require('dotenv').config();
const { pool } = require('./config/db');
const aiService = require('./services/aiService');

async function runTest() {
  const command = "tell me about today's business agriculture news";
  console.log(`Testing command: "${command}"\n`);
  
  try {
    const { intent, category, date: targetDate } = await aiService.analyzeIntent(command);
    console.log(`1. Extracted Intent: ${intent}`);
    console.log(`2. Extracted Category: ${category}`);
    console.log(`3. Extracted Date: ${targetDate}\n`);
    
    if (intent === 'news') {
      const articles = [];
      const query = `
        SELECT n.id, n.title_en AS title, n.content_en AS content, c.name_en AS category_name
        FROM news n
        JOIN news_categories nc ON n.id = nc.news_id
        JOIN categories c ON nc.category_id = c.id
        WHERE c.name_en ILIKE $1
          AND n.is_published = true
          AND n.created_at >= $2::date
          AND n.created_at < ($2::date + INTERVAL '1 day')
        ORDER BY n.created_at DESC
        LIMIT 1
      `;
      const result = await pool.query(query, [`%Business%`, targetDate]);
      if (result.rows.length > 0) {
        articles.push(result.rows[0]);
      }
      
      console.log(`4. Articles fetched from DB for ${targetDate}:`, articles.map(a => a.title));
      
      console.log(`\n5. Generating AI Summary...`);
      const summary = await aiService.generateVoiceSummary(articles, 'en', category);
      console.log(`\n=== FINAL AI RESPONSE ===\n${summary}\n=========================\n`);
    } else {
      console.log("Intent was not classified as news.");
    }
  } catch (err) {
    console.error("Test failed:", err);
  } finally {
    pool.end();
  }
}

runTest();
