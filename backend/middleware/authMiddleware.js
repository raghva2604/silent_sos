const { pool } = require('../db');
const { verifyToken } = require('../services/jwt');
const { sendError } = require('../services/response');

async function authMiddleware(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;

    if (!token) {
      return sendError(res, 401, 'Authentication token required');
    }

    const decoded = verifyToken(token, process.env.JWT_SECRET || 'silent-sos-secret');
    const result = await pool.query(
      'SELECT id, name, email, role, created_at FROM users WHERE id = $1',
      [decoded.sub]
    );

    if (result.rows.length === 0) {
      return sendError(res, 401, 'User not found');
    }

    req.user = result.rows[0];
    return next();
  } catch (error) {
    console.error('Auth middleware error:', error.message);
    return sendError(res, 401, 'Invalid or expired token');
  }
}

module.exports = authMiddleware;
