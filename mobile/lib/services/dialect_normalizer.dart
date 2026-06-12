import 'dart:convert';
import 'package:flutter/services.dart';

/// Bộ chuẩn hóa phương ngữ miền Trung → tiếng Việt phổ thông.
///
/// Sử dụng từ điển JSON (26,000+ mục) được load 1 lần duy nhất khi app khởi động.
/// Thuật toán thay thế chạy offline, tốc độ O(n) với n = số từ trong câu.
/// Không cần kết nối mạng, phù hợp cho tình huống khẩn cấp SOS.
class DialectNormalizer {
  static Map<String, String> _dict = {};
  static bool _isLoaded = false;

  /// Load từ điển từ file assets. Gọi 1 lần duy nhất trong `main.dart` hoặc `initState`.
  static Future<void> load() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/dialect_dict.json');
      final Map<String, dynamic> raw = json.decode(jsonStr);
      _dict = raw.map((key, value) => MapEntry(key.toLowerCase(), value.toString()));
      _isLoaded = true;
      print('[DialectNormalizer] Đã load ${_dict.length} mục từ điển phương ngữ.');
    } catch (e) {
      print('[DialectNormalizer] Lỗi load từ điển: $e');
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
