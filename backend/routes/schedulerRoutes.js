const express = require('express');
const { processReminders } = require('../services/reminderService');
const { authMiddleware } = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');

const router = express.Router();

// Trigger manually
router.post('/process-reminders', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const result = await processReminders('manual');
    if (result.status === 'SUCCESS') {
      res.json({ message: 'Reminders processed successfully', data: result });
    } else {
      res.status(500).json({ error: 'Reminders failed', data: result });
    }
  } catch (err) {
    console.error('Error triggering reminders manually:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
