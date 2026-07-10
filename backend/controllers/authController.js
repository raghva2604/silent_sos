const crypto = require('crypto');
const { pool } = require('../db');
const { generateToken } = require('../services/jwt');
const { sendSuccess, sendError } = require('../services/response');

async function ensureUsersTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT DEFAULT 'user',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex');
}

exports.register = async (req, res) => {
  try {
    await ensureUsersTable();

    const { name, email, password, role = 'user' } = req.body || {};

    if (!name || !email || !password) {
      return sendError(res, 400, 'Name, email, and password are required');
    }

    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return sendError(res, 409, 'Email already registered');
    }

    const passwordHash = hashPassword(password);
    const result = await pool.query(
      'INSERT INTO users (name, email, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING id, name, email, role, created_at',
      [name, email, passwordHash, role]
    );

    const user = result.rows[0];
    const token = generateToken({ sub: user.id, role: user.role }, process.env.JWT_SECRET || 'silent-sos-secret');

    return sendSuccess(res, 201, {
      user,
      token,
    }, 'User registered successfully');
  } catch (error) {
    console.error('Register error:', error.message);
    return sendError(res, 500, 'Registration failed', error.message);
  }
};

exports.login = async (req, res) => {
  try {
    await ensureUsersTable();

    const { email, password } = req.body || {};

    if (!email || !password) {
      return sendError(res, 400, 'Email and password are required');
    }

    const result = await pool.query(
      'SELECT id, name, email, role, password_hash, created_at FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return sendError(res, 401, 'Invalid credentials');
    }

    const user = result.rows[0];
    const passwordHash = hashPassword(password);

    if (user.password_hash !== passwordHash) {
      return sendError(res, 401, 'Invalid credentials');
    }

    const token = generateToken({ sub: user.id, role: user.role }, process.env.JWT_SECRET || 'silent-sos-secret');

    return sendSuccess(res, 200, {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        created_at: user.created_at,
      },
      token,
    }, 'Login successful');
  } catch (error) {
    console.error('Login error:', error.message);
    return sendError(res, 500, 'Login failed', error.message);
  }
};

exports.me = async (req, res) => {
  return sendSuccess(res, 200, req.user, 'Authenticated user profile');
};
