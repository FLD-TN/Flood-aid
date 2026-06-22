const { db } = require('../db');
const { broadcastToRoom } = require('../services/wsServer');

/**
 * GET /api/case/:id/messages — Lấy lịch sử chat (tối đa 100 tin gần nhất)
 */
async function getMessages(req, res) {
  try {
    const { id } = req.params;
    const result = await db.query(
      `SELECT id, sender_role, content, created_at
       FROM chat_messages
       WHERE case_id = $1
       ORDER BY created_at ASC
       LIMIT 100`,
      [id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('[chatController][getMessages]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

/**
 * POST /api/case/:id/messages — REST fallback gửi tin nhắn (khi WS mất kết nối)
 * Body: { senderRole: 'volunteer'|'victim', senderId?: uuid, content: string }
 */
async function sendMessage(req, res) {
  try {
    const { id } = req.params;
    const { senderRole, senderId, content } = req.body;

    if (!senderRole || !content) {
      return res.status(400).json({ error: 'Missing senderRole or content' });
    }
    if (!['volunteer', 'victim'].includes(senderRole)) {
      return res.status(400).json({ error: 'Invalid senderRole' });
    }

    const insert = await db.query(
      `INSERT INTO chat_messages (case_id, sender_role, sender_id, content)
       VALUES ($1, $2, $3, $4)
       RETURNING id, sender_role, content, created_at`,
      [id, senderRole, senderId || null, content.trim()]
    );

    const msg = insert.rows[0];

    // Broadcast qua WebSocket cho bên còn lại
    broadcastToRoom(id, {
      type: 'chat',
      senderRole: msg.sender_role,
      content: msg.content,
      createdAt: msg.created_at,
    });

    res.status(201).json(msg);
  } catch (err) {
    console.error('[chatController][sendMessage]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { getMessages, sendMessage };
