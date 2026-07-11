const { randomUUID } = require('crypto');
const { pool } = require('../config/db');

async function createUser({ name, email, phone = null, passwordHash, role = 'user' }) {
  const id = randomUUID();
  const result = await pool.query(
    `INSERT INTO users (id, name, email, phone, password_hash, role)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, name, email, phone, role, preferred_language, created_at`,
    [id, name, email, phone, passwordHash, role]
  );
  return result.rows[0];
}

async function findByEmail(email) {
  const result = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  );
  return result.rows[0] || null;
}

async function findById(id) {
  const result = await pool.query(
    'SELECT id, name, email, phone, role, preferred_language, created_at FROM users WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}

async function findAuthUserById(id) {
  const result = await pool.query(
    'SELECT id, email, role, is_active FROM users WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}

async function updateUser(id, updates) {
  const fields = Object.entries(updates)
    .filter(([, value]) => value !== undefined)
    .map(([key], index) => `${key} = $${index + 2}`);

  if (!fields.length) return null;

  const values = [id, ...Object.values(updates).filter((value) => value !== undefined)];

  const result = await pool.query(
    `UPDATE users SET ${fields.join(', ')} WHERE id = $1 RETURNING id, name, email, phone, role, preferred_language, created_at`,
    values
  );
  return result.rows[0] || null;
}

async function getAllUsers() {
  const result = await pool.query('SELECT id FROM users');
  return result.rows;
}

async function setPasswordResetOtp(userId, otpHash, expiry) {
  await pool.query(
    `UPDATE users
     SET reset_otp_hash = $2,
         reset_otp_expiry = $3,
         password_reset_version = password_reset_version + 1,
         updated_at = NOW()
     WHERE id = $1`,
    [userId, otpHash, expiry]
  );
}

async function clearPasswordResetOtp(userId) {
  await pool.query(
    `UPDATE users
     SET reset_otp_hash = NULL,
         reset_otp_expiry = NULL,
         updated_at = NOW()
     WHERE id = $1`,
    [userId]
  );
}

async function findByEmailForPasswordReset(email) {
  const result = await pool.query(
    `SELECT id, email, is_active, reset_otp_hash, reset_otp_expiry, password_reset_version
     FROM users
     WHERE email = $1`,
    [email]
  );
  return result.rows[0] || null;
}

async function completePasswordReset(userId, passwordHash) {
  await pool.query(
    `UPDATE users
     SET password_hash = $2,
         reset_otp_hash = NULL,
         reset_otp_expiry = NULL,
         password_reset_version = password_reset_version + 1,
         updated_at = NOW()
     WHERE id = $1`,
    [userId, passwordHash]
  );
}

async function deleteUser(id) {
  const result = await pool.query(
    'DELETE FROM users WHERE id = $1 RETURNING id',
    [id]
  );
  return result.rowCount > 0;
}

module.exports = {
  createUser,
  findByEmail,
  findById,
  findAuthUserById,
  updateUser,
  getAllUsers,
  setPasswordResetOtp,
  clearPasswordResetOtp,
  findByEmailForPasswordReset,
  completePasswordReset,
  deleteUser,
};
