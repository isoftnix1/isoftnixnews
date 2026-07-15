const { randomUUID } = require('crypto');
const { pool } = require('../config/db');

async function upsertDevice({ userId, fcmToken, deviceId, deviceName, manufacturer, model, platform, osVersion, appVersion, latitude, longitude, location_name }) {
  // Resolve conflicts for fcm_token by deleting stale records holding this token
  await pool.query(
    'DELETE FROM user_devices WHERE fcm_token = $1 AND (device_id != $2 OR user_id != $3)',
    [fcmToken, deviceId, userId]
  );

  const query = `
    INSERT INTO user_devices (
      user_id, fcm_token, device_id, device_name, manufacturer, model, 
      platform, os_version, app_version, latitude, longitude, location_name, app_status, notification_status, uninstall_detected_at, last_seen_at, updated_at
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'active', 'active', null, NOW(), NOW()
    ) ON CONFLICT (user_id, device_id) DO UPDATE SET 
      fcm_token = EXCLUDED.fcm_token,
      device_name = EXCLUDED.device_name,
      manufacturer = EXCLUDED.manufacturer,
      model = EXCLUDED.model,
      platform = EXCLUDED.platform,
      os_version = EXCLUDED.os_version,
      app_version = EXCLUDED.app_version,
      latitude = COALESCE(EXCLUDED.latitude, user_devices.latitude),
      longitude = COALESCE(EXCLUDED.longitude, user_devices.longitude),
      location_name = COALESCE(EXCLUDED.location_name, user_devices.location_name),
      app_status = 'active',
      notification_status = 'active',
      uninstall_detected_at = NULL,
      last_seen_at = NOW(),
      updated_at = NOW()
    RETURNING *;
  `;
  const values = [userId, fcmToken, deviceId, deviceName, manufacturer, model, platform, osVersion, appVersion, latitude, longitude, location_name];
  const result = await pool.query(query, values);
  return result.rows[0];
}

async function heartbeat(userId, deviceId, appVersion, osVersion, latitude, longitude, location_name) {
  const query = `
    UPDATE user_devices
    SET 
      app_version = COALESCE($1, app_version),
      os_version = COALESCE($2, os_version),
      latitude = COALESCE($3, latitude),
      longitude = COALESCE($4, longitude),
      location_name = COALESCE($5, location_name),
      last_seen_at = NOW(),
      app_status = 'active',
      updated_at = NOW()
    WHERE user_id = $6 AND device_id = $7
    RETURNING *;
  `;
  const result = await pool.query(query, [appVersion, osVersion, latitude, longitude, location_name, userId, deviceId]);
  return result.rows[0];
}

async function handleInvalidToken(fcmToken) {
  const query = `
    UPDATE user_devices
    SET 
      notification_status = 'invalid',
      app_status = 'possible_uninstalled',
      uninstall_detected_at = NOW(),
      updated_at = NOW()
    WHERE fcm_token = $1
    RETURNING *;
  `;
  const result = await pool.query(query, [fcmToken]);
  return result.rows[0];
}

async function updateNotificationSent(fcmTokens) {
  if (!fcmTokens || fcmTokens.length === 0) return;
  const query = `
    UPDATE user_devices
    SET 
      last_notification_sent_at = NOW(),
      last_notification_status = 'sent',
      updated_at = NOW()
    WHERE fcm_token = ANY($1::text[])
  `;
  await pool.query(query, [fcmTokens]);
}

async function getAdminDeviceList(filters = {}) {
  let query = `
    SELECT d.*, u.name as user_name, u.email as user_email, u.phone as user_phone
    FROM user_devices d
    JOIN users u ON d.user_id = u.id
    WHERE 1=1
  `;
  const values = [];
  let index = 1;

  if (filters.status && filters.status !== 'All') {
    if (filters.status === 'Active') {
      query += ` AND d.app_status = 'active'`;
    } else if (filters.status === 'Inactive') {
      query += ` AND d.app_status = 'inactive'`;
    } else if (filters.status === 'Possible Uninstalled') {
      query += ` AND d.app_status = 'possible_uninstalled'`;
    }
  }

  if (filters.platform && filters.platform !== 'All') {
    query += ` AND d.platform = $${index++}`;
    values.push(filters.platform.toLowerCase());
  }

  query += ` ORDER BY d.last_seen_at DESC LIMIT 1000`; // Safety limit for now
  
  const result = await pool.query(query, values);
  return result.rows;
}

async function getAdminDeviceAnalytics() {
  const query = `
    SELECT 
      COUNT(*) FILTER (WHERE app_status = 'active') as active_users,
      COUNT(*) FILTER (WHERE app_status = 'inactive') as inactive_users,
      COUNT(*) FILTER (WHERE app_status = 'possible_uninstalled') as possible_uninstalled,
      COUNT(*) FILTER (WHERE platform = 'android') as android_users,
      COUNT(*) FILTER (WHERE platform = 'ios') as ios_users
    FROM user_devices;
  `;
  const result = await pool.query(query);
  return result.rows[0];
}

async function cleanupStaleTokens() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Mark inactive
    const markInactiveQuery = `
      UPDATE user_devices
      SET app_status = 'inactive', updated_at = NOW()
      WHERE app_status = 'active' AND last_seen_at < NOW() - INTERVAL '2 days';
    `;
    const inactiveResult = await client.query(markInactiveQuery);

    // Delete invalid older than 30 days
    const deleteQuery = `
      DELETE FROM user_devices
      WHERE notification_status = 'invalid' AND uninstall_detected_at < NOW() - INTERVAL '30 days';
    `;
    const deleteResult = await client.query(deleteQuery);

    await client.query('COMMIT');
    return {
      markedInactive: inactiveResult.rowCount,
      deletedInvalid: deleteResult.rowCount
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

module.exports = {
  upsertDevice,
  heartbeat,
  handleInvalidToken,
  updateNotificationSent,
  getAdminDeviceList,
  getAdminDeviceAnalytics,
  cleanupStaleTokens
};
