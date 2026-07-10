const { pool } = require('../db');
const { sendSuccess, sendError } = require('../services/response');

async function ensureComplaintsTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS complaints (
      id SERIAL PRIMARY KEY,
      user_id INTEGER,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT,
      status TEXT DEFAULT 'pending',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

exports.createComplaint = async (req, res) => {
  try {
    await ensureComplaintsTable();

    const { title, description, category } = req.body || {};
    if (!title || !description) {
      return sendError(res, 400, 'Title and description are required');
    }

    const result = await pool.query(
      'INSERT INTO complaints (user_id, title, description, category) VALUES ($1, $2, $3, $4) RETURNING *',
      [req.user?.id || null, title, description, category || 'general']
    );

    return sendSuccess(res, 201, result.rows[0], 'Complaint submitted successfully');
  } catch (error) {
    console.error('Create complaint error:', error.message);
    return sendError(res, 500, 'Failed to submit complaint', error.message);
  }
};

exports.listComplaints = async (req, res) => {
  try {
    await ensureComplaintsTable();

    const query = req.user?.role === 'admin'
      ? 'SELECT * FROM complaints ORDER BY created_at DESC'
      : 'SELECT * FROM complaints WHERE user_id = $1 ORDER BY created_at DESC';
    const values = req.user?.role === 'admin' ? [] : [req.user?.id];

    const result = await pool.query(query, values);
    return sendSuccess(res, 200, result.rows, 'Complaints retrieved successfully');
  } catch (error) {
    console.error('List complaints error:', error.message);
    return sendError(res, 500, 'Failed to retrieve complaints', error.message);
  }
};
