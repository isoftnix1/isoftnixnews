const cron = require('node-cron');
const { pool } = require('./config/db');
const aiService = require('./services/aiService');

// Function to run the nightly summarization
async function runNightlySummarization() {
  console.log(`\n======================================================`);
  console.log(`[CRON] Starting Nightly Chat Summarization...`);
  
  try {
    // We want to find all distinct conversations that have un-summarized messages
    // To do this, we can select conversation_ids where there are messages not of intent 'daily_summary'
    const activeConvsQuery = `
      SELECT DISTINCT conversation_id 
      FROM messages 
      WHERE intent IS NULL OR intent != 'daily_summary'
    `;
    const convsResult = await pool.query(activeConvsQuery);
    const activeConversations = convsResult.rows.map(r => r.conversation_id);

    console.log(`[CRON] Found ${activeConversations.length} conversations to summarize.`);

    // Process each conversation sequentially to avoid overwhelming the Groq API
    for (const conversationId of activeConversations) {
      console.log(`[CRON] Processing Conversation: ${conversationId}`);

      // Fetch all messages for this conversation
      const msgQuery = `
        SELECT sender, content, intent, created_at 
        FROM messages 
        WHERE conversation_id = $1
        ORDER BY created_at ASC
      `;
      const messagesResult = await pool.query(msgQuery, [conversationId]);
      const allMessages = messagesResult.rows;

      if (allMessages.length === 0) continue;
      
      // If the entire conversation is ALREADY just a single daily_summary message, skip
      if (allMessages.length === 1 && allMessages[0].intent === 'daily_summary') {
        continue; 
      }

      // Find the user's language preference
      const langQuery = `
        SELECT u.preferred_language 
        FROM conversations c 
        JOIN users u ON c.user_id = u.id 
        WHERE c.id = $1
      `;
      const langResult = await pool.query(langQuery, [conversationId]);
      const lang = langResult.rows.length > 0 ? (langResult.rows[0].preferred_language || 'en') : 'en';

      // Separate voice logs if we previously pushed them as system notes?
      // No, currently voice history is passed via the endpoint, but in a true Cron Job, we ONLY summarize what's in the DB.
      // So voiceHistory is empty here, and we just summarize chatHistory.
      const chatHistory = allMessages;

      const grandSummary = await aiService.generateGrandSummary([], chatHistory, lang);

      // Delete all old messages
      await pool.query('DELETE FROM messages WHERE conversation_id = $1', [conversationId]);

      // Insert the single Grand Summary message
      await pool.query(
        'INSERT INTO messages (conversation_id, sender, content, intent) VALUES ($1, $2, $3, $4)',
        [conversationId, 'ai', grandSummary, 'daily_summary']
      );

      console.log(`[CRON] Successfully summarized and cleaned Conversation: ${conversationId}`);
    }

    console.log(`[CRON] Nightly Summarization Complete!`);
    console.log(`======================================================\n`);

  } catch (error) {
    console.error(`[CRON] Error during nightly summarization:`, error);
  }
}

function initCronJobs() {
  // Runs every night at midnight (00:00)
  cron.schedule('0 0 * * *', () => {
    runNightlySummarization();
  });
  console.log(`[CRON] Jobs initialized. Scheduled to run...`);
}

module.exports = {
  initCronJobs,
  runNightlySummarization
};
