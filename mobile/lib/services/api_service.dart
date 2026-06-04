import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // Web: dùng 127.0.0.1 cho local dev
  // Android: dùng Render (backend online, hoạt động ở mọi nơi)
  static String get _baseUrl =>
      kIsWeb ? 'http://127.0.0.1:3000' : 'https://floodaid.onrender.com';

  static Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await AuthService.getIdToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// POST /api/sos — Gửi SOS
  static Future<Map<String, dynamic>?> sendSos({
    required String text,
    required double lat,
    required double lon,
    required String phone,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/sos'),
            headers: headers,
            body: json.encode({
              'text': text,
              'lat': lat,
              'lon': lon,
              'phone': phone,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 409) {
        // Ca active đã tồn tại
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('[ApiService] sendSos error: $e');
      return null; // Offline → queue sẽ xử lý
    }
  }

  /// GET /api/sos/active?phone=xxx — Kiểm tra ca SOS active
  static Future<Map<String, dynamic>?> checkActiveCaseByPhone(String phone) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$_baseUrl/api/sos/active?phone=$phone'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('[ApiService] checkActiveCaseByPhone error: $e');
      return null;
    }
  }

  /// GET /api/case/:id/tnv-location — Polling vị trí TNV
  static Future<Map<String, dynamic>?> getTnvLocation(String caseId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/case/$caseId/tnv-location'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/case/:id — Lấy thông tin ca, dùng để pre-check status trước khi accept
  static Future<String?> getCaseStatus(String caseId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/case/$caseId'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/case/:id/my-assignment?volunteerId=xxx
  /// TNV kiểm tra xem mình đã được assign vào ca này chưa
  static Future<Map<String, dynamic>?> checkMyAssignment(String caseId, String volunteerId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/case/$caseId/my-assignment?volunteerId=$volunteerId'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// POST /api/case/:id/resolve — Đóng ca
  static Future<bool> resolveCase(String caseId, String resolvedBy) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/case/$caseId/resolve'),
        headers: headers,
        body: json.encode({'resolvedBy': resolvedBy}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/case/:id/revoke — TNV chủ động hủy nhiệm vụ
  static Future<bool> revokeCase(String caseId, String volunteerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/case/$caseId/revoke'),
        headers: headers,
        body: json.encode({'volunteerId': volunteerId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/case/:id/accept — TNV nhận ca
  /// Gửi kèm lat/lon hiện tại để backend tính khoảng cách ban đầu
  static Future<bool> acceptCase(String caseId, String volunteerId, {double? lat, double? lon}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{'volunteerId': volunteerId};
      if (lat != null && lon != null) {
        body['lat'] = lat;
        body['lon'] = lon;
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/api/case/$caseId/accept'),
        headers: headers,
        body: json.encode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/location — TNV gửi GPS update
  static Future<void> updateLocation({
    required double lat,
    required double lon,
    required String volunteerId,
  }) async {
    try {
      final headers = await _getHeaders();
      await http
          .post(
            Uri.parse('$_baseUrl/api/location'),
            headers: headers,
            body: json.encode({
              'lat': lat,
              'lon': lon,
              'volunteerId': volunteerId,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Silent fail — GPS update mất 1 lần không sao
    }
  }

  /// PUT /api/volunteers/:id/radius — Bật/tắt nhận thông báo SOS
  static Future<bool> updateNotificationSetting({
    required String volunteerId,
    required bool enabled,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('$_baseUrl/api/volunteers/$volunteerId/radius'),
            headers: headers,
            body: json.encode({
              'enabled': enabled,
            }),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/volunteers/register — Đăng ký TNV
  /// Trả về volunteerId (UUID) cả khi tạo mới (201) lẫn đã tồn tại (409)
  static Future<Map<String, dynamic>?> registerVolunteer({
    required String phone,
    String? fullName,
    List<String>? skills,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/volunteers/register'),
        headers: headers,
        body: json.encode({
          'phone': phone,
          'fullName': fullName,
          'skills': skills ?? [],
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 409) {
        // 201 = tạo mới, 409 = đã tồn tại → cả hai đều trả về volunteerId
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('[ApiService] registerVolunteer error: $e');
      return null;
    }
  }


  /// GET /api/admin/cases — Lấy danh sách ca SOS active
  static Future<List<Map<String, dynamic>>> getCases() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/admin/cases'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      }
      return [];
    } catch (e) {
      print('[ApiService] getCases error: $e');
      return [];
    }
  }

  /// GET /api/case/:id — Lấy chi tiết ca SOS
  static Future<Map<String, dynamic>?> getCaseById(String caseId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/case/$caseId'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/cases/nearby — Lấy danh sách ca SOS gần TNV (có khoảng cách, filter, sort)
  static Future<List<Map<String, dynamic>>> getNearbyCases({
    required double lat,
    required double lon,
    double maxDistance = 10,
    List<int>? urgencyLevels,
    List<String>? tags,
    String sortBy = 'distance_asc',
  }) async {
    try {
      final queryParams = <String, String>{
        'lat': lat.toString(),
        'lon': lon.toString(),
        'maxDistance': maxDistance.toString(),
        'sortBy': sortBy,
      };

      if (urgencyLevels != null && urgencyLevels.isNotEmpty) {
        queryParams['urgency'] = urgencyLevels.join(',');
      }
      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }

      final uri = Uri.parse('$_baseUrl/api/cases/nearby')
          .replace(queryParameters: queryParams);

      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      }
      return [];
    } catch (e) {
      print('[ApiService] getNearbyCases error: $e');
      return [];
    }
  }
  /// PUT /api/volunteers/:id/fcm-token — Gửi FCM token lên Backend
  static Future<bool> updateFcmToken({
    required String volunteerId,
    required String fcmToken,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/api/volunteers/$volunteerId/fcm-token'),
        headers: headers,
        body: json.encode({'fcmToken': fcmToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[ApiService] updateFcmToken error: $e');
      return false;
    }
  }
}
