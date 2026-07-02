const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { sendPasswordResetOtpEmail } = require('../services/emailService');
const { successResponse, errorResponse } = require('../utils/responseHandler');

const GENERIC_FORGOT_MESSAGE =
  'If an account exists with that email, a verification code has been sent.';
const OTP_EXPIRY_MINUTES = 10;
const RESET_TOKEN_EXPIRY = '15m';

function generateOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

function issueResetToken(user) {
  return jwt.sign(
    {
      purpose: 'password_reset',
      id: user.id,
      email: user.email,
      v: user.password_reset_version,
    },
    process.env.JWT_SECRET,
    { expiresIn: RESET_TOKEN_EXPIRY, algorithm: 'HS256' }
  );
}

async function forgotPassword(req, res, next) {
  try {
    const email = req.body.email.toLowerCase().trim();
    const user = await User.findByEmail(email);

    if (user && user.is_active !== false) {
      const otp = generateOtp();
      const otpHash = await bcrypt.hash(otp, 10);
      const expiry = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

      await User.setPasswordResetOtp(user.id, otpHash, expiry);

      try {
        await sendPasswordResetOtpEmail(email, otp);
      } catch (emailError) {
        console.error('[Password Reset] Failed to send OTP email:', emailError.message);
      }
    }

    return successResponse(res, 200, null, GENERIC_FORGOT_MESSAGE);
  } catch (error) {
    return next(error);
  }
}

async function verifyResetOtp(req, res, next) {
  try {
    const email = req.body.email.toLowerCase().trim();
    const otp = req.body.otp.trim();
    const user = await User.findByEmailForPasswordReset(email);

    if (
      !user ||
      !user.reset_otp_hash ||
      !user.reset_otp_expiry ||
      user.is_active === false
    ) {
      return errorResponse(res, 400, 'Invalid or expired verification code');
    }

    if (new Date() > new Date(user.reset_otp_expiry)) {
      return errorResponse(res, 400, 'Verification code has expired');
    }

    const isValidOtp = await bcrypt.compare(otp, user.reset_otp_hash);
    if (!isValidOtp) {
      return errorResponse(res, 400, 'Invalid or expired verification code');
    }

    await User.clearPasswordResetOtp(user.id);

    const refreshedUser = await User.findByEmailForPasswordReset(email);
    const resetToken = issueResetToken(refreshedUser);

    return successResponse(
      res,
      200,
      { resetToken },
      'OTP verified successfully'
    );
  } catch (error) {
    return next(error);
  }
}

async function resetPassword(req, res, next) {
  try {
    const { resetToken, newPassword } = req.body;

    let decoded;
    try {
      decoded = jwt.verify(resetToken, process.env.JWT_SECRET, {
        algorithms: ['HS256'],
      });
    } catch (error) {
      return errorResponse(res, 400, 'Invalid or expired reset token');
    }

    if (decoded.purpose !== 'password_reset') {
      return errorResponse(res, 400, 'Invalid or expired reset token');
    }

    const user = await User.findByEmailForPasswordReset(decoded.email);
    if (!user || user.id !== decoded.id || user.is_active === false) {
      return errorResponse(res, 400, 'Invalid or expired reset token');
    }

    if (user.password_reset_version !== decoded.v) {
      return errorResponse(res, 400, 'Invalid or expired reset token');
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await User.completePasswordReset(user.id, passwordHash);

    return successResponse(res, 200, null, 'Password reset successfully');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  forgotPassword,
  verifyResetOtp,
  resetPassword,
};
