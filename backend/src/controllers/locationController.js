/**
 * Location Controller — POST /api/location
 * Module 3: TNV GPS tracking
 */

const { db } = require('../db');

/**
 * POST /api/location — TNV gửi GPS update
 */
async function updateVolunteerLocation(req, res) {
  try {
    const { lat, lon, volunteerId } = req.body;

    if (!lat || !lon || !volunteerId) {
      return res.status(400).json({ error: 'Missing lat, lon, or volunteerId' });
    }

    // Cập nhật vị trí TNV
    await db.query(
      `UPDATE volunteers 
       SET current_coords = ST_SetSRID(ST_MakePoint($1, $2), 4326), 
           last_seen_at = NOW()
       WHERE id = $3`,
      [lon, lat, volunteerId]
    );

    // Trigger distance check (async — không block response)
    setImmediate(() => {
      const { onVolunteerLocationUpdate } = require('../jobs/distanceTracker');
      const coordsWkt = `SRID=4326;POINT(${lon} ${lat})`;
      onVolunteerLocationUpdate(volunteerId, coordsWkt).catch(err => {
        console.error('[locationController] Distance check error:', err.message);
      });
    });

    res.status(200).json({ ok: true });
  } catch (err) {
    console.error('[locationController][updateVolunteerLocation]', err.message);
    res.status(500).json({ error: 'Internal error' });
  }
}

module.exports = { updateVolunteerLocation };
