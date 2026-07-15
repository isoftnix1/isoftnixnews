const express = require('express');
const router = express.Router();
const { sendMessage, getHistory, getMessages, deleteConversation, summarizeDay } = require('../controllers/chatController');
const { authMiddleware } = require('../middleware/authMiddleware');

// All chat routes require authentication since we are saving history per user
router.use(authMiddleware);

router.post('/message', sendMessage);
router.get('/history', getHistory);
router.get('/:conversationId/messages', getMessages);
router.delete('/history/:conversationId', deleteConversation);
router.post('/summarize-day', summarizeDay);

module.exports = router;
