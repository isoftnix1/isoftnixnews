const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

async function setupDb() {
  if (!process.env.DATABASE_URL) {
    console.error('❌ FATAL: DATABASE_URL environment variable is required. Set it in your .env file.');
    process.exit(1);
  }

  const client = new Client({
    connectionString: process.env.DATABASE_URL,
  });

  try {
    await client.connect();
    console.log('Connected to database.');

    const schemaPath = path.join(__dirname, 'sql', 'schema.sql');
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');
    
    console.log('Executing schema.sql...');
    await client.query(schemaSql);
    console.log('Schema executed successfully.');

    const seedPath = path.join(__dirname, 'sql', 'seed.sql');
    if (fs.existsSync(seedPath)) {
      const seedSql = fs.readFileSync(seedPath, 'utf8');
      console.log('Executing seed.sql...');
      await client.query(seedSql);
      console.log('Seed executed successfully.');
    }
  } catch (error) {
    console.error('Error setting up database:', error);
  } finally {
    await client.end();
    console.log('Database connection closed.');
  }
}

setupDb();
