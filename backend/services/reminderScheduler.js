const cron = require('node-cron');
const { pool } = require('../config/db');
const { processReminders } = require('./reminderService');

// Use advisory lock ID 987654 to ensure single execution across instances
const ADVISORY_LOCK_ID = 987654;

function initScheduler() {
  const intervalMinutes = parseInt(process.env.NEWS_REMINDER_INTERVAL_MINUTES || '15', 10);
  const cronExpression = `*/${intervalMinutes} * * * *`;

  console.log(`[Scheduler] Initializing reminder cron job (every ${intervalMinutes} minutes)`);

  cron.schedule(cronExpression, async () => {
    let client;
    try {
      client = await pool.connect();
      // Try to acquire the lock
      const lockResult = await client.query('SELECT pg_try_advisory_lock($1) AS acquired', [ADVISORY_LOCK_ID]);
      
      if (!lockResult.rows[0].acquired) {
        console.log(`[Scheduler] Lock not acquired. Another instance is already running the reminder service.`);
        return;
      }

      await processReminders('cron');

    } catch (error) {
      console.error('[Scheduler] Error in scheduled run:', error);
    } finally {
      if (client) {
        try {
          // Release the lock
          await client.query('SELECT pg_advisory_unlock($1)', [ADVISORY_LOCK_ID]);
          client.release();
        } catch (releaseErr) {
          console.error('[Scheduler] Error releasing lock:', releaseErr);
        }
      }
    }
  });

  // Daily cleanup job at 3:00 AM
  cron.schedule('0 3 * * *', async () => {
    try {
      const deviceService = require('./deviceService');
      const stats = await deviceService.cleanupStaleTokens();
      console.log(`[Scheduler] Daily device cleanup complete. Inactive: ${stats.markedInactive}, Invalid deleted: ${stats.deletedInvalid}`);
    } catch (error) {
      console.error('[Scheduler] Error in daily device cleanup:', error);
    }
  });
}

module.exports = {
  initScheduler
};
