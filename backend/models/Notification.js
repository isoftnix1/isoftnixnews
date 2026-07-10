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

async function createGlobalNotification(title, body, data = {}) {
  const result = await pool.query(
    `INSERT INTO notifications (id, user_id, title, body, data)
     VALUES (gen_random_uuid(), NULL, $1, $2, $3::jsonb)
     RETURNING *`,
    [title, body, JSON.stringify(data)]
  );
  return result.rows[0];
}

async function getNotificationsForUser(userId, limit = 20) {
  const result = await pool.query(
    `SELECT n.id, n.title, n.body, n.data, n.created_at,
            CASE 
               WHEN n.user_id IS NOT NULL THEN n.is_read
               WHEN urn.notification_id IS NOT NULL THEN true
               ELSE false 
            END as is_read
     FROM notifications n
     LEFT JOIN user_read_notifications urn 
            ON n.id = urn.notification_id AND urn.user_id = $1
     WHERE (n.user_id = $1 OR n.user_id IS NULL)
       AND n.id NOT IN (SELECT notification_id FROM user_hidden_notifications WHERE user_id = $1)
     ORDER BY n.created_at DESC
     LIMIT $2`,
    [userId, limit]
  );
  return result.rows;
}

async function markAsRead(notificationId, userId) {
  // First update if it's a personal notification
  const result = await pool.query(
    `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING *`,
    [notificationId, userId]
  );
  
  if (result.rowCount === 0) {
    // If not found, it might be a global notification, insert into user_read_notifications
    await pool.query(
      `INSERT INTO user_read_notifications (user_id, notification_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [userId, notificationId]
    );
  }
  return true;
}

async function deleteNotificationForUser(notificationId, userId) {
  // Insert into hidden tracking for global notifications
  await pool.query(
    `INSERT INTO user_hidden_notifications (user_id, notification_id)
     VALUES ($1, $2)
     ON CONFLICT DO NOTHING`,
    [userId, notificationId]
  );
  
  // Also delete from notifications if it's a personal notification
  const result = await pool.query(
    `DELETE FROM notifications
     WHERE id = $1 AND user_id = $2
     RETURNING *`,
    [notificationId, userId]
  );
  return true; // We return true because even if rowCount=0, it might be global and was hidden successfully
}

module.exports = {
  registerDeviceToken,
  getTokensForUser,
  getAllTokens,
  getTokensGroupedByLanguage,
  createNotification,
  createGlobalNotification,
  getNotificationsForUser,
  markAsRead,
  deleteNotificationForUser,
};
