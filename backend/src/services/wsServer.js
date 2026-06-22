/**
 * WebSocket Server — Real-time GPS tracking
 * 
 * Path: ws://host:port/ws/gps
 * 
 * Roles:
 *   - volunteer: sends GPS updates → server saves to DB + forwards to victim
 *   - victim: receives GPS updates from volunteer in real-time
 * 
 * Connection query params:
 *   ?role=volunteer&caseId=xxx&volunteerId=yyy
 *   ?role=victim&caseId=xxx
 */

const WebSocket = require('ws');
const url = require('url');
const { db } = require('../db');

// Lazy require để tránh circular dependency với chatController
function saveChatMessage(caseId, senderRole, senderId, content) {
  return db.query(
    `INSERT INTO chat_messages (case_id, sender_role, sender_id, content)
     VALUES ($1, $2, $3, $4)
     RETURNING id, sender_role, content, created_at`,
    [caseId, senderRole, senderId || null, content]
  );
}

// Room map: caseId -> { volunteers: Set<ws>, victims: Set<ws> }
const rooms = new Map();

/**
 * Initialize WebSocket server on existing HTTP server
 */
function initWebSocket(httpServer) {
  const wss = new WebSocket.Server({
    server: httpServer,
    path: '/ws/gps',
  });

  console.log('[WS] WebSocket GPS server initialized on /ws/gps');

  wss.on('connection', (ws, req) => {
    const params = url.parse(req.url, true).query;
    const { role, caseId, volunteerId } = params;

    if (!caseId || !role) {
      ws.close(4001, 'Missing caseId or role');
      return;
    }

    // Store metadata on the ws object
    ws.caseId = caseId;
    ws.role = role;
    ws.volunteerId = volunteerId || null;
    ws.isAlive = true;

    // Join room
    if (!rooms.has(caseId)) {
      rooms.set(caseId, { volunteers: new Set(), victims: new Set() });
    }
    const room = rooms.get(caseId);

    if (role === 'volunteer') {
      room.volunteers.add(ws);
    } else if (role === 'victim') {
      room.victims.add(ws);
    }

    console.log(`[WS] ${role} joined room ${caseId} (V:${room.volunteers.size} / N:${room.victims.size})`);

    // Send connection confirmation
    ws.send(JSON.stringify({
      type: 'connected',
      caseId,
      role,
      timestamp: new Date().toISOString(),
    }));

    // Handle incoming messages
    ws.on('message', (raw) => {
      try {
        const msg = JSON.parse(raw);
        handleMessage(ws, msg);
      } catch (err) {
        console.error('[WS] Invalid message:', err.message);
      }
    });

    // Pong for heartbeat
    ws.on('pong', () => {
      ws.isAlive = true;
    });

    // Cleanup on close
    ws.on('close', () => {
      removeFromRoom(ws);
    });

    ws.on('error', (err) => {
      console.error(`[WS] Error for ${role} in room ${caseId}:`, err.message);
      removeFromRoom(ws);
    });
  });

  // Heartbeat: ping every 30s, close dead connections
  const heartbeatInterval = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (ws.isAlive === false) {
        removeFromRoom(ws);
        return ws.terminate();
      }
      ws.isAlive = false;
      ws.ping();
    });
  }, 30000);

  wss.on('close', () => {
    clearInterval(heartbeatInterval);
  });

  return wss;
}

/**
 * Handle incoming WebSocket messages
 */
async function handleMessage(ws, msg) {
  switch (msg.type) {
    case 'gps_update': {
      if (ws.role !== 'volunteer') return;

      const { lat, lon } = msg;
      if (!lat || !lon) return;

      const caseId = ws.caseId;
      const volunteerId = ws.volunteerId;

      // 1. Save to DB (async, don't block)
      saveGpsToDb(volunteerId, lat, lon).catch(err => {
        console.error('[WS] DB save error:', err.message);
      });

      // 2. Calculate distance to victim
      let distanceM = null;
      try {
        const distResult = await db.query(`
          SELECT ROUND(ST_Distance(
            c.coords::geography,
            ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
          ))::int AS dist_m
          FROM cases c WHERE c.id = $3
        `, [lon, lat, caseId]);

        if (distResult.rows.length > 0) {
          distanceM = distResult.rows[0].dist_m;
        }
      } catch (err) {
        // Non-critical — still forward GPS
      }

      // 3. Forward GPS to all victims in the same room
      const room = rooms.get(caseId);
      if (room) {
        const payload = JSON.stringify({
          type: 'gps_update',
          lat,
          lon,
          distance_m: distanceM,
          volunteerId,
          timestamp: new Date().toISOString(),
        });

        for (const victim of room.victims) {
          if (victim.readyState === WebSocket.OPEN) {
            victim.send(payload);
          }
        }
      }

      break;
    }

    case 'chat': {
      const { content } = msg;
      if (!content || typeof content !== 'string' || !content.trim()) return;

      const caseId = ws.caseId;
      const senderRole = ws.role; // 'volunteer' or 'victim'
      const senderId = ws.volunteerId || null;

      // Lưu vào DB
      let savedMsg;
      try {
        const result = await saveChatMessage(caseId, senderRole, senderId, content.trim());
        savedMsg = result.rows[0];
      } catch (err) {
        console.error('[WS] Chat DB save error:', err.message);
        return;
      }

      // Forward cho bên còn lại trong room
      const room = rooms.get(caseId);
      if (!room) return;

      const payload = JSON.stringify({
        type: 'chat',
        senderRole,
        content: savedMsg.content,
        createdAt: savedMsg.created_at,
      });

      const targets = senderRole === 'volunteer' ? room.victims : room.volunteers;
      for (const peer of targets) {
        if (peer.readyState === WebSocket.OPEN) {
          peer.send(payload);
        }
      }

      // Echo lại cho chính người gửi (để confirm tin đã lưu)
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(payload);
      }

      break;
    }

    default:
      // Unknown message type — ignore
      break;
  }
}

/**
 * Broadcast a message to ALL clients (volunteers + victims) in a room.
 * Used by sosController to notify TNV when victim resolves a case.
 */
function broadcastToRoom(caseId, message) {
  const room = rooms.get(caseId);
  if (!room) return;

  const payload = JSON.stringify(message);
  let sent = 0;

  for (const ws of [...room.volunteers, ...room.victims]) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(payload);
      sent++;
    }
  }

  console.log(`[WS] Broadcast "${message.type}" to ${sent} client(s) in room ${caseId}`);
}

/**
 * Save volunteer GPS to database (same logic as locationController)
 */
async function saveGpsToDb(volunteerId, lat, lon) {
  if (!volunteerId) return;

  await db.query(
    `UPDATE volunteers 
     SET current_coords = ST_SetSRID(ST_MakePoint($1, $2), 4326), 
         last_seen_at = NOW()
     WHERE id = $3`,
    [lon, lat, volunteerId]
  );

  // Trigger distance check (async)
  setImmediate(() => {
    const { onVolunteerLocationUpdate } = require('../jobs/distanceTracker');
    const coordsWkt = `SRID=4326;POINT(${lon} ${lat})`;
    onVolunteerLocationUpdate(volunteerId, coordsWkt).catch(err => {
      console.error('[WS] Distance check error:', err.message);
    });
  });
}

/**
 * Remove a WebSocket client from its room
 */
function removeFromRoom(ws) {
  const { caseId, role } = ws;
  if (!caseId) return;

  const room = rooms.get(caseId);
  if (!room) return;

  if (role === 'volunteer') {
    room.volunteers.delete(ws);
  } else if (role === 'victim') {
    room.victims.delete(ws);
  }

  // Cleanup empty rooms
  if (room.volunteers.size === 0 && room.victims.size === 0) {
    rooms.delete(caseId);
  }

  console.log(`[WS] ${role} left room ${caseId} (V:${room.volunteers.size} / N:${room.victims.size})`);
}

module.exports = { initWebSocket, broadcastToRoom };
