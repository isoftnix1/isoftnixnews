require('dotenv').config();
const { pool } = require('../config/db');

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Starting migration...');
    await client.query('BEGIN');

    // 1. Alter notifications table to allow null user_id (for global announcements)
    await client.query(`
      ALTER TABLE notifications 
      ALTER COLUMN user_id DROP NOT NULL;
    `);
    console.log('Altered notifications table.');

    // 2. Create user_read_notifications table
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_read_notifications (
          user_id UUID REFERENCES users(id) ON DELETE CASCADE,
          notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
          read_at TIMESTAMP DEFAULT NOW(),
          PRIMARY KEY (user_id, notification_id)
      );
    `);
    console.log('Created user_read_notifications table.');

    // 3. Create user_hidden_notifications table
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_hidden_notifications (
          user_id UUID REFERENCES users(id) ON DELETE CASCADE,
          notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
          hidden_at TIMESTAMP DEFAULT NOW(),
          PRIMARY KEY (user_id, notification_id)
      );
    `);
    console.log('Created user_hidden_notifications table.');

    await client.query('COMMIT');
    console.log('Migration completed successfully.');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', error);
  } finally {
    client.release();
    process.exit(0);
  }
}

runMigration();
