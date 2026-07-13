require('dotenv').config({ path: '../.env' });
const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');

async function runMigration() {
  try {
    const sqlPath = path.join(__dirname, '../sql/10_chat_history.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    
    console.log('Running chat history migration...');
    await pool.query(sql);
    console.log('Migration successful!');
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
