const express = require('express');
const { register, login, getProfile, updateProfile, updatePreferences } = require('../controllers/authController');
const {
  forgotPassword,
  verifyResetOtp,
  resetPassword,
} = require('../controllers/passwordResetController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validateRequest');
const schemas = require('../utils/schemas');

const router = express.Router();

router.post('/register', validate(schemas.register), register);
router.post('/login', validate(schemas.login), login);
router.post('/forgot-password', validate(schemas.forgotPassword), forgotPassword);
router.post('/verify-reset-otp', validate(schemas.verifyResetOtp), verifyResetOtp);
router.post('/reset-password', validate(schemas.resetPassword), resetPassword);
router.get('/me', authMiddleware, getProfile);
router.put('/me', authMiddleware, validate(schemas.updateProfile), updateProfile);
router.patch('/preferences', authMiddleware, validate(schemas.preferences), updatePreferences);

module.exports = router;
