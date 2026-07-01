/**
 * Admin password reset utility.
 *
 * Usage:
 *   node reset-password.js <email> <newPassword>
 *   node reset-password.js <email>             ← generates a secure random password
 *
 * NEVER run this with a hardcoded password.
 */
require('dotenv').config();
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { pool } = require('./config/db');

async function run() {
  const email = process.argv[2];
  let newPassword = process.argv[3];

  if (!email) {
    console.error('Usage: node reset-password.js <email> [newPassword]');
    process.exit(1);
  }

  // If no password supplied, generate a secure random one
  if (!newPassword) {
    // 16 random bytes → 22-char base64url string, then pad with fixed suffix
    // to guarantee it meets the password policy (upper + lower + digit + special)
    const rand = crypto.randomBytes(12).toString('base64url'); // ~16 chars
    newPassword = `${rand.charAt(0).toUpperCase()}${rand.slice(1)}@1`;
    console.log(`\n⚠️  No password provided. Generated secure password:\n\n  ${newPassword}\n\nStore this somewhere safe — it will not be shown again.\n`);
  }

  // Validate against the production password policy before touching the DB
  const policyRegex = /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$/;
  if (!policyRegex.test(newPassword)) {
    console.error(
      'Password does not meet the production policy.\n' +
      'Requirements: 8+ chars, uppercase, lowercase, number, special char (@$!%*#?&)'
    );
    process.exit(1);
  }

  try {
    const hash = await bcrypt.hash(newPassword, 12);
    const result = await pool.query(
      'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE email = $2 RETURNING email',
      [hash, email]
    );

    if (result.rowCount === 0) {
      console.error(`No user found with email: ${email}`);
      process.exit(1);
    }

    console.log(`✅ Password updated successfully for ${result.rows[0].email}`);
  } catch (err) {
    console.error('Database error:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

run();
