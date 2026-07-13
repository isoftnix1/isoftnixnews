const cron = require('node-cron');
const { pool } = require('../config/db');
const { getTokensGroupedByLanguage, createGlobalNotification } = require('../models/Notification');
const { sendNotificationToTokens } = require('./notificationService');
const cache = require('../utils/cache');

let _isRunning = false;

async function publishPendingDrafts() {
  // Prevent overlapping runs if the previous tick is still processing
  if (_isRunning) {
    console.log('[DraftScheduler] Previous run still in progress, skipping this tick.');
    return;
  }
  _isRunning = true;

  let client;
  try {
    // Acquire a fresh connection with a short timeout so a dead DB doesn't block indefinitely
    client = await pool.connect();

    await client.query('BEGIN');

    const { rows: drafts } = await client.query(`
      SELECT * FROM news
      WHERE is_published = false
        AND published_at IS NOT NULL
        AND published_at <= NOW()
    `);

    if (drafts.length === 0) {
      console.log('[DraftScheduler] No pending drafts to publish.');
      await client.query('ROLLBACK');
      return;
    }

    console.log(`[DraftScheduler] Found ${drafts.length} draft(s). Publishing now…`);

    let successCount = 0;

    for (const news of drafts) {
      try {
        // 1. Mark as published immediately so duplicate runs don't pick it up again
        await client.query(
          `UPDATE news SET is_published = true, updated_at = NOW() WHERE id = $1`,
          [news.id]
        );

        // 2. Send push notifications — failures here must NOT roll back the publish
        try {
          const groupedTokens = await getTokensGroupedByLanguage();

          const sendBatch = async (tokens, title, body) => {
            if (!tokens || tokens.length === 0) return;
            let trimmedBody = (body || 'New Article').replace(/\n/g, ' ').trim();
            if (trimmedBody.length > 120) {
              const sub = trimmedBody.substring(0, 120);
              trimmedBody = sub.substring(0, Math.min(sub.length, sub.lastIndexOf(' '))) + '…';
            }
            await sendNotificationToTokens(tokens, title || 'New Article', trimmedBody, { newsId: news.id });
          };

          await Promise.all([
            sendBatch(groupedTokens.en, news.title_en, news.content_en),
            sendBatch(groupedTokens.hi, news.title_hi, news.content_hi),
            sendBatch(groupedTokens.mr, news.title_mr, news.content_mr),
          ]);

          await createGlobalNotification(
            'New article published',
            news.title_en || 'New Article',
            { newsId: news.id }
          );
        } catch (notifErr) {
          // Notification failure must never block publishing
          console.error(`[DraftScheduler] Notification error for draft ${news.id}:`, notifErr.message);
        }

        successCount++;
        console.log(`[DraftScheduler] ✅ Published: "${news.title_en}" (${news.id})`);
      } catch (draftErr) {
        // Per-draft error: log but continue with other drafts
        console.error(`[DraftScheduler] ❌ Failed to publish draft ${news.id}:`, draftErr.message);
      }
    }

    await client.query('COMMIT');
    cache.deletePattern('news_');

    console.log(`[DraftScheduler] Done. ${successCount}/${drafts.length} draft(s) published successfully.`);

  } catch (err) {
    // Top-level DB error (connection refused, timeout, etc.)
    console.error('[DraftScheduler] DB error, skipping this tick:', err.message);
    try { if (client) await client.query('ROLLBACK'); } catch (_) { /* ignore */ }
  } finally {
    try { if (client) client.release(); } catch (_) { /* ignore */ }
    _isRunning = false;
  }
}


function initDraftScheduler() {
  console.log('🕒 Initializing Draft Scheduler (Runs every minute to check scheduled drafts)');

  // Regular every-minute cron — runs reliably 24/7 on Render Starter plan
  cron.schedule('* * * * *', () => {
    publishPendingDrafts();
  });
}

module.exports = {
  initDraftScheduler,
  publishPendingDrafts
};
