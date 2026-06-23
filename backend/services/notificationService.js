const admin = require('../config/firebase');
const { getMessaging } = require('firebase-admin/messaging');

async function sendNotificationToTokens(tokens, title, body, data = {}) {
  if (!tokens || tokens.length === 0) return { successCount: 0, failureCount: 0 };

  const cleanTokens = [...new Set(tokens.filter(Boolean))];
  if (!cleanTokens.length) return { successCount: 0, failureCount: 0 };

  const message = {
    notification: {
      title,
      body,
    },
    data,
    tokens: cleanTokens,
  };

  try {
    const response = await getMessaging().sendEachForMulticast(message);
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
  // This is a placeholder for future user lookup logic.
  // The actual notification dispatch is handled by the device token table.
  return sendNotificationToTokens([], title, body, data);
}

module.exports = {
  sendNotificationToTokens,
  sendNotificationToUsers,
};
