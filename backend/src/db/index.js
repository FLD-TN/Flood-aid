const { Pool } = require('pg');

let pool;

/**
 * Initialize PostgreSQL connection pool
 */
async function initDb() {
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
  });

  // Test connection
  const client = await pool.connect();
  try {
    await client.query('SELECT 1');
    console.log('[DB] Connection test successful');
  } finally {
    client.release();
  }

  return pool;
}

/**
 * Database query wrapper
 */
const db = {
  query: (text, params) => {
    if (!pool) throw new Error('Database not initialized');
    return pool.query(text, params);
  },
  getPool: () => pool,
};

module.exports = { initDb, db };
