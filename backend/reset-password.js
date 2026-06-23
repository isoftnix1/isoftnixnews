require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool } = require('./config/db');

async function run() {
  try {
    const hash = await bcrypt.hash('admin123', 10);
    await pool.query('UPDATE users SET password_hash = $1 WHERE email = $2', [hash, 'admin@isoftnix.com']);
    console.log('Password updated successfully');
  } catch (err) {
    console.error(err);
  } finally {
    process.exit(0);
  }
}

run();
