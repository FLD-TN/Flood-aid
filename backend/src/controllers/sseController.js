/**
 * SSE Controller — Server-Sent Events for case status updates
 * Replaces client-side polling with push-based real-time updates.
 * 
 * Events emitted:
 *   case:accepted  — TNV nhận ca
 *   case:resolved  — Ca đã đóng
 *   case:cancelled — Nạn nhân hủy
 *   case:orphaned  — Không ai nhận sau 15 phút
 */

// Map: caseId -> Set<response>
const caseStreams = new Map();

/**
 * GET /api/case/:id/stream — SSE stream for a specific case
 */
function streamCase(req, res) {
  const { id } = req.params;

  // SSE headers
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'X-Accel-Buffering': 'no', // Disable nginx buffering
  });

  // Send initial connection event
  res.write(`event: connected\ndata: ${JSON.stringify({ caseId: id, timestamp: new Date().toISOString() })}\n\n`);

  // Register client
  if (!caseStreams.has(id)) {
    caseStreams.set(id, new Set());
  }
  caseStreams.get(id).add(res);

  console.log(`[SSE] Client connected to case ${id} (${caseStreams.get(id).size} total)`);

  // Heartbeat every 30s to keep connection alive
  const heartbeat = setInterval(() => {
    res.write(`:heartbeat\n\n`);
  }, 30000);

  // Cleanup on disconnect
  req.on('close', () => {
    clearInterval(heartbeat);
    const clients = caseStreams.get(id);
    if (clients) {
      clients.delete(res);
      if (clients.size === 0) {
        caseStreams.delete(id);
      }
    }
    console.log(`[SSE] Client disconnected from case ${id} (${caseStreams.get(id)?.size ?? 0} remaining)`);
  });
}

/**
 * Emit an event to all clients listening to a specific case.
 * Called by other controllers (sosController, geoDispatch) when state changes.
 * 
 * @param {string} caseId 
 * @param {string} event - Event name (e.g. 'case:accepted')
 * @param {object} data - Event payload
 */
function emitCaseEvent(caseId, event, data) {
  const clients = caseStreams.get(caseId);
  if (!clients || clients.size === 0) return;

  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;

  for (const res of clients) {
    try {
      res.write(payload);
    } catch (err) {
      console.error(`[SSE] Error writing to client for case ${caseId}:`, err.message);
      clients.delete(res);
    }
  }

  console.log(`[SSE] Emitted "${event}" to ${clients.size} client(s) for case ${caseId}`);
}

/**
 * Get count of active SSE connections (for monitoring)
 */
function getActiveConnections() {
  let total = 0;
  for (const [, clients] of caseStreams) {
    total += clients.size;
  }
  return { totalConnections: total, totalCases: caseStreams.size };
}

module.exports = { streamCase, emitCaseEvent, getActiveConnections };
