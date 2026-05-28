import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Represents a single Server-Sent Event
class SseEvent {
  final String event;
  final Map<String, dynamic> data;

  SseEvent({required this.event, required this.data});

  @override
  String toString() => 'SseEvent($event, $data)';
}

/// SSE client service for listening to case status events.
/// Replaces polling — only receives data when server has an actual update.
class SseService {
  // Web: local dev | Android: Render (online)
  static String get _baseUrl =>
      kIsWeb ? 'http://127.0.0.1:3000' : 'https://floodaid.onrender.com';

  /// Listen to case status events via SSE stream.
  /// 
  /// Yields [SseEvent] objects as they arrive from the server.
  /// Events: case:accepted, case:resolved, case:cancelled, case:orphaned
  /// 
  /// The stream will automatically retry on connection errors.
  static Stream<SseEvent> listenCaseEvents(String caseId) async* {
    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse('$_baseUrl/api/case/$caseId/stream'),
      );
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await client.send(request);

      if (response.statusCode != 200) {
        print('[SseService] SSE connection failed: ${response.statusCode}');
        return;
      }

      // Buffer for incomplete SSE frames
      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // SSE format: "event: xxx\ndata: {...}\n\n"
        // Split on double newline (end of event)
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final rawEvent = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          // Parse the SSE event
          final parsed = _parseRawEvent(rawEvent);
          if (parsed != null) {
            yield parsed;
          }
        }
      }
    } catch (e) {
      print('[SseService] SSE stream error: $e');
    } finally {
      client.close();
    }
  }

  /// Parse raw SSE text into an SseEvent.
  /// Format: "event: eventName\ndata: {json}"
  static SseEvent? _parseRawEvent(String raw) {
    String? eventName;
    String? dataStr;

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      
      // Skip comments (heartbeat)
      if (trimmed.startsWith(':')) continue;

      if (trimmed.startsWith('event:')) {
        eventName = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('data:')) {
        dataStr = trimmed.substring(5).trim();
      }
    }

    if (eventName == null || dataStr == null) return null;

    // Skip connection/heartbeat events
    if (eventName == 'connected') return null;

    try {
      final data = json.decode(dataStr) as Map<String, dynamic>;
      return SseEvent(event: eventName, data: data);
    } catch (e) {
      print('[SseService] JSON parse error: $e');
      return null;
    }
  }
}
