import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Bộ chuẩn hóa phương ngữ miền Trung → tiếng Việt phổ thông.
///
/// Nguồn từ điển gồm 2 lớp, gộp lại khi chạy:
///  1. Từ điển gốc (bundle): file JSON ~26k mục đóng gói trong app — luôn có sẵn,
///     chạy được offline ngay cả khi chưa từng có mạng.
///  2. Overrides từ backend: các từ admin thêm/sửa (file nhỏ). App tải về, cache
///     trong SharedPreferences và merge ĐÈ lên bundle. Nhờ vậy thêm từ mới chỉ cần
///     admin gọi API, KHÔNG cần build lại app.
///
/// Việc normalize luôn đọc từ dict đã merge trong RAM → hoàn toàn offline,
/// không gọi mạng lúc tạo SOS. Chỉ [syncFromBackend] mới chạm mạng, và nếu offline
/// thì bỏ qua êm, dùng bản cache/bundle đang có.
class DialectNormalizer {
  static const String _baseUrl = 'https://floodaid.onrender.com';
  static const String _kOverrideTerms = 'dialect_overrides_terms';
  static const String _kOverrideVersion = 'dialect_overrides_version';

  static Map<String, String> _bundledDict = {};
  static Map<String, String> _overrides = {};
  // Dict đã gộp, dùng cho normalize (build lại mỗi khi overrides đổi).
  static Map<String, String> _dict = {};
  static bool _isLoaded = false;

  /// Load từ điển gốc + overrides đã cache. Gọi 1 lần khi khởi động.
  static Future<void> load() async {
    if (_isLoaded) return;
    await _loadBundled();
    await _loadCachedOverrides();
    _rebuild();
    _isLoaded = true;
    print('[DialectNormalizer] Đã load ${_bundledDict.length} mục gốc + '
        '${_overrides.length} mục override.');
  }

  static Future<void> _loadBundled() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/dialect_dict.json');
      final Map<String, dynamic> raw = json.decode(jsonStr);
      _bundledDict =
          raw.map((key, value) => MapEntry(key.toLowerCase(), value.toString()));
    } catch (e) {
      print('[DialectNormalizer] Lỗi load từ điển gốc: $e');
    }
  }

  static Future<void> _loadCachedOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kOverrideTerms);
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> raw = json.decode(str);
        _overrides =
            raw.map((key, value) => MapEntry(key.toLowerCase(), value.toString()));
      }
    } catch (e) {
      print('[DialectNormalizer] Lỗi load overrides cache: $e');
    }
  }

  /// Gộp: override đè lên từ gốc khi trùng key.
  static void _rebuild() {
    _dict = {..._bundledDict, ..._overrides};
  }

  /// Đồng bộ overrides từ backend nếu có mạng. Gọi kiểu fire-and-forget sau [load].
  /// Offline / lỗi mạng → bỏ qua, giữ nguyên bản cache/bundle.
  static Future<void> syncFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_kOverrideVersion) ?? -1;

      // Kiểm tra version trước (nhẹ) để tránh tải thừa.
      final verResp = await http
          .get(Uri.parse('$_baseUrl/api/dialect-dict/version'))
          .timeout(const Duration(seconds: 6));
      if (verResp.statusCode != 200) return;
      final remoteVersion =
          (json.decode(verResp.body)['version'] as num?)?.toInt() ?? 0;
      if (remoteVersion <= localVersion) return; // đã mới nhất

      // Tải toàn bộ overrides.
      final resp = await http
          .get(Uri.parse('$_baseUrl/api/dialect-dict'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;

      final Map<String, dynamic> data = json.decode(resp.body);
      final Map<String, dynamic> terms =
          (data['terms'] as Map?)?.cast<String, dynamic>() ?? {};
      final version = (data['version'] as num?)?.toInt() ?? remoteVersion;

      _overrides =
          terms.map((key, value) => MapEntry(key.toLowerCase(), value.toString()));
      _rebuild();

      await prefs.setString(_kOverrideTerms, json.encode(_overrides));
      await prefs.setInt(_kOverrideVersion, version);
      print('[DialectNormalizer] Đồng bộ overrides v$version: '
          '${_overrides.length} mục.');
    } catch (e) {
      // Offline hoặc backend lỗi → im lặng dùng bản đang có.
      print('[DialectNormalizer] Bỏ qua sync (offline/lỗi): $e');
    }
  }

  /// Chuẩn hóa chuỗi văn bản chứa phương ngữ miền Trung sang tiếng Việt phổ thông.
  ///
  /// Thuật toán:
  /// 1. Tách câu thành từng từ (theo khoảng trắng).
  /// 2. Thử khớp cụm từ dài trước (2-3 từ), nếu không khớp thì thử từ đơn.
  /// 3. Giữ nguyên viết hoa/thường của từ gốc.
  ///
  /// Ví dụ: "Bữa ni nước lên gốp quá" → "Bữa này nước lên gấp quá"
  static String normalize(String text) {
    if (!_isLoaded || _dict.isEmpty || text.isEmpty) return text;

    final words = text.split(' ');
    final result = <String>[];
    int i = 0;

    while (i < words.length) {
      bool matched = false;

      // Thử khớp cụm 3 từ trước (cho các cụm như "chu cha ơi")
      if (i + 2 < words.length) {
        final trigram = '${words[i]} ${words[i + 1]} ${words[i + 2]}'.toLowerCase();
        if (_dict.containsKey(trigram)) {
          result.add(_preserveCase(words[i], _dict[trigram]!));
          i += 3;
          matched = true;
        }
      }

      // Thử khớp cụm 2 từ (cho các cụm như "chu cha")
      if (!matched && i + 1 < words.length) {
        final bigram = '${words[i]} ${words[i + 1]}'.toLowerCase();
        if (_dict.containsKey(bigram)) {
          result.add(_preserveCase(words[i], _dict[bigram]!));
          i += 2;
          matched = true;
        }
      }

      // Thử khớp từ đơn
      if (!matched) {
        final lower = words[i].toLowerCase();
        if (_dict.containsKey(lower)) {
          result.add(_preserveCase(words[i], _dict[lower]!));
        } else {
          result.add(words[i]); // Giữ nguyên nếu không khớp
        }
        i++;
      }
    }

    return result.join(' ');
  }

  /// Giữ nguyên quy tắc viết hoa của từ gốc khi thay thế.
  /// Ví dụ: gốc = "Lồm" (viết hoa chữ đầu), thay thế = "làm" → "Làm"
  static String _preserveCase(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;

    // Nếu toàn bộ viết hoa (VD: "LỒM") → "LÀM"
    if (original == original.toUpperCase() && original != original.toLowerCase()) {
      return replacement.toUpperCase();
    }

    // Nếu chữ đầu viết hoa (VD: "Lồm") → "Làm"
    if (original[0] == original[0].toUpperCase() &&
        original[0] != original[0].toLowerCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }

    // Ngược lại giữ nguyên chữ thường
    return replacement;
  }
}
