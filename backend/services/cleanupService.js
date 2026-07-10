const cron = require('node-cron');
const { pool } = require('../config/db');

/**
 * Executes the database cleanup queries.
 * Deletes news_views where the associated news is > 3 days old.
 * Deletes notification_delivery logs > 7 days old.
 */
async function runDailyCleanup() {
  console.log(`[CLEANUP] Starting daily database cleanup at ${new Date().toISOString()}`);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Delete old news_views (3 days)
    // We join with the news table to check the published_at or created_at date
    const deleteViewsQuery = `
      DELETE FROM news_views 
      WHERE news_id IN (
        SELECT id FROM news 
        WHERE COALESCE(published_at, created_at) < NOW() - INTERVAL '3 days'
      )
    `;
    const viewsResult = await client.query(deleteViewsQuery);
    console.log(`[CLEANUP] Deleted ${viewsResult.rowCount} old rows from news_views.`);

    // 2. Delete old notification_delivery (7 days)
    // Assuming there is a sent_at or created_at column. We check for both.
    const deleteNotificationsQuery = `
      DELETE FROM notification_delivery 
      WHERE COALESCE(sent_at, created_at) < NOW() - INTERVAL '7 days'
    `;
    
    // We wrap this in a try-catch specifically in case the table doesn't exist 
    // or column names differ, to prevent crashing the whole transaction
    try {
      const notifResult = await client.query(deleteNotificationsQuery);
      console.log(`[CLEANUP] Deleted ${notifResult.rowCount} old rows from notification_delivery.`);
    } catch (notifErr) {
      if (notifErr.code === '42P01') {
        console.log(`[CLEANUP] Table notification_delivery does not exist, skipping.`);
      } else {
        console.warn(`[CLEANUP] Warning: Could not clean notification_delivery: ${notifErr.message}`);
      }
    }

    // 3. Delete old notifications (1 day)
    const deleteOldNotificationsQuery = `
      DELETE FROM notifications 
      WHERE created_at < NOW() - INTERVAL '1 day'
    `;
    try {
      const result = await client.query(deleteOldNotificationsQuery);
      console.log(`[CLEANUP] Deleted ${result.rowCount} old rows from notifications.`);
    } catch (err) {
      if (err.code === '42P01') {
        console.log(`[CLEANUP] Table notifications does not exist, skipping.`);
      } else {
        console.warn(`[CLEANUP] Warning: Could not clean notifications: ${err.message}`);
      }
    }

    // 4. Delete old scheduler runs (7 days)
    const deleteSchedulerRunsQuery = `
      DELETE FROM scheduler_runs 
      WHERE started_at < NOW() - INTERVAL '7 days'
    `;
    try {
      const runResult = await client.query(deleteSchedulerRunsQuery);
      console.log(`[CLEANUP] Deleted ${runResult.rowCount} old rows from scheduler_runs.`);
    } catch (runErr) {
      if (runErr.code === '42P01') {
        console.log(`[CLEANUP] Table scheduler_runs does not exist, skipping.`);
      } else {
        console.warn(`[CLEANUP] Warning: Could not clean scheduler_runs: ${runErr.message}`);
      }
    }

    await client.query('COMMIT');
    console.log(`[CLEANUP] Daily database cleanup completed successfully.`);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error(`[CLEANUP ERROR] Failed to run daily cleanup:`, error);
  } finally {
    client.release();
  }
}

/**
 * Initializes the cron job to run every night at 2:00 AM.
 */
function initCleanupScheduler() {
  console.log('🕒 Initializing Database Cleanup Scheduler (Runs daily at 2:00 AM)');
  cron.schedule('0 2 * * *', () => {
    runDailyCleanup();
  });
}

module.exports = {
  runDailyCleanup,
  initCleanupScheduler
};
