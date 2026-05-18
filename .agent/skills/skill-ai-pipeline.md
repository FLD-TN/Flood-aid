# skill-ai-pipeline.md — Module 1: Core Ingestion & AI Pipeline

> Đọc file này khi làm task liên quan đến: xử lý SOS đầu vào, Gemini API, Rule-based fallback, offline queue, GPS cold start.

---

## Trách nhiệm của skill này

- Nhận payload SOS từ Flutter client
- Chạy Parallel Race Pipeline (Gemini API vs Rule-based Regex)
- Xử lý mạng yếu: Split Payload + Offline Queue
- GPS Cold Start: 3-layer strategy

---

## Pattern: Parallel Race Pipeline

```js
// services/aiPipeline.js

const { GoogleGenerativeAI } = require('@google/generative-ai');
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const URGENCY_KEYWORDS = {
  5: ['máu', 'bất tỉnh', 'không thở', 'chết', 'chìm'],
  4: ['trẻ em', 'em bé', 'người già', 'ngập nóc', 'mái nhà', 'bị thương'],
  3: ['ngập sâu', 'nước dâng', 'kẹt', 'không thoát được'],
  2: ['ngập', 'cần xuồng', 'cần giúp'],
};

const TAG_KEYWORDS = {
  y_te:      ['máu', 'bất tỉnh', 'chấn thương', 'bị thương', 'không thở', 'cấp cứu'],
  tre_em:    ['trẻ em', 'em bé', 'con nít', 'trẻ con'],
  nguoi_gia: ['người già', 'ông', 'bà', 'cụ'],
  ngap_noc:  ['ngập nóc', 'nước đến nóc', 'ngập tới mái'],
  phuong_tien: ['cần xuồng', 'cần thuyền', 'không có phương tiện'],
};

/**
 * Rule-based fallback — chạy local, 0ms latency
 */
function runRuleBasedFallback(text) {
  const lower = text.toLowerCase();

  // Tính urgency
  let urgency = 1;
  for (const [level, words] of Object.entries(URGENCY_KEYWORDS)) {
    if (words.some(w => lower.includes(w))) {
      urgency = Math.max(urgency, Number(level));
    }
  }

  // Tính tags
  const tags = Object.entries(TAG_KEYWORDS)
    .filter(([, words]) => words.some(w => lower.includes(w)))
    .map(([tag]) => tag);

  // Summary đơn giản
  const summary = text.length > 80 ? text.slice(0, 77) + '...' : text;

  return { urgency_level: urgency, tags, summary_1line: summary, source: 'rule_based' };
}

/**
 * Gemini AI call với timeout cứng 3 giây
 */
async function callGeminiWithTimeout(text) {
  const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

  const prompt = `
Phân tích yêu cầu cứu trợ lũ lụt sau (tiếng Việt):
"${text}"

Trả về JSON với format chính xác:
{
  "urgency_level": <1-5>,
  "tags": <mảng các tag từ: y_te, tre_em, nguoi_gia, ngap_noc, phuong_tien>,
  "summary_1line": <tóm tắt tối đa 80 ký tự cho notification>
}

Thang urgency: 1=thấp, 3=trung bình, 5=cực kỳ nguy hiểm (tính mạng nguy cấp).
Chỉ trả về JSON, không giải thích thêm.
`;

  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('GEMINI_TIMEOUT')), parseInt(process.env.GEMINI_TIMEOUT_MS) || 3000)
  );

  const geminiPromise = (async () => {
    const result = await model.generateContent(prompt);
    const raw = result.response.text().trim().replace(/```json|```/g, '');
    const parsed = JSON.parse(raw);
    return { ...parsed, source: 'gemini' };
  })();

  return Promise.race([geminiPromise, timeoutPromise]);
}

/**
 * MAIN: Parallel Race Pipeline
 * Luôn chạy cả 2 đồng thời, lấy kết quả nào tốt hơn
 */
async function runParallelAiPipeline(text) {
  const ruleResult = runRuleBasedFallback(text); // sync, instant

  let aiResult = null;
  try {
    aiResult = await callGeminiWithTimeout(text);
  } catch (err) {
    console.warn('[aiPipeline] Gemini unavailable:', err.message, '→ using rule-based');
  }

  // Dùng Gemini nếu có, fallback sang Rule-based
  const final = aiResult || ruleResult;

  // Safety: urgency của Rule-based làm baseline tối thiểu
  final.urgency_level = Math.max(final.urgency_level, ruleResult.urgency_level);

  return final;
}

module.exports = { runParallelAiPipeline, runRuleBasedFallback };
```

---

## Pattern: SOS Controller (POST /api/sos)

```js
// controllers/sosController.js

const { runParallelAiPipeline } = require('../services/aiPipeline');
const { db } = require('../db');
const crypto = require('crypto');

const SALT = process.env.PHONE_HASH_SALT;

function hashPhone(phone) {
  return crypto.createHmac('sha256', SALT).update(phone).digest('hex');
}

async function createSos(req, res) {
  try {
    const { text, lat, lon, phone } = req.body;

    // Validate input
    if (!text || !lat || !lon || !phone) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const phoneHash = hashPhone(phone);

    // Anti-spam: 1 SĐT chỉ có 1 ca active
    const existing = await db.query(
      `SELECT id FROM cases WHERE phone_hash = $1 AND status != 'resolved' LIMIT 1`,
      [phoneHash]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: 'ACTIVE_CASE_EXISTS',
        caseId: existing.rows[0].id,
        message: 'Bạn đang có 1 ca đang được xử lý'
      });
    }

    // Chạy AI Pipeline (parallel)
    const aiResult = await runParallelAiPipeline(text);

    // Lưu vào PostGIS
    const insert = await db.query(
      `INSERT INTO cases (phone_hash, coords, text_raw, urgency_level, tags, summary_1line, status)
       VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, $5, $6, $7, 'pending')
       RETURNING id`,
      [phoneHash, lon, lat, text, aiResult.urgency_level, JSON.stringify(aiResult.tags), aiResult.summary_1line]
    );

    const caseId = insert.rows[0].id;

    // Trigger geo-dispatch (async, không block response)
    setImmediate(() => require('../services/geoDispatch').dispatchToNearbyVolunteers(caseId));

    res.status(201).json({ caseId, status: 'pending', aiSource: aiResult.source });

  } catch (err) {
    console.error('[sosController][createSos]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { createSos };
```

---

## Pattern: Flutter Offline Queue + Split Payload

```dart
// services/offline_queue_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import 'dart:io';

const CRITICAL_PAYLOAD_MAX_BYTES = 150;
const SYNC_TASK_NAME = 'floodaid.sync_sos_queue';

class OfflineQueueService {
  static Database? _db;

  static Future<Database> getDb() async {
    _db ??= await openDatabase(
      'floodaid_queue.db',
      onCreate: (db, _) => db.execute(
        'CREATE TABLE queue(id INTEGER PRIMARY KEY, payload TEXT, sent INTEGER DEFAULT 0)'
      ),
      version: 1,
    );
    return _db!;
  }

  /// Gửi SOS với Split Payload strategy
  static Future<String?> sendSos({
    required String text,
    required double lat,
    required double lon,
    required String phone,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasNetwork = connectivity != ConnectivityResult.none;

    // Critical payload < 150 bytes: chỉ coords + hash + urgency
    final criticalPayload = {
      'phone': phone,
      'lat': lat,
      'lon': lon,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    // Enrichment payload: text đầy đủ
    final enrichmentPayload = {
      'phone': phone,
      'text': text,
      'lat': lat,
      'lon': lon,
    };

    if (!hasNetwork) {
      // Mất mạng: lưu queue, WorkManager sẽ sync
      await _saveToQueue(json.encode(enrichmentPayload));
      _scheduleBackgroundSync();
      return null; // UI sẽ hiển thị "đã lưu, chờ sóng"
    }

    try {
      // Gửi critical trước
      final criticalBytes = utf8.encode(json.encode(criticalPayload));
      if (criticalBytes.length > CRITICAL_PAYLOAD_MAX_BYTES) {
        // Trim nếu cần
      }
      await _postToServer('/api/sos/critical', criticalPayload);

      // Gửi enrichment sau (best-effort)
      _postToServer('/api/sos', enrichmentPayload).catchError((_) {
        // Enrichment thất bại → lưu queue để sync sau
        _saveToQueue(json.encode(enrichmentPayload));
      });

      return 'sent';
    } catch (e) {
      // Network error → lưu queue
      await _saveToQueue(json.encode(enrichmentPayload));
      _scheduleBackgroundSync();
      return null;
    }
  }

  static Future<void> _saveToQueue(String payloadJson) async {
    final db = await getDb();
    await db.insert('queue', {'payload': payloadJson, 'sent': 0});
  }

  static void _scheduleBackgroundSync() {
    Workmanager().registerOneOffTask(
      SYNC_TASK_NAME,
      SYNC_TASK_NAME,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
    );
  }

  /// Chạy trong Workmanager callback khi mạng trở lại
  static Future<void> syncPendingQueue() async {
    final db = await getDb();
    final rows = await db.query('queue', where: 'sent = 0');
    for (final row in rows) {
      try {
        final payload = json.decode(row['payload'] as String);
        await _postToServer('/api/sos', payload);
        await db.update('queue', {'sent': 1}, where: 'id = ?', whereArgs: [row['id']]);
      } catch (_) {
        // Thất bại → để WorkManager thử lại sau
      }
    }
  }

  static Future<void> _postToServer(String path, Map payload) async {
    // HTTP POST implementation
  }
}
```

---

## GPS Cold Start — 3 Layer Strategy

```dart
// services/adaptive_gps_service.dart (phần Cold Start)

class GpsColdStartHandler {
  
  /// Lớp 1: Khởi động GPS ngay khi vào màn hình SOS (không phải khi mở app)
  static void warmUpOnSosScreen() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.balanced,
        distanceFilter: 0,
      ),
    ).listen((_) {}); // chỉ để warm up, bỏ listener sau khi có fix
  }

  /// Lớp 2 + 3: Lấy tọa độ khi bấm Gửi
  static Future<Position?> getBestAvailableLocation() async {
    try {
      // Thử lấy GPS fresh (timeout 8 giây)
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.balanced,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      // Lớp 3: Dùng cache nếu GPS chưa kịp fix
      return await Geolocator.getLastKnownPosition();
    }
  }
}
```
