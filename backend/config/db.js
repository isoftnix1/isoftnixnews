const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }, // Neon strictly requires SSL even in development
  connectionTimeoutMillis: 60000,
  query_timeout: 60000,
});

pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err);
});

async function initializeDatabase() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE EXTENSION IF NOT EXISTS "pgcrypto";

      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        phone VARCHAR(50),
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(20) NOT NULL DEFAULT 'user',
        preferred_language VARCHAR(5) DEFAULT 'en',
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS categories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name_en VARCHAR(255) UNIQUE NOT NULL,
        name_hi TEXT,
        name_mr TEXT,
        slug VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS news (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title_en VARCHAR(255) NOT NULL,
        content_en TEXT NOT NULL,
        title_hi TEXT,
        content_hi TEXT,
        title_mr TEXT,
        content_mr TEXT,
        image_url TEXT,
        video_url TEXT,
        category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
        author_id UUID REFERENCES users(id) ON DELETE SET NULL,
        is_published BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        body TEXT NOT NULL,
        data JSONB DEFAULT '{}'::jsonb,
        is_read BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMP NOT NULL DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS device_tokens (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        token TEXT NOT NULL UNIQUE,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS user_app_usage (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        usage_date DATE NOT NULL,
        time_spent_seconds INT NOT NULL DEFAULT 0,
        UNIQUE(user_id, usage_date)
      );
    `);
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  initializeDatabase,
};
