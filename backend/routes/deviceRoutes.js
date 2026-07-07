const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');
const validate = require('../middleware/validateRequest');
const { registerDeviceSchema, heartbeatSchema } = require('../utils/schemas');
const deviceController = require('../controllers/deviceController');

// User endpoints
router.post('/register', authMiddleware, validate(registerDeviceSchema), deviceController.registerDevice);
router.post('/heartbeat', authMiddleware, validate(heartbeatSchema), deviceController.heartbeat);

// Admin endpoints
router.get('/list', authMiddleware, adminMiddleware, deviceController.listAdminDevices);
router.get('/analytics', authMiddleware, adminMiddleware, deviceController.getAdminDeviceAnalytics);

module.exports = router;
