const admin = require('../config/firebase');
const { getMessaging } = require('firebase-admin/messaging');
const deviceService = require('./deviceService');

const ANDROID_CHANNEL_ID = 'updates_channel';
const ANDROID_NOTIFICATION_ICON = 'ic_notification';
const ANDROID_NOTIFICATION_COLOR = '#F97316';

function normalizeData(data = {}) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value ?? '')])
  );
}

async function sendNotificationToTokens(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return { successCount: 0, failureCount: 0 };

  const cleanTokens = [...new Set(tokens.filter(Boolean))];
  if (!cleanTokens.length) return { successCount: 0, failureCount: 0 };

  const message = {
    notification: {
      title,
      body,
    },
    data: normalizeData(data),
    android: {
      priority: 'high',
      notification: {
        channelId: ANDROID_CHANNEL_ID,
        icon: ANDROID_NOTIFICATION_ICON,
        color: ANDROID_NOTIFICATION_COLOR,
      },
    },
    tokens: cleanTokens,
  };

  try {
    const response = await getMessaging().sendEachForMulticast(message);
    
    // Async background task — handle token failures and uninstalls
    deviceService.handleFCMResponse(response, cleanTokens).catch(err => {
      console.error('[NotificationService] Error handling FCM response in deviceService:', err);
    });

    // Async background task — update last_notification_sent_at
    if (response.successCount > 0) {
      const successfulTokens = cleanTokens.filter((_, idx) => response.responses[idx].success);
      deviceService.recordNotificationSent(successfulTokens).catch(err => {
        console.error('[NotificationService] Error recording notification sent in deviceService:', err);
      });
    }

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses,
    };
  } catch (error) {
    console.error('FCM send error:', error);
    throw error;
  }
}

async function sendNotificationToUsers(userIds, title, body, data = {}) {
  return sendNotificationToTokens([], title, body, data);
}

module.exports = {
  sendNotificationToTokens,
  sendNotificationToUsers,
};
