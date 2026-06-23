const { successResponse, errorResponse } = require('../utils/responseHandler');
const Notification = require('../models/Notification');

async function registerToken(req, res, next) {
  
  try {
    const { token } = req.body;
   
    
    if (!token) {
      
      return errorResponse(res, 400, 'Device token is required');
    }

    
    const saved = await Notification.registerDeviceToken({
      userId: req.user.id,
      token,
    });

    
    return successResponse(res, 200, saved, 'Device token registered successfully');
  } catch (error) {
    console.error('[Notification Route] Exception during registerToken:', error);
    return next(error);
  }
}

async function listNotifications(req, res, next) {
  try {
    const notifications = await Notification.getNotificationsForUser(req.user.id, 50);
    return successResponse(res, 200, notifications);
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  registerToken,
  listNotifications,
};
