const { successResponse, errorResponse } = require('../utils/responseHandler');
const deviceService = require('../services/deviceService');

async function registerDevice(req, res, next) {
  try {
    const { fcm_token, device_id, device_name, manufacturer, model, platform, os_version, app_version } = req.body;
    const userId = req.user.id;

    const device = await deviceService.registerDevice({
      userId,
      fcmToken: fcm_token,
      deviceId: device_id,
      deviceName: device_name,
      manufacturer,
      model,
      platform,
      osVersion: os_version,
      appVersion: app_version
    });

    return successResponse(res, 200, device, 'Device registered successfully');
  } catch (error) {
    console.error('[DeviceController] registerDevice error:', error);
    return next(error);
  }
}

async function heartbeat(req, res, next) {
  try {
    const { device_id, app_version, os_version } = req.body;
    const userId = req.user.id;

    const device = await deviceService.heartbeat(userId, device_id, app_version, os_version);
    
    if (!device) {
      return errorResponse(res, 404, 'Device not found, please register first');
    }

    return successResponse(res, 200, device, 'Heartbeat recorded');
  } catch (error) {
    console.error('[DeviceController] heartbeat error:', error);
    return next(error);
  }
}

async function listAdminDevices(req, res, next) {
  try {
    const filters = {
      status: req.query.status,
      platform: req.query.platform
    };
    
    const devices = await deviceService.getAdminDeviceList(filters);
    return successResponse(res, 200, devices);
  } catch (error) {
    return next(error);
  }
}

async function getAdminDeviceAnalytics(req, res, next) {
  try {
    const analytics = await deviceService.getAdminDeviceAnalytics();
    return successResponse(res, 200, analytics);
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  registerDevice,
  heartbeat,
  listAdminDevices,
  getAdminDeviceAnalytics
};
