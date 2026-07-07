const { pool } = require('../config/db');

class AuthSecurity {
  // ===============================
  // Refresh Tokens
  // ===============================
  static async createRefreshToken(data) {
    const { user_id, device_id, device_name, platform, ip_address, user_agent, token_hash, expires_at } = data;
    const query = `
      INSERT INTO refresh_tokens 
        (user_id, device_id, device_name, platform, ip_address, user_agent, token_hash, expires_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *;
    `;
    const result = await pool.query(query, [user_id, device_id, device_name, platform, ip_address, user_agent, token_hash, expires_at]);
    return result.rows[0];
  }

  static async getRefreshToken(token_hash) {
    const query = `
      SELECT * FROM refresh_tokens
      WHERE token_hash = $1;
    `;
    const result = await pool.query(query, [token_hash]);
    return result.rows[0];
  }

  static async revokeRefreshToken(id) {
    const query = `
      UPDATE refresh_tokens
      SET revoked = TRUE, revoked_at = NOW(), updated_at = NOW()
      WHERE id = $1
      RETURNING *;
    `;
    const result = await pool.query(query, [id]);
    return result.rows[0];
  }

  static async updateLastUsed(id) {
    const query = `
      UPDATE refresh_tokens
      SET last_used_at = NOW(), updated_at = NOW()
      WHERE id = $1;
    `;
    await pool.query(query, [id]);
  }

  static async revokeAllRefreshTokens(user_id) {
    const query = `
      UPDATE refresh_tokens
      SET revoked = TRUE, revoked_at = NOW(), updated_at = NOW()
      WHERE user_id = $1 AND revoked = FALSE
      RETURNING *;
    `;
    const result = await pool.query(query, [user_id]);
    return result.rows;
  }

  static async deleteExpiredOrRevokedTokens() {
    const query = `
      DELETE FROM refresh_tokens
      WHERE revoked = TRUE OR expires_at < NOW();
    `;
    const result = await pool.query(query);
    return result.rowCount;
  }

  // ===============================
  // Login Attempts & Lockout
  // ===============================
  static async getLoginAttempt(email) {
    const query = `
      SELECT * FROM login_attempts WHERE email = $1;
    `;
    const result = await pool.query(query, [email]);
    return result.rows[0];
  }

  static async recordFailedAttempt(email) {
    // Upsert logic for failed attempt
    const query = `
      INSERT INTO login_attempts (email, attempts, last_attempt_at)
      VALUES ($1, 1, NOW())
      ON CONFLICT (email)
      DO UPDATE SET 
        attempts = login_attempts.attempts + 1,
        last_attempt_at = NOW()
      RETURNING *;
    `;
    const result = await pool.query(query, [email]);
    return result.rows[0];
  }

  static async lockAccount(email, lockedUntil) {
    const query = `
      UPDATE login_attempts
      SET locked_until = $2
      WHERE email = $1
      RETURNING *;
    `;
    const result = await pool.query(query, [email, lockedUntil]);
    return result.rows[0];
  }

  static async resetLoginAttempts(email) {
    const query = `
      DELETE FROM login_attempts WHERE email = $1;
    `;
    await pool.query(query, [email]);
  }

  // ===============================
  // Security Logs
  // ===============================
  static async logSecurityEvent(user_id, event_type, ip_address, user_agent, details = {}) {
    const query = `
      INSERT INTO security_logs (user_id, event_type, ip_address, user_agent, details)
      VALUES ($1, $2, $3, $4, $5);
    `;
    await pool.query(query, [user_id, event_type, ip_address, user_agent, JSON.stringify(details)]);
  }

  // ===============================
  // Trusted Devices
  // ===============================
  static async getTrustedDevice(user_id, device_id) {
    const query = `
      SELECT * FROM trusted_devices 
      WHERE user_id = $1 AND device_id = $2;
    `;
    const result = await pool.query(query, [user_id, device_id]);
    return result.rows[0];
  }

  static async registerTrustedDevice(data) {
    const { user_id, device_id, device_name, platform, manufacturer, model } = data;
    const query = `
      INSERT INTO trusted_devices 
        (user_id, device_id, device_name, platform, manufacturer, model)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (user_id, device_id) 
      DO UPDATE SET 
        last_login_at = NOW(),
        updated_at = NOW()
      RETURNING *;
    `;
    const result = await pool.query(query, [user_id, device_id, device_name, platform, manufacturer, model]);
    return result.rows[0];
  }

  static async countAdminTrustedDevices(user_id) {
    const query = `
      SELECT COUNT(*) FROM trusted_devices 
      WHERE user_id = $1 AND is_trusted = TRUE;
    `;
    const result = await pool.query(query, [user_id]);
    return parseInt(result.rows[0].count, 10);
  }

  // ===============================
  // Admin Hardware Logs
  // ===============================
  static async recordFailedAdminHardwareAttempt({ email, ip_address, fingerprint, user_agent, device_info }) {
    const query = `
      INSERT INTO failed_admin_hardware_attempts (email, ip_address, fingerprint, user_agent, device_info, status)
      VALUES ($1, $2, $3, $4, $5, 'BLOCKED')
      RETURNING *;
    `;
    const result = await pool.query(query, [email, ip_address, fingerprint, user_agent, device_info]);
    return result.rows[0];
  }

  static async countFailedAdminHardwareAttempts(email, minutes = 30) {
    const query = `
      SELECT COUNT(*) FROM failed_admin_hardware_attempts 
      WHERE email = $1 AND created_at >= NOW() - INTERVAL '${minutes} minutes';
    `;
    const result = await pool.query(query, [email]);
    return parseInt(result.rows[0].count, 10);
  }

  static async getPendingDevices(email, limit = 5) {
    const query = `
      SELECT id, fingerprint, ip_address, user_agent, created_at, status, device_info
      FROM failed_admin_hardware_attempts 
      WHERE email = $1 AND status = 'BLOCKED'
      ORDER BY created_at DESC
      LIMIT $2;
    `;
    const result = await pool.query(query, [email, limit]);
    return result.rows;
  }
}

module.exports = AuthSecurity;
