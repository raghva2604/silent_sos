require('dotenv').config();
const { Pool } = require('pg');

const baseConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'postgres'
};

if (process.env.DB_PASSWORD) {
  baseConfig.password = process.env.DB_PASSWORD;
}

const pool = new Pool({
  ...baseConfig,
  database: process.env.DB_NAME || 'silent_sos'
});

async function connectWithConfig(config) {
  const tempPool = new Pool(config);
  try {
    await tempPool.query('SELECT NOW()');
    return tempPool;
  } catch (error) {
    await tempPool.end().catch(() => {});
    throw error;
  }
}

async function connectDb() {
  const targetDb = process.env.DB_NAME || 'silent_sos';

  try {
    await pool.query('SELECT NOW()');
    console.log('✅ PostgreSQL Connected');
    return true;
  } catch (error) {
    if (error.code === '3D000') {
      try {
        const adminPool = await connectWithConfig({ ...baseConfig, database: 'postgres' });
        await adminPool.query(`CREATE DATABASE "${targetDb}"`);
        await adminPool.end();
        await pool.query('SELECT NOW()');
        console.log('✅ PostgreSQL Connected');
        return true;
      } catch (createError) {
        console.error('⚠️ PostgreSQL connection failed:', createError.message);
        return false;
      }
    }

    if (error.message && error.message.includes('password authentication failed')) {
      try {
        const fallbackPool = await connectWithConfig({ ...baseConfig, database: 'postgres' });
        await fallbackPool.end();
        await pool.query('SELECT NOW()');
        console.log('✅ PostgreSQL Connected');
        return true;
      } catch (fallbackError) {
        console.error('⚠️ PostgreSQL connection failed:', fallbackError.message);
        return false;
      }
    }

    console.error('⚠️ PostgreSQL connection failed:', error.message);
    return false;
  }
}

module.exports = { pool, connectDb };
