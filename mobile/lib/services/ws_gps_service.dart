import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket GPS Service with automatic polling fallback.
///
/// Primary: WebSocket for real-time GPS streaming
/// Fallback: REST polling every 10s when WS disconnects
/// Auto-reconnect: Tries WS reconnection every 30s
class WsGpsService {
  // Web: 127.0.0.1 | Android emulator: 10.0.2.2
  static String get _wsBaseUrl =>
      kIsWeb ? 'ws://127.0.0.1:3000' : 'ws://10.0.2.2:3000';
  static String get _httpBaseUrl =>
      kIsWeb ? 'http://127.0.0.1:3000' : 'http://10.0.2.2:3000';

  // Connection state
  bool _isConnected = false;
  bool _disposed = false;

  // WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  // Fallback timers
  Timer? _fallbackTimer;
  Timer? _reconnectTimer;

  // Connection params (saved for reconnection)
  String? _caseId;
  String? _role;
  String? _volunteerId;

  // Callbacks
  final void Function(Map<String, dynamic>)? onGpsReceived;
  final void Function(bool)? onConnectionChanged;

  WsGpsService({this.onGpsReceived, this.onConnectionChanged});

  bool get isConnected => _isConnected;

  /// Connect to WebSocket GPS stream.
  ///
  /// [role]: 'volunteer' or 'victim'
  /// [caseId]: The case ID to join the room
  /// [volunteerId]: Required for volunteer role
  Future<void> connect({
    required String caseId,
    required String role,
    String? volunteerId,
  }) async {
    if (_disposed) return;

    _caseId = caseId;
    _role = role;
    _volunteerId = volunteerId;

    try {
      final wsUrl = '$_wsBaseUrl/ws/gps?caseId=$caseId&role=$role'
          '${volunteerId != null ? '&volunteerId=$volunteerId' : ''}';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for connection to be ready
      await _channel!.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('WebSocket connection timeout');
        },
      );

      _isConnected = true;
      onConnectionChanged?.call(true);
      _stopFallbackPolling();
      _stopReconnect();

      debugPrint('[WsGps] Connected to $wsUrl');

      _wsSubscription = _channel!.stream.listen(
        (data) {
          try {
            final msg = json.decode(data as String) as Map<String, dynamic>;
            _handleMessage(msg);
          } catch (e) {
            debugPrint('[WsGps] Parse error: $e');
          }
        },
        onDone: () => _onDisconnect(),
        onError: (e) {
          debugPrint('[WsGps] Stream error: $e');
          _onDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[WsGps] Connection failed: $e');
      _isConnected = false;
      _onDisconnect();
    }
  }

  /// Send GPS update to server (volunteer only).
  /// Only sends when WebSocket is connected.
  void sendGps(double lat, double lon) {
    if (!_isConnected || _channel == null) return;
    try {
      _channel!.sink.add(json.encode({
        'type': 'gps_update',
        'lat': lat,
        'lon': lon,
      }));
    } catch (e) {
      debugPrint('[WsGps] Send error: $e');
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'gps_update':
        onGpsReceived?.call(msg);
        break;
      case 'connected':
        debugPrint('[WsGps] Server confirmed connection for case ${msg['caseId']}');
        break;
    }
  }

  /// Called when WebSocket disconnects — start fallback + reconnect
  void _onDisconnect() {
    if (_disposed) return;
    final wasConnected = _isConnected;
    _isConnected = false;
    if (wasConnected) {
      onConnectionChanged?.call(false);
    }
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _channel = null;

    debugPrint('[WsGps] Disconnected — starting fallback polling');

    _startFallbackPolling();
    _startReconnect();
  }

  /// Fallback: poll TNV location via REST every 10s
  void _startFallbackPolling() {
    _fallbackTimer?.cancel();
    if (_disposed || _caseId == null) return;

    _fallbackTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isConnected || _disposed) {
        _fallbackTimer?.cancel();
        return;
      }

      try {
        if (_role == 'victim') {
          // Victim: poll TNV location via REST
          final response = await http.get(
            Uri.parse('$_httpBaseUrl/api/case/$_caseId/tnv-location'),
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200 && !_disposed) {
            final data = json.decode(response.body) as Map<String, dynamic>;
            onGpsReceived?.call({
              'type': 'gps_update',
              'lat': data['lat'],
              'lon': data['lon'],
              'distance_m': data['distance_m'],
              'has_volunteer': data['has_volunteer'],
            });
          }
        }
        // Note: volunteer fallback is handled by the screen calling
        // ApiService.updateLocation() directly when WS is down
      } catch (e) {
        debugPrint('[WsGps] Fallback poll error: $e');
      }
    });
  }

  /// Try to reconnect WebSocket every 30s
  void _startReconnect() {
    _reconnectTimer?.cancel();
    if (_disposed) return;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isConnected || _disposed) {
        _reconnectTimer?.cancel();
        return;
      }

      debugPrint('[WsGps] Attempting reconnection...');
      await connect(
        caseId: _caseId!,
        role: _role!,
        volunteerId: _volunteerId,
      );
    });
  }

  void _stopFallbackPolling() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Dispose all resources
  void dispose() {
    _disposed = true;
    _wsSubscription?.cancel();
    _stopFallbackPolling();
    _stopReconnect();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
