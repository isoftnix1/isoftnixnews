const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const { normalizeIndianPhone } = require('../utils/phoneUtils');
const User = require('../models/User');
const AuthSecurity = require('../models/AuthSecurity');
const AdminDeviceManager = require('../utils/adminDeviceManager');
const { sendNewDeviceLoginAlert, sendUnauthorizedAdminLoginAlert, sendCriticalAdminSecurityAlert } = require('../services/emailService');

// Helper to calculate progressive lockout delay
function getLockoutDuration(attempts) {
  if (attempts >= 9) return 60; // 1 hour for >= 9
  if (attempts >= 8) return 30; // 30 min
  if (attempts >= 7) return 15; // 15 min
  if (attempts >= 6) return 5;  // 5 min
  if (attempts >= 5) return 2;  // 2 min
  return 0; // Not locked yet
}

function generateAccessToken(user, deviceId) {
  return jwt.sign(
    {
      sub: user.id, // Standard claim for subject
      role: user.role,
      deviceId: deviceId || 'unknown'
    },
    process.env.JWT_SECRET,
    { expiresIn: '30m' } // Short-lived access token
  );
}

function generateRefreshTokenString() {
  return crypto.randomBytes(40).toString('hex');
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function handleDeviceTrust(user, req) {
  const deviceId = req.body.device_id || req.headers['x-device-id'] || 'unknown';
  const deviceName = req.body.device_name || req.headers['x-device-name'] || 'Unknown Device';
  const platform = req.body.platform || req.headers['x-platform'] || 'Unknown Platform';
  const manufacturer = req.body.manufacturer || null;
  const model = req.body.model || null;
  const ip = req.ip;

  // Max 5 devices for admins
  if (user.role === 'admin') {
    const adminDeviceCount = await AuthSecurity.countAdminTrustedDevices(user.id);
    const existingDevice = await AuthSecurity.getTrustedDevice(user.id, deviceId);
    
    // If it's a new device and they already have 5, block it.
    if (!existingDevice && adminDeviceCount >= 5) {
      await AuthSecurity.logSecurityEvent(user.id, 'admin_max_devices_reached', ip, req.headers['user-agent'], { deviceId });
      throw new Error('MAX_ADMIN_DEVICES');
    }
  }

  const existingDevice = await AuthSecurity.getTrustedDevice(user.id, deviceId);

  // Register or update trusted device
  await AuthSecurity.registerTrustedDevice({
    user_id: user.id,
    device_id: deviceId,
    device_name: deviceName,
    platform: platform,
    manufacturer: manufacturer,
    model: model
  });

  // If new device, send email alert
  if (!existingDevice && deviceId !== 'unknown') {
    const time = new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }) + ' IST';
    try {
      await sendNewDeviceLoginAlert(user.email, {
        deviceName,
        platform,
        ip,
        time
      });
      await AuthSecurity.logSecurityEvent(user.id, 'new_device_login_email_sent', ip, req.headers['user-agent'], { deviceId });
    } catch (err) {
      console.error('Failed to send new device email:', err);
    }
  }

  return { deviceId, deviceName, platform };
}

async function register(req, res, next) {
  try {
    const existingUser = await User.findByEmail(req.body.email);
    if (existingUser) return errorResponse(res, 409, 'Email already registered');

    const passwordHash = await bcrypt.hash(req.body.password, 12);

    const user = await User.createUser({
      name: req.body.name,
      email: req.body.email,
      phone: req.body.phone ? normalizeIndianPhone(req.body.phone) : null,
      passwordHash,
      role: 'user',
    });

    const { deviceId, deviceName, platform } = await handleDeviceTrust(user, req);

    const accessToken = generateAccessToken(user, deviceId);
    
    const refreshTokenString = generateRefreshTokenString();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30 days expiry

    await AuthSecurity.createRefreshToken({
      user_id: user.id,
      device_id: deviceId,
      device_name: deviceName,
      platform: platform,
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      token_hash: hashToken(refreshTokenString),
      expires_at: expiresAt
    });

    await AuthSecurity.logSecurityEvent(user.id, 'register_success', req.ip, req.headers['user-agent']);

    return successResponse(res, 201, {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || null,
        role: user.role
      },
      accessToken,
      refreshToken: refreshTokenString
    }, 'User registered successfully');
  } catch (error) {
    return next(error);
  }
}

async function login(req, res, next) {
  try {
    const { email, password, hardwareFingerprint, deviceInformation } = req.body;
    
    // Check lockout status
    const attemptRecord = await AuthSecurity.getLoginAttempt(email);
    if (attemptRecord && attemptRecord.locked_until && new Date() < attemptRecord.locked_until) {
      await AuthSecurity.logSecurityEvent(null, 'login_locked_attempt', req.ip, req.headers['user-agent'], { email });
      return errorResponse(res, 429, `Account temporarily locked. Try again later.`);
    }

    const user = await User.findByEmail(email);
    if (!user) {
      await AuthSecurity.recordFailedAttempt(email);
      return errorResponse(res, 401, 'Invalid email or password');
    }

    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      const record = await AuthSecurity.recordFailedAttempt(email);
      const lockMinutes = getLockoutDuration(record.attempts);
      
      if (lockMinutes > 0) {
        const lockedUntil = new Date();
        lockedUntil.setMinutes(lockedUntil.getMinutes() + lockMinutes);
        await AuthSecurity.lockAccount(email, lockedUntil);
        
        await AuthSecurity.logSecurityEvent(user.id, 'account_locked', req.ip, req.headers['user-agent'], { minutes: lockMinutes });
        return errorResponse(res, 429, `Account locked for ${lockMinutes} minutes due to too many failed attempts.`);
      }
      
      await AuthSecurity.logSecurityEvent(user.id, 'login_failed', req.ip, req.headers['user-agent']);
      return errorResponse(res, 401, 'Invalid email or password');
    }

    // Success - reset attempts
    await AuthSecurity.resetLoginAttempts(email);

    let deviceId, deviceName, platform;

    // ============================================
    // ADMIN HARDWARE LOCK ENFORCEMENT
    // ============================================
    if (user.role === 'admin') {
      
      // AUTO-BOOTSTRAP (Zero-to-One Deployment)
      // If this is a fresh server with 0 devices, the first successful login gets Slot 1.
      const totalSlots = await AdminDeviceManager.getFilledSlotCount();
      if (totalSlots === 0) {
        console.log('🚀 [Zero-to-One] Fresh server detected! Auto-bootstrapping Slot 1...');
        await AdminDeviceManager.updateSlot(1, {
          hardwareFingerprint: hardwareFingerprint || 'fallback_fingerprint',
          deviceName: deviceInformation?.deviceName || 'Initial Admin Device (Auto-Bootstrapped)',
          manufacturer: deviceInformation?.manufacturer || 'Unknown',
          model: deviceInformation?.model || 'Unknown',
          platform: deviceInformation?.platform || 'Unknown',
          osVersion: deviceInformation?.osVersion || 'Unknown',
          appVersion: deviceInformation?.appVersion || 'Unknown'
        });
      }

      const isHardwareAuthorized = await AdminDeviceManager.verifyAdminDevice(hardwareFingerprint);
      
      if (!isHardwareAuthorized) {
        console.warn(`[SECURITY] Unauthorized hardware login attempt for admin: ${email}`);
        await AuthSecurity.recordFailedAdminHardwareAttempt({
          email: user.email,
          ip_address: req.ip,
          fingerprint: hardwareFingerprint || 'missing',
          user_agent: req.headers['user-agent'],
          device_info: deviceInformation || null
        });
        await AuthSecurity.logSecurityEvent(user.id, 'admin_hardware_unauthorized', req.ip, req.headers['user-agent'], { fingerprint: hardwareFingerprint });

        // Always print the debug log in dev mode so the admin can see it even without email
        if (process.env.NODE_ENV !== 'production') {
          console.log(`\n=========================================`);
          console.log(`[DEBUG] UNAUTHORIZED ADMIN LOGIN ATTEMPT`);
          console.log(`[DEBUG] EMAIL: ${user.email}`);
          console.log(`[DEBUG] HARDWARE FINGERPRINT: ${hardwareFingerprint}`);
          console.log(`[DEBUG] This device has been placed in the Pending Queue.`);
          console.log(`[DEBUG] Go to 'Hardware Lock' -> 'Blocked Login Attempts' in the app to Authorize it.`);
          console.log(`=========================================\n`);
        }

        // Check if we hit critical threshold
        const failedAttempts = await AuthSecurity.countFailedAdminHardwareAttempts(user.email, 30);
        const time = new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }) + ' IST';

        if (failedAttempts > 5) {
          try {
            await sendCriticalAdminSecurityAlert(user.email, failedAttempts);
            await AuthSecurity.logSecurityEvent(user.id, 'critical_admin_alert_sent', req.ip, req.headers['user-agent'], { failedAttempts });
          } catch (err) {
            console.error('Failed to send critical admin alert:', err);
          }
        } else {
          // Standard warning email
          try {
            await sendUnauthorizedAdminLoginAlert(user.email, {
              deviceName: req.headers['x-device-name'] || 'Unknown Device',
              platform: req.headers['x-platform'] || 'Unknown Platform',
              ip: req.ip,
              time: time,
              reason: 'Device not found in 5 encrypted admin slots',
              fingerprint: hardwareFingerprint ? (hardwareFingerprint.substring(0, 10) + '...') : 'none'
            });
          } catch (err) {
            console.error('Failed to send unauthorized admin email:', err);
          }
        }

        return errorResponse(res, 403, 'Hardware Lock: This device is not authorized for Admin access. It has been placed in the Pending Queue.');
      }

      // If authorized, just use the fingerprint as the deviceId internally for tokens
      deviceId = hardwareFingerprint;
      deviceName = req.headers['x-device-name'] || 'Admin Device';
      platform = req.headers['x-platform'] || 'Admin Platform';
    } else {
      // Standard User Device Trust Flow
      try {
        const deviceTrustResult = await handleDeviceTrust(user, req);
        deviceId = deviceTrustResult.deviceId;
        deviceName = deviceTrustResult.deviceName;
        platform = deviceTrustResult.platform;
      } catch (e) {
        if (e.message === 'MAX_ADMIN_DEVICES') {
          return errorResponse(res, 403, 'Maximum trusted devices reached for this admin account.');
        }
        throw e;
      }
    }

    const accessToken = generateAccessToken(user, deviceId);
    
    const refreshTokenString = generateRefreshTokenString();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30 days expiry

    await AuthSecurity.createRefreshToken({
      user_id: user.id,
      device_id: deviceId,
      device_name: deviceName,
      platform: platform,
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      token_hash: hashToken(refreshTokenString),
      expires_at: expiresAt
    });

    await AuthSecurity.logSecurityEvent(user.id, 'login_success', req.ip, req.headers['user-agent'], { deviceId });

    return successResponse(res, 200, {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || null,
        role: user.role
      },
      accessToken,
      refreshToken: refreshTokenString
    }, 'Login successful');
  } catch (error) {
    console.error(`[Login Error] Internal server error:`, error);
    return next(error);
  }
}

async function refresh(req, res, next) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return errorResponse(res, 400, 'Refresh token is required');

    const hashedToken = hashToken(refreshToken);
    const tokenRecord = await AuthSecurity.getRefreshToken(hashedToken);

    if (!tokenRecord) {
      return errorResponse(res, 401, 'Invalid refresh token');
    }

    if (tokenRecord.revoked) {
      await AuthSecurity.logSecurityEvent(tokenRecord.user_id, 'token_reuse_attempt', req.ip, req.headers['user-agent'], { token_id: tokenRecord.id });
      return errorResponse(res, 401, 'Refresh token has been revoked');
    }

    if (new Date() > tokenRecord.expires_at) {
      return errorResponse(res, 401, 'Refresh token has expired');
    }

    // Token is valid. Rotate it.
    await AuthSecurity.revokeRefreshToken(tokenRecord.id); // single-use

    const user = await User.findById(tokenRecord.user_id);
    if (!user) return errorResponse(res, 404, 'User not found');

    const deviceId = req.body.device_id || req.headers['x-device-id'] || tokenRecord.device_id;
    const newAccessToken = generateAccessToken(user, deviceId);
    
    const newRefreshTokenString = generateRefreshTokenString();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30 days

    await AuthSecurity.createRefreshToken({
      user_id: user.id,
      device_id: deviceId,
      device_name: req.headers['x-device-name'] || tokenRecord.device_name,
      platform: req.headers['x-platform'] || tokenRecord.platform,
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      token_hash: hashToken(newRefreshTokenString),
      expires_at: expiresAt
    });

    await AuthSecurity.logSecurityEvent(user.id, 'token_refresh', req.ip, req.headers['user-agent'], { deviceId });

    return successResponse(res, 200, {
      accessToken: newAccessToken,
      refreshToken: newRefreshTokenString
    }, 'Tokens refreshed successfully');
  } catch (error) {
    return next(error);
  }
}

async function logout(req, res, next) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return errorResponse(res, 400, 'Refresh token is required for logout');

    const hashedToken = hashToken(refreshToken);
    const tokenRecord = await AuthSecurity.getRefreshToken(hashedToken);

    if (tokenRecord && !tokenRecord.revoked) {
      await AuthSecurity.revokeRefreshToken(tokenRecord.id);
      await AuthSecurity.logSecurityEvent(tokenRecord.user_id, 'logout_success', req.ip, req.headers['user-agent'], { deviceId: tokenRecord.device_id });
    }

    return successResponse(res, 200, null, 'Logged out successfully');
  } catch (error) {
    return next(error);
  }
}

async function logoutAll(req, res, next) {
  try {
    const userId = req.user.sub || req.user.id;
    await AuthSecurity.revokeAllRefreshTokens(userId);
    await AuthSecurity.logSecurityEvent(userId, 'logout_all_success', req.ip, req.headers['user-agent']);
    return successResponse(res, 200, null, 'All sessions logged out successfully');
  } catch (error) {
    return next(error);
  }
}

async function getProfile(req, res, next) {
  try {
    const userId = req.user.sub || req.user.id; // Support both sub and id for backwards compatibility
    const user = await User.findById(userId);
    if (!user) return errorResponse(res, 404, 'User not found');
    return successResponse(res, 200, {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone || null,
        role: user.role,
        created_at: user.created_at,
      }
    }, 'Profile retrieved successfully');
  } catch (error) {
    return next(error);
  }
}

async function updateProfile(req, res, next) {
  try {
    const updates = {};
    if (req.body.name) updates.name = req.body.name;
    if (req.body.phone) updates.phone = normalizeIndianPhone(req.body.phone);
    if (req.body.password) {
      updates.password_hash = await bcrypt.hash(req.body.password, 12);
    }

    if (Object.keys(updates).length === 0) {
      return errorResponse(res, 400, 'No update fields provided');
    }

    const userId = req.user.sub || req.user.id;
    const updatedUser = await User.updateUser(userId, updates);
    if (!updatedUser) return errorResponse(res, 404, 'User not found');

    return successResponse(res, 200, { user: updatedUser }, 'Profile updated successfully');
  } catch (error) {
    return next(error);
  }
}

async function updatePreferences(req, res, next) {
  try {
    const { preferred_language } = req.body;
    
    if (!preferred_language) {
      return errorResponse(res, 400, 'preferred_language is required');
    }
    
    if (!['en', 'hi', 'mr'].includes(preferred_language)) {
      return errorResponse(res, 400, 'Invalid language code. Allowed values: en, hi, mr');
    }

    const userId = req.user.sub || req.user.id;
    const updatedUser = await User.updateUser(userId, { preferred_language });
    if (!updatedUser) return errorResponse(res, 404, 'User not found');

    return successResponse(res, 200, { preferred_language: updatedUser.preferred_language }, 'Preferences updated successfully');
  } catch (error) {
    return next(error);
  }
}

async function deleteAccount(req, res, next) {
  try {
    const userId = req.user.sub || req.user.id;
    
    // Revoke all tokens to immediately kill active sessions
    await AuthSecurity.revokeAllRefreshTokens(userId);
    
    // Delete user from the database (Cascades will handle related tables like user_devices, notifications, etc.)
    const deleted = await User.deleteUser(userId);
    
    if (!deleted) return errorResponse(res, 404, 'User not found');
    
    // Anonymized in security_logs and news, so no action needed there
    return successResponse(res, 200, null, 'Account and all associated data successfully deleted');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  register,
  login,
  refresh,
  logout,
  logoutAll,
  getProfile,
  updateProfile,
  updatePreferences,
  deleteAccount,
};