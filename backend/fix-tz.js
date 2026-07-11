require('dotenv').config();
const { pool } = require('./config/db');

async function fixTimezones() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    console.log('Altering news.published_at to TIMESTAMPTZ...');
    await client.query(`ALTER TABLE news ALTER COLUMN published_at TYPE TIMESTAMPTZ USING published_at AT TIME ZONE 'UTC'`);
    
    console.log('Altering other timestamp columns to TIMESTAMPTZ...');
    await client.query(`ALTER TABLE news ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC'`);
    await client.query(`ALTER TABLE news ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC'`);
    
    await client.query(`ALTER TABLE users ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC'`);
    await client.query(`ALTER TABLE users ALTER COLUMN updated_at TYPE TIMESTAMPTZ USING updated_at AT TIME ZONE 'UTC'`);
    
    await client.query('COMMIT');
    console.log('SUCCESS: All timezones updated to TIMESTAMPTZ!');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error during migration:', err);
  } finally {
    client.release();
    pool.end();
  }
}

fixTimezones();
