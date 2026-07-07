const { body, validationResult } = require('express-validator');
const { errorResponse } = require('../utils/responseHandler');

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    // Return the first error message
    return errorResponse(res, 400, errors.array()[0].msg);
  }
  next();
};

const passwordRules = body('password')
  .isLength({ min: 8, max: 128 }).withMessage('Password must be between 8 and 128 characters')
  .matches(/[A-Z]/).withMessage('Password must contain an uppercase letter')
  .matches(/[a-z]/).withMessage('Password must contain a lowercase letter')
  .matches(/\d/).withMessage('Password must contain a number')
  .matches(/[@$!%*#?&]/).withMessage('Password must contain a special character')
  .not().isIn(['12345678', 'password123', 'qwerty123']).withMessage('Password is too common');

const validateRegister = [
  body('name')
    .trim()
    .isLength({ min: 2, max: 100 }).withMessage('Name must be between 2 and 100 characters')
    .escape(),
  body('email')
    .trim()
    .isEmail().withMessage('Valid email is required')
    .normalizeEmail(),
  passwordRules,
  body('phone')
    .optional()
    .trim()
    .matches(/^[6-9]\d{9}$/).withMessage('Enter a valid 10-digit Indian mobile number'),
  handleValidationErrors
];

const validateLogin = [
  body('email')
    .trim()
    .isEmail().withMessage('Valid email is required')
    .normalizeEmail(),
  body('password')
    .trim()
    .notEmpty().withMessage('Password is required'),
  handleValidationErrors
];

const validateForgotPassword = [
  body('email')
    .trim()
    .isEmail().withMessage('Valid email is required')
    .normalizeEmail(),
  handleValidationErrors
];

const validateResetPassword = [
  body('resetToken')
    .trim()
    .notEmpty().withMessage('Reset token is required'),
  passwordRules,
  handleValidationErrors
];

module.exports = {
  validateRegister,
  validateLogin,
  validateForgotPassword,
  validateResetPassword
};
