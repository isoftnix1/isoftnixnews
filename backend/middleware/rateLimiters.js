const rateLimit = require('express-rate-limit');

// Generic error message format for rate limits
const createMessage = (msg) => ({ success: false, message: msg });

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  message: createMessage('Too many login attempts from this IP, please try again after 15 minutes'),
  standardHeaders: true,
  legacyHeaders: false,
});

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5,
  message: createMessage('Too many registration attempts from this IP, please try again after an hour'),
  standardHeaders: true,
  legacyHeaders: false,
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: createMessage('Too many refresh token requests. Please log in again.'),
  standardHeaders: true,
  legacyHeaders: false,
});

const forgotPasswordLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3,
  message: createMessage('Too many password reset attempts from this IP, please try again after an hour'),
  standardHeaders: true,
  legacyHeaders: false,
});

const otpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: createMessage('Too many verification attempts from this IP, please try again after 15 minutes'),
  standardHeaders: true,
  legacyHeaders: false,
});

const publicApiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 500, // Higher limit for public APIs
  message: createMessage('Too many requests to public API from this IP, please try again after 15 minutes'),
  standardHeaders: true,
  legacyHeaders: false,
});

const adminApiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200,
  message: createMessage('Too many requests to admin API from this IP, please try again after 15 minutes'),
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  loginLimiter,
  registerLimiter,
  refreshLimiter,
  forgotPasswordLimiter,
  otpLimiter,
  publicApiLimiter,
  adminApiLimiter,
};
