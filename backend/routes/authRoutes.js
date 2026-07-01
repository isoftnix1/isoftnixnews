const express = require('express');
const { register, login, getProfile, updateProfile, updatePreferences } = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validateRequest');
const schemas = require('../utils/schemas');

const router = express.Router();

router.post('/register', validate(schemas.register), register);
router.post('/login', validate(schemas.login), login);
router.get('/me', authMiddleware, getProfile);
router.put('/me', authMiddleware, validate(schemas.updateProfile), updateProfile);
router.patch('/preferences', authMiddleware, validate(schemas.preferences), updatePreferences);

module.exports = router;
