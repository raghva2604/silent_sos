const { pool } = require('../db');
const { broadcastLocation } = require('../websocket/socket');

async function ensureTrackingTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS live_tracking (
      id SERIAL PRIMARY KEY,
      user_id TEXT,
      latitude DOUBLE PRECISION,
      longitude DOUBLE PRECISION,
      battery DOUBLE PRECISION,
      risk_score DOUBLE PRECISION,
      status TEXT,
      speed DOUBLE PRECISION,
      fall_detected BOOLEAN,
      network TEXT,
      device_motion TEXT,
      background_tracking BOOLEAN,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await pool.query(`ALTER TABLE live_tracking ADD COLUMN IF NOT EXISTS fall_detected BOOLEAN`);
  await pool.query(`ALTER TABLE live_tracking ADD COLUMN IF NOT EXISTS network TEXT`);
  await pool.query(`ALTER TABLE live_tracking ADD COLUMN IF NOT EXISTS device_motion TEXT`);
  await pool.query(`ALTER TABLE live_tracking ADD COLUMN IF NOT EXISTS background_tracking BOOLEAN`);
}

function formatLiveRow(row) {
  return {
    type: 'location',
    userId: row.user_id,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    battery: row.battery,
    riskScore: row.risk_score,
    status: row.status,
    speed: row.speed,
    fallDetected: Boolean(row.fall_detected),
    network: row.network || null,
    deviceMotion: row.device_motion || null,
    backgroundTracking: Boolean(row.background_tracking),
    updatedAt: row.created_at ? row.created_at.toISOString() : new Date().toISOString(),
  };
}

exports.updateLocation = async (req, res) => {
  try {
    await ensureTrackingTable();

    const {
      userId,
      latitude,
      longitude,
      battery,
      riskScore,
      status,
      speed,
      fallDetected,
      network,
      deviceMotion,
      backgroundTracking,
    } = req.body;

    const query = `
      INSERT INTO live_tracking
        (user_id, latitude, longitude, battery, risk_score, status, speed, fall_detected, network, device_motion, background_tracking)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *;
    `;

    const values = [
      userId,
      latitude,
      longitude,
      battery,
      riskScore,
      status,
      speed,
      fallDetected,
      network,
      deviceMotion,
      backgroundTracking,
    ];

    const result = await pool.query(query, values);
    const row = result.rows[0];

    broadcastLocation(formatLiveRow(row));

    return res.status(200).json({
      success: true,
      data: row,
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getLatestLocations = async (req, res) => {
  try {
    await ensureTrackingTable();

    const query = `
      SELECT DISTINCT ON (user_id)
        user_id,
        latitude,
        longitude,
        battery,
        risk_score,
        status,
        speed,
        fall_detected,
        network,
        device_motion,
        background_tracking,
        created_at
      FROM live_tracking
      ORDER BY user_id, created_at DESC;
    `;

    const result = await pool.query(query);

    return res.status(200).json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateLiveLocation = exports.updateLocation;
