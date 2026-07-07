const { pool } = require('../config/db');
const { sendNotificationToTokens } = require('./notificationService');

const BATCH_SIZE = 500;

async function processReminders(trigger = 'manual') {
  const startTime = Date.now();
  const delayHours = parseInt(process.env.NEWS_REMINDER_DELAY_HOURS || '3', 10);
  const delayMinutes = parseInt(process.env.NEWS_REMINDER_DELAY_MINUTES || '0', 10);
  
  const timeCondition = delayMinutes > 0 
    ? `INTERVAL '${delayMinutes} MINUTES'` 
    : `INTERVAL '${delayHours} HOURS'`;
  
  let newsProcessed = 0;
  let eligibleDevicesFound = 0;
  let uniqueUsersProcessed = 0;
  let notificationsSent = 0;
  let notificationsFailed = 0;
  let status = 'SUCCESS';
  let failReason = null;

  try {
    // 1. Find eligible news
    // Must be published >= delayHours ago, and reminder_status in ('pending', 'failed')
    // OR 'processing' but stuck for more than 1 hour.
    const newsResult = await pool.query(`
      WITH eligible_news AS (
        SELECT id, title_en, title_hi, title_mr, reminder_sent_count 
        FROM news
        WHERE published_at <= NOW() - ${timeCondition}
          AND is_published = TRUE
          AND (
            reminder_status IN ('pending', 'failed') 
            OR (reminder_status = 'processing' AND last_reminder_attempt_at <= NOW() - INTERVAL '1 HOUR')
          )
        FOR UPDATE SKIP LOCKED
      )
      UPDATE news n
      SET reminder_status = 'processing',
          last_reminder_attempt_at = NOW()
      FROM eligible_news en
      WHERE n.id = en.id
      RETURNING n.id, n.title_en, n.title_hi, n.title_mr, n.reminder_sent_count
    `);

    const newsList = newsResult.rows;
    newsProcessed = newsList.length;

    if (newsProcessed > 0) {
      for (const news of newsList) {
        let sentCount = 0;
        const title = news.title_en || news.title_hi || news.title_mr || 'News Updates';
        const body = 'You haven\'t read this news yet. Tap to read now.';
        
        // 2. Find eligible users for this news
        // active account, has device token, hasn't viewed, reminder not sent
        const usersResult = await pool.query(`
          SELECT u.id as user_id, dt.token, dt.id as token_id
          FROM users u
          JOIN device_tokens dt ON u.id = dt.user_id
          WHERE u.is_active = TRUE
            AND NOT EXISTS (
              SELECT 1 FROM news_views nv 
              WHERE nv.news_id = $1 AND nv.user_id = u.id
            )
            AND NOT EXISTS (
              SELECT 1 FROM notification_delivery nd 
              WHERE nd.news_id = $1 AND nd.user_id = u.id AND nd.type = 'reminder' AND nd.status IN ('success', 'processing', 'pending')
              -- we allow retry if failed and next_retry_at is reached, but for simplicity we can just handle fail state later
            )
        `, [news.id]);

        const users = usersResult.rows;
        eligibleDevicesFound += users.length;

        // 3. Process in batches
        for (let i = 0; i < users.length; i += BATCH_SIZE) {
          const batch = users.slice(i, i + BATCH_SIZE);
          const tokens = batch.map(u => u.token);
          
          try {
            const fcmResult = await sendNotificationToTokens(tokens, title, body, { 
              type: 'reminder', 
              newsId: news.id 
            });

            // Handle FCM Responses
            const userStatusMap = new Map();
            
            for (let j = 0; j < batch.length; j++) {
              const user = batch[j];
              const response = fcmResult.responses[j];
              
              if (!response.success) {
                const error = response.error ? response.error.code : 'Unknown';
                if (error === 'messaging/registration-token-not-registered' || error === 'messaging/invalid-registration-token') {
                  await pool.query('DELETE FROM device_tokens WHERE id = $1', [user.token_id]);
                }
              }

              // If a user has multiple devices, if ANY device succeeds, mark the user delivery as success.
              const currentStatus = userStatusMap.get(user.user_id);
              if (currentStatus?.success) {
                continue; // Already succeeded for this user
              }

              userStatusMap.set(user.user_id, {
                success: response.success,
                error: response.success ? null : (response.error ? response.error.code : 'Unknown')
              });
            }

            const deliveryValues = [];
            uniqueUsersProcessed += userStatusMap.size;
            
            for (const [userId, status] of userStatusMap.entries()) {
              if (status.success) {
                deliveryValues.push(`('${userId}', '${news.id}', 'reminder', 'success', NOW(), NULL, 0, NULL)`);
                notificationsSent++;
                sentCount++;
              } else {
                const retryCount = 1;
                const nextRetry = `NOW() + INTERVAL '15 MINUTES'`;
                deliveryValues.push(`('${userId}', '${news.id}', 'reminder', 'failed', NULL, '${status.error}', ${retryCount}, ${nextRetry})`);
                notificationsFailed++;
              }
            }

            // Insert to notification_delivery
            if (deliveryValues.length > 0) {
              await pool.query(`
                INSERT INTO notification_delivery (user_id, news_id, type, status, sent_at, error_message, retry_count, next_retry_at)
                VALUES ${deliveryValues.join(',')}
                ON CONFLICT (user_id, news_id, type) DO UPDATE 
                SET status = EXCLUDED.status, 
                    sent_at = EXCLUDED.sent_at, 
                    error_message = EXCLUDED.error_message,
                    retry_count = EXCLUDED.retry_count,
                    next_retry_at = EXCLUDED.next_retry_at
              `);
            }
          } catch (batchError) {
            console.error('Batch send error:', batchError);
            notificationsFailed += batch.length;
            // mark all as failed for this batch
            const failValues = batch.map(u => `('${u.user_id}', '${news.id}', 'reminder', 'failed', NULL, 'Batch Error', 1, NOW() + INTERVAL '15 MINUTES')`);
            await pool.query(`
              INSERT INTO notification_delivery (user_id, news_id, type, status, sent_at, error_message, retry_count, next_retry_at)
              VALUES ${failValues.join(',')}
              ON CONFLICT (user_id, news_id, type) DO NOTHING
            `);
          }
        } // end batches

        // 4. Update news table to completed
        await pool.query(`
          UPDATE news 
          SET reminder_status = 'completed', 
              reminder_sent_count = reminder_sent_count + $1
          WHERE id = $2
        `, [sentCount, news.id]);
      }
    }
  } catch (error) {
    status = 'FAILED';
    failReason = error.message;
  }

  const execTime = ((Date.now() - startTime) / 1000).toFixed(2);
  const execTimeMs = Date.now() - startTime;

  // Insert scheduler run log
  try {
    await pool.query(`
      INSERT INTO scheduler_runs (triggered_by, started_at, finished_at, news_processed, notifications_sent, notifications_failed, execution_time_ms, status)
      VALUES ($1, TO_TIMESTAMP($2 / 1000.0), NOW(), $3, $4, $5, $6, $7)
    `, [trigger, startTime, newsProcessed, notificationsSent, notificationsFailed, execTimeMs, status]);
  } catch (dbErr) {
    console.error('Failed to log scheduler run:', dbErr);
  }

  // Print nicely formatted logs
  console.log(`
======================================
Reminder Service ${status === 'SUCCESS' ? 'Completed' : 'Failed'}
======================================
Trigger        : ${trigger}
Started At     : ${new Date(startTime).toLocaleString()}
${status === 'FAILED' ? `Reason         : ${failReason}` : ''}
News Found           : ${newsProcessed}
Eligible Devices     : ${eligibleDevicesFound}
Unique Users         : ${uniqueUsersProcessed}
Notifications Sent   : ${notificationsSent}
Notifications Failed : ${notificationsFailed}
Execution Time       : ${execTime} sec
Status               : ${status}
======================================
`);

  return {
    newsProcessed,
    eligibleDevicesFound,
    uniqueUsersProcessed,
    notificationsSent,
    notificationsFailed,
    execTime,
    status
  };
}

module.exports = {
  processReminders
};
