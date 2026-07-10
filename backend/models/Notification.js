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
    `SELECT fcm_token as token FROM user_devices WHERE user_id = $1 AND notification_status = 'active'
     UNION
     SELECT token FROM device_tokens WHERE user_id = $1`,
    [userId]
  );
  return result.rows.map((row) => row.token);
}

async function getAllTokens() {
  const result = await pool.query(`
    SELECT fcm_token as token FROM user_devices WHERE notification_status = 'active'
    UNION
    SELECT token FROM device_tokens
  `);
  return result.rows.map((row) => row.token);
}

async function getTokensGroupedByLanguage() {
  const result = await pool.query(`
    SELECT dt.fcm_token as token, COALESCE(u.preferred_language, 'en') as lang
    FROM user_devices dt
    LEFT JOIN users u ON dt.user_id = u.id
    WHERE dt.notification_status = 'active'
    UNION
    SELECT dt.token, COALESCE(u.preferred_language, 'en') as lang
    FROM device_tokens dt
    LEFT JOIN users u ON dt.user_id = u.id
  `);
  
  const grouped = { en: [], hi: [], mr: [] };
  
  result.rows.forEach(row => {
    const lang = row.lang;
    if (grouped[lang]) {
      grouped[lang].push(row.token);
    } else {
      grouped['en'].push(row.token);
    }
  });
  
  return grouped;
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

async function deleteNotificationForUser(notificationId, userId) {
  const result = await pool.query(
    `DELETE FROM notifications
     WHERE id = $1 AND user_id = $2
     RETURNING *`,
    [notificationId, userId]
  );
  return result.rowCount > 0;
}

module.exports = {
  registerDeviceToken,
  getTokensForUser,
  getAllTokens,
  getTokensGroupedByLanguage,
  createNotification,
  getNotificationsForUser,
  deleteNotificationForUser,
};
