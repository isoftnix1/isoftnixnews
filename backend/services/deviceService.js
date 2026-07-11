const UserDevice = require('../models/UserDevice');
const { getMessaging } = require('firebase-admin/messaging');

async function registerDevice(data) {
  return await UserDevice.upsertDevice(data);
}

async function heartbeat(userId, deviceId, appVersion, osVersion, latitude, longitude, location_name) {
  return await UserDevice.heartbeat(userId, deviceId, appVersion, osVersion, latitude, longitude, location_name);
}

async function getAdminDeviceList(filters) {
  return await UserDevice.getAdminDeviceList(filters);
}

async function getAdminDeviceAnalytics() {
  return await UserDevice.getAdminDeviceAnalytics();
}

async function handleFCMResponse(response, tokens) {
  if (response.failureCount === 0) return;
  
  const invalidTokens = [];
  
  response.responses.forEach((res, idx) => {
    if (!res.success) {
      const errorCode = res.error?.code;
      if (
        errorCode === 'messaging/invalid-registration-token' ||
        errorCode === 'messaging/registration-token-not-registered' ||
        errorCode === 'messaging/unregistered'
      ) {
        invalidTokens.push(tokens[idx]);
      }
    }
  });

  for (const token of invalidTokens) {
    try {
      await UserDevice.handleInvalidToken(token);
      console.log(`[DeviceService] Marked token as invalid and possible uninstall: ${token.substring(0, 10)}...`);
    } catch (e) {
      console.error(`[DeviceService] Error handling invalid token ${token}:`, e);
    }
  }
}

async function recordNotificationSent(tokens) {
  try {
    await UserDevice.updateNotificationSent(tokens);
  } catch (e) {
    console.error(`[DeviceService] Error recording notification sent:`, e);
  }
}

async function cleanupStaleTokens() {
  return await UserDevice.cleanupStaleTokens();
}

module.exports = {
  registerDevice,
  heartbeat,
  getAdminDeviceList,
  getAdminDeviceAnalytics,
  handleFCMResponse,
  recordNotificationSent,
  cleanupStaleTokens
};
