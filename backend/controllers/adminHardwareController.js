const bcrypt = require('bcryptjs');
const AdminDeviceManager = require('../utils/adminDeviceManager');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const User = require('../models/User');
const AuthSecurity = require('../models/AuthSecurity');
const { sendAdminHardwareReplacementOtp } = require('../services/emailService');

// In-memory OTP store specifically for Admin Hardware Replacement
// In a real production environment, this should ideally be in Redis or PostgreSQL,
// but for a single-node or basic deployment, in-memory is acceptable for short-lived OTPs.
const hardwareOtpStore = new Map(); // email -> { otp, expiresAt }

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function getHardwareSlots(req, res, next) {
  try {
    const slots = await AdminDeviceManager.getAllSlots();
    return successResponse(res, 200, slots, 'Hardware slots retrieved successfully');
  } catch (error) {
    return next(error);
  }
}

async function requestHardwareReplacement(req, res, next) {
  try {
    const { password } = req.body;
    const userId = req.user.sub || req.user.id;
    
    if (!password) {
      return errorResponse(res, 400, 'Password is required to request replacement');
    }

    const user = await User.findById(userId);
    if (!user) return errorResponse(res, 404, 'Admin user not found');

    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return errorResponse(res, 401, 'Invalid password');
    }

    const otp = generateOtp();
    hardwareOtpStore.set(user.email, {
      otp,
      expiresAt: Date.now() + 10 * 60 * 1000 // 10 minutes
    });

    // For local testing without email access
    if (process.env.NODE_ENV !== 'production') {
      console.log(`\n=========================================`);
      console.log(`[DEBUG] HARDWARE REPLACEMENT OTP FOR ${user.email}: ${otp}`);
      console.log(`=========================================\n`);
    }

    await sendAdminHardwareReplacementOtp(user.email, otp);

    return successResponse(res, 200, null, 'OTP sent to your email');
  } catch (error) {
    return next(error);
  }
}

async function replaceHardwareSlot(req, res, next) {
  try {
    const { slotNumber, hardwareFingerprint, deviceInformation, otp, password } = req.body;
    const userId = req.user.sub || req.user.id;

    if (!slotNumber || !hardwareFingerprint || !otp || !password) {
      return errorResponse(res, 400, 'slotNumber, hardwareFingerprint, otp, and password are required');
    }

    const user = await User.findById(userId);
    if (!user) return errorResponse(res, 404, 'Admin user not found');

    // 1. Password Verification
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return errorResponse(res, 401, 'Invalid password');
    }

    // 2. OTP Verification
    const stored = hardwareOtpStore.get(user.email);
    if (!stored || stored.otp !== otp || Date.now() > stored.expiresAt) {
      return errorResponse(res, 400, 'Invalid or expired OTP');
    }

    // 3. Existing authenticated JWT is verified implicitly by the authMiddleware on this route.

    // Proceed to replace
    const newSlotData = await AdminDeviceManager.updateSlot(slotNumber, {
      hardwareFingerprint,
      ...deviceInformation
    });

    // Clear OTP
    hardwareOtpStore.delete(user.email);

    // Audit Log
    await AuthSecurity.logSecurityEvent(userId, 'admin_hardware_replaced', req.ip, req.headers['user-agent'], { slotNumber });

    return successResponse(res, 200, newSlotData, 'Hardware slot updated successfully');
  } catch (error) {
    return next(error);
  }
}

async function getPendingDevices(req, res, next) {
  try {
    const userId = req.user.sub || req.user.id;
    const user = await User.findById(userId);
    if (!user) return errorResponse(res, 404, 'Admin user not found');

    const pending = await AuthSecurity.getPendingDevices(user.email, 5);
    return successResponse(res, 200, pending, 'Fetched pending devices');
  } catch (error) {
    return next(error);
  }
}

async function authorizePendingDevice(req, res, next) {
  try {
    const { attemptId, slotNumber, password } = req.body;
    const userId = req.user.sub || req.user.id;

    if (!attemptId || !slotNumber || !password) {
      return errorResponse(res, 400, 'attemptId, slotNumber, and password are required');
    }

    const { pool } = require('../config/db');
    const userResult = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
    const user = userResult.rows[0];
    if (!user) return errorResponse(res, 404, 'Admin user not found');

    // 1. Password Verification
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return errorResponse(res, 401, 'Invalid password');
    }

    // 2. Fetch the attempt to get the fingerprint
    const attemptQuery = `SELECT * FROM failed_admin_hardware_attempts WHERE id = $1 AND email = $2 AND status = 'BLOCKED'`;
    const attemptResult = await pool.query(attemptQuery, [attemptId, user.email]);
    
    if (attemptResult.rows.length === 0) {
      return errorResponse(res, 404, 'Pending device not found or already authorized');
    }
    const attempt = attemptResult.rows[0];

    // 3. Authorize into slot
    const deviceInfo = attempt.device_info || {};
    
    const newSlotData = await AdminDeviceManager.updateSlot(slotNumber, {
      hardwareFingerprint: attempt.fingerprint,
      deviceName: deviceInfo.deviceName || 'Authorized from Pending (UserAgent: ' + (attempt.user_agent ? attempt.user_agent.substring(0, 20) : 'Unknown') + ')',
      platform: deviceInfo.platform || 'Unknown',
      osVersion: deviceInfo.osVersion || 'Unknown',
      appVersion: deviceInfo.appVersion || 'Unknown',
      manufacturer: deviceInfo.manufacturer || 'Unknown',
      model: deviceInfo.model || 'Unknown'
    });

    // 4. Mark attempt as Authorized so it disappears from the list
    await pool.query(`UPDATE failed_admin_hardware_attempts SET status = 'AUTHORIZED' WHERE id = $1`, [attemptId]);

    // Audit Log
    await AuthSecurity.logSecurityEvent(userId, 'admin_hardware_authorized_from_pending', req.ip, req.headers['user-agent'], { slotNumber, fingerprint: attempt.fingerprint });

    return successResponse(res, 200, newSlotData, 'Device successfully authorized');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getHardwareSlots,
  requestHardwareReplacement,
  replaceHardwareSlot,
  getPendingDevices,
  authorizePendingDevice
};
