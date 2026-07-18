require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

async function run() {
  try {
    const res = await pool.query(`
      SELECT n.id, n.title_en, n.created_at, c.name_en AS category_name
      FROM news n
      JOIN news_categories nc ON n.id = nc.news_id
      JOIN categories c ON nc.category_id = c.id
      ORDER BY n.created_at DESC
      LIMIT 10
    `);
    console.log(JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    pool.end();
  }
}
run();
