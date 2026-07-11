const Joi = require('joi');
const { INDIAN_MOBILE_PATTERN, normalizeIndianPhone } = require('./phoneUtils');

// ─────────────────────────────────────────────
// Reusable primitives
// ─────────────────────────────────────────────

const uuid = Joi.string()
  .guid({ version: ['uuidv4'] })
  .required()
  .messages({ 'string.guid': 'Must be a valid UUID' });

const lang = Joi.string()
  .valid('en', 'hi', 'mr')
  .default('en')
  .messages({ 'any.only': 'Language must be one of: en, hi, mr' });

const positiveInt = (defaultVal) =>
  Joi.number().integer().min(1).default(defaultVal);

const indianPhone = Joi.string()
  .trim()
  .required()
  .custom((value, helpers) => {
    const normalized = normalizeIndianPhone(value);
    if (!normalized || !INDIAN_MOBILE_PATTERN.test(normalized)) {
      return helpers.error('string.indianPhone');
    }
    return normalized;
  })
  .messages({
    'string.empty': 'Phone number is required',
    'any.required': 'Phone number is required',
    'string.indianPhone':
      'Enter a valid 10-digit Indian mobile number (starting with 6–9)',
  });

const optionalIndianPhone = Joi.string()
  .trim()
  .optional()
  .allow('', null)
  .custom((value, helpers) => {
    if (value == null || value === '') return value;
    const normalized = normalizeIndianPhone(value);
    if (!normalized || !INDIAN_MOBILE_PATTERN.test(normalized)) {
      return helpers.error('string.indianPhone');
    }
    return normalized;
  })
  .messages({
    'string.indianPhone':
      'Enter a valid 10-digit Indian mobile number (starting with 6–9)',
  });

// ─────────────────────────────────────────────
// Auth schemas
// ─────────────────────────────────────────────

const passwordPattern = /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$/;

const register = Joi.object({
  name: Joi.string().trim().min(2).max(100).required()
    .messages({ 'string.empty': 'Name is required', 'string.min': 'Name must be at least 2 characters' }),
  email: Joi.string().email().lowercase().required()
    .messages({ 'string.email': 'A valid email address is required' }),
  password: Joi.string()
    .pattern(passwordPattern)
    .required()
    .messages({
      'string.pattern.base':
        'Password must be at least 8 characters and contain: an uppercase letter, a lowercase letter, a number, and a special character (@$!%*#?&)',
    }),
  phone: indianPhone,
});

const login = Joi.object({
  email: Joi.string().email().lowercase().required()
    .messages({ 'string.email': 'A valid email address is required' }),
  password: Joi.string().required()
    .messages({ 'string.empty': 'Password is required' }),
});

const updateProfile = Joi.object({
  name: Joi.string().trim().min(2).max(100).optional(),
  phone: optionalIndianPhone,
  password: Joi.string()
    .pattern(passwordPattern)
    .optional()
    .messages({
      'string.pattern.base':
        'Password must be at least 8 characters and contain: an uppercase letter, a lowercase letter, a number, and a special character (@$!%*#?&)',
    }),
}).min(1).messages({ 'object.min': 'At least one field must be provided' });

const preferences = Joi.object({
  preferred_language: lang.required()
    .messages({ 'any.required': 'preferred_language is required' }),
});

const forgotPassword = Joi.object({
  email: Joi.string().email().lowercase().required()
    .messages({ 'string.email': 'A valid email address is required' }),
});

const verifyResetOtp = Joi.object({
  email: Joi.string().email().lowercase().required()
    .messages({ 'string.email': 'A valid email address is required' }),
  otp: Joi.string().pattern(/^\d{6}$/).required()
    .messages({
      'string.pattern.base': 'OTP must be exactly 6 digits',
      'string.empty': 'OTP is required',
    }),
});

const resetPassword = Joi.object({
  resetToken: Joi.string().trim().min(20).required()
    .messages({ 'string.empty': 'Reset token is required' }),
  newPassword: Joi.string()
    .pattern(passwordPattern)
    .required()
    .messages({
      'string.pattern.base':
        'Password must be at least 8 characters and contain: an uppercase letter, a lowercase letter, a number, and a special character (@$!%*#?&)',
    }),
});

// ─────────────────────────────────────────────
// News schemas
// ─────────────────────────────────────────────

const createNews = Joi.object({
  title_en: Joi.string().trim().min(3).max(500).required()
    .messages({ 'string.empty': 'English title is required' }),
  content_en: Joi.string().trim().min(10).required()
    .messages({ 'string.empty': 'English content is required' }),
  title_hi: Joi.string().trim().min(1).required()
    .messages({ 'string.empty': 'Hindi title is required' }),
  content_hi: Joi.string().trim().min(1).required()
    .messages({ 'string.empty': 'Hindi content is required' }),
  title_mr: Joi.string().trim().min(1).required()
    .messages({ 'string.empty': 'Marathi title is required' }),
  content_mr: Joi.string().trim().min(1).required()
    .messages({ 'string.empty': 'Marathi content is required' }),
  // categoryIds come in from multipart as categoryIds[0], categoryIds[1] etc.
  // Express body-parser assembles them into an array — accept either
  'categoryIds[]': Joi.alternatives().try(
    Joi.array().items(Joi.string().guid()).min(1),
    Joi.string().guid()
  ).optional(),
  categoryIds: Joi.alternatives().try(
    Joi.array().items(Joi.string().guid()).min(1),
    Joi.string().guid()
  ).optional(),
  imageUrl: Joi.string().uri().optional().allow('', null),
  videoUrl: Joi.string().uri().optional().allow('', null),
  source_name: Joi.string().trim().max(200).optional().allow('', null),
  source_url: Joi.string().uri().optional().allow('', null),
  isPublished: Joi.alternatives().try(
    Joi.boolean(),
    Joi.string().valid('true', 'false')
  ).optional(),
});

const newsQuery = Joi.object({
  page: positiveInt(1),
  limit: Joi.number().integer().min(1).max(1000).default(10),
  search: Joi.string().trim().max(200).optional().allow(''),
  categoryId: Joi.string().guid().optional().allow('', null),
  lang,
  startDate: Joi.string().isoDate().optional().allow('', null),
  endDate: Joi.string().isoDate().optional().allow('', null),
  includeDrafts: Joi.alternatives().try(Joi.boolean(), Joi.string().valid('true', 'false')).optional(),
  onlyDrafts: Joi.alternatives().try(Joi.boolean(), Joi.string().valid('true', 'false')).optional(),
});

// ─────────────────────────────────────────────
// Category schemas
// ─────────────────────────────────────────────

const createCategory = Joi.object({
  name: Joi.string().trim().min(2).max(100).required()
    .messages({ 'string.empty': 'Category name is required' }),
  slug: Joi.string().trim().lowercase()
    .pattern(/^[a-z0-9-]+$/)
    .min(2).max(100).required()
    .messages({
      'string.empty': 'Slug is required',
      'string.pattern.base': 'Slug must contain only lowercase letters, numbers, and hyphens',
    }),
});

// ─────────────────────────────────────────────
// Param schema
// ─────────────────────────────────────────────

const uuidParam = Joi.object({
  id: uuid,
});

// ─────────────────────────────────────────────
// Device schemas
// ─────────────────────────────────────────────

const registerDeviceSchema = Joi.object({
  fcm_token: Joi.string().trim().required().messages({ 'string.empty': 'FCM token is required' }),
  device_id: Joi.string().trim().required().messages({ 'string.empty': 'Device ID is required' }),
  device_name: Joi.string().trim().optional().allow('', null),
  manufacturer: Joi.string().trim().optional().allow('', null),
  model: Joi.string().trim().optional().allow('', null),
  platform: Joi.string().trim().required(),
  os_version: Joi.string().trim().optional().allow('', null),
  app_version: Joi.string().trim().optional().allow('', null),
  latitude: Joi.number().optional().allow(null),
  longitude: Joi.number().optional().allow(null),
  location_name: Joi.string().optional().allow(null, ''),
});

const heartbeatSchema = Joi.object({
  device_id: Joi.string().trim().required().messages({ 'string.empty': 'Device ID is required' }),
  app_version: Joi.string().trim().optional().allow('', null),
  os_version: Joi.string().trim().optional().allow('', null),
  latitude: Joi.number().optional().allow(null),
  longitude: Joi.number().optional().allow(null),
  location_name: Joi.string().optional().allow(null, ''),
});

// ─────────────────────────────────────────────
// Exports
// ─────────────────────────────────────────────

module.exports = {
  register,
  login,
  updateProfile,
  preferences,
  forgotPassword,
  verifyResetOtp,
  resetPassword,
  createNews,
  newsQuery,
  createCategory,
  uuidParam,
  registerDeviceSchema,
  heartbeatSchema,
};
