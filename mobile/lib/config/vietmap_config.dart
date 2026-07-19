/// Cấu hình VietMap cho phần hiển thị bản đồ (client-side).
///
/// Đây là KEY TILEMAP (consumer "bản đồ") — được thiết kế để nhúng trong app.
/// Bảo vệ bằng giới hạn domain/IP + quota trong VietMap Console, KHÔNG phải bằng cách giấu.
/// Các API khác (reverse/route/autocomplete) KHÔNG dùng key này — chúng đi qua backend.
class VietmapConfig {
  /// Key tilemap (consumer "bản đồ (tile)").
  static const String mapApiKey = '67cc2a5a85106ca9c8a4ea8ba6873f82a0bca0ec4950b145';

  /// Style vector mặc định (đường phố).
  static String get styleUrl =>
      'https://maps.vietmap.vn/maps/styles/tm/style.json?apikey=$mapApiKey';

  /// Style tối (dùng khi cần).
  static String get styleUrlDark =>
      'https://maps.vietmap.vn/maps/styles/dm/style.json?apikey=$mapApiKey';
}
