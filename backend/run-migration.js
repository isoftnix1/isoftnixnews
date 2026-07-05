require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

async function runMigration() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/isoftnix_news',
  });

  try {
    await client.connect();
    const sql = fs.readFileSync(path.join(__dirname, 'sql', '01_optimized_news_tracking.sql'), 'utf8');
    await client.query(sql);
    console.log('Migration executed successfully.');
  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    await client.end();
  }
}

runMigration();
