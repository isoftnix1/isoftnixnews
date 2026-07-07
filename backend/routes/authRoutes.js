const express = require('express');
const { register, login, refresh, logout, logoutAll, getProfile, updateProfile, updatePreferences } = require('../controllers/authController');
const {
  forgotPassword,
  verifyResetOtp,
  resetPassword,
} = require('../controllers/passwordResetController');
const { authMiddleware } = require('../middleware/authMiddleware');
const validate = require('../middleware/validateRequest');
const schemas = require('../utils/schemas');

const {
  validateRegister,
  validateLogin,
  validateForgotPassword,
  validateResetPassword
} = require('../middleware/expressValidators');

const router = express.Router();

router.post('/register', validateRegister, register);
router.post('/login', validateLogin, login);
router.post('/refresh', refresh);
router.post('/logout', authMiddleware, logout);
router.post('/logout-all', authMiddleware, logoutAll);
router.post('/forgot-password', validateForgotPassword, forgotPassword);
router.post('/verify-reset-otp', validate(schemas.verifyResetOtp), verifyResetOtp);
router.post('/reset-password', validateResetPassword, resetPassword);
router.get('/me', authMiddleware, getProfile);
router.put('/me', authMiddleware, validate(schemas.updateProfile), updateProfile);
router.patch('/preferences', authMiddleware, validate(schemas.preferences), updatePreferences);

module.exports = router;
