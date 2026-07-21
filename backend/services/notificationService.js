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

async function sendNotificationToTokens(tokens, title, body, data = {}, imageUrl = null) {
  if (!tokens || tokens.length === 0) return { successCount: 0, failureCount: 0 };

  const cleanTokens = [...new Set(tokens.filter(Boolean))];
  if (!cleanTokens.length) return { successCount: 0, failureCount: 0 };

  let optimizedImageUrl = imageUrl;
  if (optimizedImageUrl && optimizedImageUrl.includes('cloudinary.com') && optimizedImageUrl.includes('/upload/')) {
    // Compress and crop to a perfect square (800x800). This makes the collapsed thumbnail perfectly square and small, 
    // leaving plenty of room for text. Android will natively handle it when expanded!
    optimizedImageUrl = optimizedImageUrl.replace('/upload/', '/upload/c_fill,w_800,h_800,g_center,q_auto,f_jpg/');
  }

  const message = {
    notification: {
      title,
      body,
      ...(optimizedImageUrl && { imageUrl: optimizedImageUrl }),
    },
    data: normalizeData({
      ...data,
      // Add imageUrl to data payload for Flutter foreground handling
      ...(optimizedImageUrl && { imageUrl: optimizedImageUrl }), 
    }),
    android: {
      priority: 'high',
      notification: {
        channelId: ANDROID_CHANNEL_ID,
        icon: ANDROID_NOTIFICATION_ICON,
        color: ANDROID_NOTIFICATION_COLOR,
        ...(optimizedImageUrl && { imageUrl: optimizedImageUrl }), // Android native image support
      },
    },
    apns: {
      payload: {
        aps: {
          'mutable-content': 1, // Required for iOS Notification Service Extension to trigger
        },
      },
      ...(optimizedImageUrl && {
        fcmOptions: {
          imageUrl: optimizedImageUrl, // iOS native image support via FCM options
        },
      }),
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

async function sendSilentPingToTokens(tokens) {
  if (!tokens || tokens.length === 0) return { successCount: 0, failureCount: 0 };

  const cleanTokens = [...new Set(tokens.filter(Boolean))];
  if (!cleanTokens.length) return { successCount: 0, failureCount: 0 };

  // A silent ping is a data-only message with NO notification object
  const message = {
    data: { silent_ping: 'true' },
    android: {
      priority: 'normal',
    },
    tokens: cleanTokens,
  };

  try {
    const response = await getMessaging().sendEachForMulticast(message);
    
    // Async background task — handle token failures and uninstalls
    deviceService.handleFCMResponse(response, cleanTokens).catch(err => {
      console.error('[NotificationService] Error handling FCM response for silent ping:', err);
    });

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('[NotificationService] Silent ping send error:', error);
    throw error;
  }
}

async function sendNotificationToUsers(userIds, title, body, data = {}, imageUrl = null) {
  return sendNotificationToTokens([], title, body, data, imageUrl);
}

module.exports = {
  sendNotificationToTokens,
  sendNotificationToUsers,
  sendSilentPingToTokens,
};
