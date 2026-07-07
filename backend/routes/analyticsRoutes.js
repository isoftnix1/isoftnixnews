const express = require('express');
const { recordUsageTime, getUserUsageStats, getGlobalUsageStats } = require('../controllers/analyticsController');
const { authMiddleware, roleMiddleware } = require('../middleware/authMiddleware');

const router = express.Router();

// User facing route to record usage
router.post('/usage-time', authMiddleware, recordUsageTime);

// Admin facing routes
router.get('/global-usage', authMiddleware, roleMiddleware(['admin']), getGlobalUsageStats);
router.get('/usage-time/:userId', authMiddleware, roleMiddleware(['admin']), getUserUsageStats);

module.exports = router;
