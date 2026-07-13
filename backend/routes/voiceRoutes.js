const express = require('express');
const router = express.Router();
const { getVoiceSummary } = require('../controllers/voiceController');
const { authMiddleware } = require('../middleware/authMiddleware');

// Using authMiddleware to ensure only logged-in users use the AI voice assistant
router.post('/summary', getVoiceSummary);

module.exports = router;
