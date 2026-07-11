require('dotenv').config();
const { pool } = require('./config/db');

async function migrate() {
  try {
    await pool.query('ALTER TABLE user_devices ADD COLUMN latitude NUMERIC(10, 8), ADD COLUMN longitude NUMERIC(11, 8);');
    console.log('Migration done');
  } catch(e) {
    if (e.code === '42701') {
      console.log('Columns already exist');
    } else {
      console.error('Migration failed:', e);
      process.exit(1);
    }
  } finally {
    process.exit(0);
  }
}

migrate();
