const cron = require('node-cron');
const { pool } = require('../config/db');
const { getTokensGroupedByLanguage, createGlobalNotification } = require('../models/Notification');
const { sendNotificationToTokens } = require('./notificationService');
const cache = require('../utils/cache');

async function publishPendingDrafts() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { rows: drafts } = await client.query(`
      SELECT * FROM news 
      WHERE is_published = false AND published_at <= NOW()
    `);

    if (drafts.length === 0) {
      console.log(`[DraftScheduler] No pending drafts found to publish.`);
      await client.query('ROLLBACK');
      return;
    }

    console.log(`[DraftScheduler] Found ${drafts.length} drafts. Publishing them now...`);

    for (const news of drafts) {
      await client.query(
        `UPDATE news SET is_published = true, published_at = NOW() WHERE id = $1`,
        [news.id]
      );

      const groupedTokens = await getTokensGroupedByLanguage();

      const sendBatch = async (tokens, title, body) => {
        if (tokens && tokens.length > 0) {
          let trimmedBody = body || 'New Article';
          trimmedBody = trimmedBody.replace(/\n/g, ' ').trim();
          if (trimmedBody.length > 120) {
            const sub = trimmedBody.substring(0, 120);
            trimmedBody = sub.substring(0, Math.min(sub.length, sub.lastIndexOf(' '))) + '...';
          }
          await sendNotificationToTokens(
            tokens,
            title || 'New Article',
            trimmedBody,
            { newsId: news.id }
          );
        }
      };

      await Promise.all([
        sendBatch(groupedTokens.en, news.title_en, news.content_en),
        sendBatch(groupedTokens.hi, news.title_hi, news.content_hi),
        sendBatch(groupedTokens.mr, news.title_mr, news.content_mr)
      ]);

      await createGlobalNotification(
        'New article published', 
        news.title_en || 'New Article', 
        { newsId: news.id }
      );
    }

    await client.query('COMMIT');
    
    cache.deletePattern('news_');
    
    console.log(`[DraftScheduler] Successfully published ${drafts.length} drafts!`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(`[DraftScheduler] Error publishing drafts:`, error);
  } finally {
    client.release();
  }
}

function initDraftScheduler() {
  console.log('🕒 Initializing Draft Scheduler (Runs every minute to check scheduled drafts)');

  cron.schedule('* * * * *', () => {
    publishPendingDrafts();
  });
}

module.exports = {
  initDraftScheduler,
  publishPendingDrafts
};
