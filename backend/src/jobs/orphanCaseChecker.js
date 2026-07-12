/**
 * Orphan Case Checker — phát hiện ca "mồ côi" (quá ngưỡng mà chưa ai nhận).
 *
 * Trước đây việc này dùng setTimeout đặt trong geoDispatch, tức bộ hẹn giờ nằm
 * trong BỘ NHỚ TIẾN TRÌNH. Khi máy chủ khởi động lại (rất hay xảy ra trên hạ
 * tầng miễn phí), bộ hẹn giờ bốc hơi và ca không bao giờ được cảnh báo — đúng
 * vào tình huống mà cơ chế sinh ra để chống.
 *
 * Nguyên tắc: trạng thái cần bền vững phải nằm trong CSDL, không nằm trong bộ
 * nhớ tiến trình. Ở đây ta quét theo cases.created_at và đánh dấu bằng cột
 * cases.orphan_alerted_at.
 *
 * Lưu ý: KHÔNG đổi status sang 'orphaned' — ca phải ở lại 'pending' để TNV vẫn
 * nhận được (acceptCase và getNearbyCases đều lọc theo 'pending').
 *
 * Cron: mỗi 1 phút.
 */

const cron = require('node-cron');
const { db } = require('../db');
const { emitCaseEvent } = require('../controllers/sseController');

const ORPHAN_ALERT_MS = parseInt(process.env.ORPHAN_ALERT_MS) || 15 * 60 * 1000;

async function checkOrphanCases() {
  try {
    // UPDATE ... RETURNING là một câu lệnh nguyên tử: vừa đánh dấu vừa lấy danh
    // sách. Nhờ vậy dù có nhiều tiến trình chạy song song, mỗi ca chỉ được cảnh
    // báo đúng một lần (orphan_alerted_at đóng vai trò cờ chống lặp).
    const result = await db.query(
      `UPDATE cases
       SET orphan_alerted_at = NOW()
       WHERE status = 'pending'
         AND orphan_alerted_at IS NULL
         AND created_at < NOW() - ($1::bigint * INTERVAL '1 millisecond')
       RETURNING id, urgency_level`,
      [ORPHAN_ALERT_MS]
    );

    for (const row of result.rows) {
      console.warn(
        `[orphanCase] Ca ${row.id} (mức ${row.urgency_level}) chưa có TNV nhận sau ngưỡng — cảnh báo.`
      );
      emitCaseEvent(row.id, 'case:orphaned', {
        caseId: row.id,
        urgencyLevel: row.urgency_level,
        status: 'orphaned',
      });
    }

    if (result.rows.length > 0) {
      console.log(`[orphanCase] Đã cảnh báo ${result.rows.length} ca mồ côi.`);
    }
  } catch (err) {
    console.error('[orphanCase] cron error:', err.message);
  }
}

cron.schedule('* * * * *', checkOrphanCases); // mỗi 1 phút

console.log('[orphanCase] Cron job scheduled: every 1 minute');

module.exports = { checkOrphanCases };
