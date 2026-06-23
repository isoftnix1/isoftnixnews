const { randomUUID } = require('crypto');
const { pool } = require('../config/db');

async function registerDeviceToken({ userId, token }) {
  const id = randomUUID();
  await pool.query(
    `INSERT INTO device_tokens (id, user_id, token)
     VALUES ($1, $2, $3)
     ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, updated_at = NOW()`,
    [id, userId, token]
  );
  return { id, userId, token };
}

async function getTokensForUser(userId) {
  const result = await pool.query(
    'SELECT token FROM device_tokens WHERE user_id = $1',
    [userId]
  );
  return result.rows.map((row) => row.token);
}

async function getAllTokens() {
  const result = await pool.query('SELECT token FROM device_tokens');
  return result.rows.map((row) => row.token);
}

async function createNotification({ userId, title, body, data = {} }) {
  const id = randomUUID();
  const result = await pool.query(
    `INSERT INTO notifications (id, user_id, title, body, data)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [id, userId, title, body, JSON.stringify(data)]
  );
  return result.rows[0];
}

async function getNotificationsForUser(userId, limit = 20) {
  const result = await pool.query(
    `SELECT id, title, body, data, is_read, created_at
     FROM notifications
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows;
}

module.exports = {
  registerDeviceToken,
  getTokensForUser,
  getAllTokens,
  createNotification,
  getNotificationsForUser,
};
