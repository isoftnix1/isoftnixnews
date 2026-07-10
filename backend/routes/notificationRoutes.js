const express = require('express');
const { registerToken, listNotifications, deleteNotification, markAsRead } = require('../controllers/notificationController');
const { authMiddleware } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/register-token', authMiddleware, registerToken);
router.get('/', authMiddleware, listNotifications);
router.delete('/:id', authMiddleware, deleteNotification);
router.put('/:id/read', authMiddleware, markAsRead);

module.exports = router;
