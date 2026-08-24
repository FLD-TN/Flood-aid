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
  /// 2. Ở mỗi từ, tách phần dấu câu dính ở đầu/cuối ("rứa," -> "rứa" + ",")
  ///    để tra từ điển trên phần lõi, rồi gắn dấu câu lại sau khi thay thế.
  /// 3. Thử khớp cụm từ dài trước (3 rồi 2 từ), không khớp thì thử từ đơn.
  ///    Cụm chỉ hợp lệ khi dấu câu nằm ở rìa ngoài, không xen giữa các từ.
  /// 4. Giữ nguyên viết hoa/thường của cụm gốc, kể cả cụm thay thế nhiều từ.
  ///
  /// Ví dụ: "Bữa ni nước lên gốp quá" → "Bữa này nước lên gấp quá"
  static String normalize(String text) {
    if (!_isLoaded || _dict.isEmpty || text.isEmpty) return text;

    final words = text.split(' ');
    final result = <String>[];
    int i = 0;

    while (i < words.length) {
      // Token rỗng (nhiều khoảng trắng liên tiếp) → giữ nguyên.
      if (words[i].isEmpty) {
        result.add(words[i]);
        i++;
        continue;
      }

      bool matched = false;

      // Thử khớp cụm dài trước: 3 từ rồi 2 từ.
      for (int n = 3; n >= 2 && !matched; n--) {
        if (i + n - 1 >= words.length) continue;

        // Mỗi phần tử: [dấu đầu, lõi, dấu cuối] của từng từ trong cụm.
        final parts = <List<String>>[];
        bool eligible = true;
        for (int k = 0; k < n; k++) {
          final p = _splitPunct(words[i + k]);
          // Dấu câu chỉ được phép ở rìa ngoài: đầu-của-từ-đầu và cuối-của-từ-cuối.
          final badInnerPrefix = k != 0 && p[0].isNotEmpty;
          final badInnerSuffix = k != n - 1 && p[2].isNotEmpty;
          if (p[1].isEmpty || badInnerPrefix || badInnerSuffix) {
            eligible = false;
            break;
          }
          parts.add(p);
        }
        if (!eligible) continue;

        final cores = parts.map((p) => p[1]).toList();
        final key = cores.join(' ').toLowerCase();
        if (_dict.containsKey(key)) {
          final replaced = _preserveCasePhrase(cores, _dict[key]!);
          result.add(parts.first[0] + replaced + parts.last[2]);
          i += n;
          matched = true;
        }
      }

      // Thử khớp từ đơn.
      if (!matched) {
        final p = _splitPunct(words[i]);
        final core = p[1];
        final lower = core.toLowerCase();
        if (core.isNotEmpty && _dict.containsKey(lower)) {
          final replaced = _preserveCasePhrase([core], _dict[lower]!);
          result.add(p[0] + replaced + p[2]);
        } else {
          result.add(words[i]); // Giữ nguyên nếu không khớp
        }
        i++;
      }
    }

    return result.join(' ');
  }

  /// Các ký tự được coi là dấu câu khi tách khỏi rìa từ.
  static const String _punctChars = ',.;:!?"\'“”‘’()[]{}…-–—/\\`~@#\$%^&*_+=|<>';

  static bool _isPunct(String ch) => _punctChars.contains(ch);

  /// Tách một từ thành [dấu câu đầu, lõi, dấu câu cuối].
  /// Ví dụ: "rứa," → ["", "rứa", ","];  "(nhà)" → ["(", "nhà", ")"].
  static List<String> _splitPunct(String w) {
    int start = 0, end = w.length;
    while (start < end && _isPunct(w[start])) {
      start++;
    }
    while (end > start && _isPunct(w[end - 1])) {
      end--;
    }
    return [w.substring(0, start), w.substring(start, end), w.substring(end)];
  }

  /// Giữ nguyên quy tắc viết hoa của cụm gốc khi thay thế, xử lý được cả cụm
  /// thay thế nhiều từ (VD: gốc "Nhoà Tôi" → thay "nhà tôi" → "Nhà Tôi").
  static String _preserveCasePhrase(
      List<String> originalWords, String replacement) {
    if (originalWords.isEmpty || replacement.isEmpty) return replacement;

    // Chỉ coi là VIẾT HOA TOÀN BỘ khi từ dài ≥ 2 ký tự: một chữ cái hoa đơn lẻ
    // (VD "O" đầu câu) là viết hoa chữ đầu, không phải cả từ in hoa.
    bool isUpper(String s) =>
        s.length > 1 && s == s.toUpperCase() && s != s.toLowerCase();
    bool isTitle(String s) =>
        s.isNotEmpty && s[0] == s[0].toUpperCase() && s[0] != s[0].toLowerCase();
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

    final repWords = replacement.split(' ');

    // Cả cụm gốc VIẾT HOA (VD "LỒM") → thay thế viết hoa hết.
    if (originalWords.every(isUpper)) {
      return replacement.toUpperCase();
    }
    // Mỗi từ trong cụm gốc Viết Hoa chữ đầu → viết hoa chữ đầu từng từ thay thế.
    if (originalWords.every(isTitle)) {
      return repWords.map(cap).join(' ');
    }
    // Chỉ từ đầu cụm viết Hoa → chỉ viết hoa chữ đầu của từ thay thế đầu tiên.
    if (isTitle(originalWords.first)) {
      repWords[0] = cap(repWords[0]);
      return repWords.join(' ');
    }
    // Còn lại giữ nguyên chữ thường.
    return replacement;
  }
}
