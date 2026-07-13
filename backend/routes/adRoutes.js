const express = require('express');
const { getActiveAds, createAd, deleteAd, recordAdView, recordAdClick } = require('../controllers/adController');
const upload = require('../middleware/uploadMiddleware');
const { authMiddleware, roleMiddleware } = require('../middleware/authMiddleware');
const router = express.Router();

router.get('/active', getActiveAds);
router.post('/:id/view', authMiddleware, recordAdView);
router.post('/:id/click', authMiddleware, recordAdClick);

// Admin routes for ads
router.post('/admin/ads', authMiddleware, roleMiddleware(['admin']), upload.fields([{ name: 'image', maxCount: 1 }, { name: 'video', maxCount: 1 }]), createAd);
router.delete('/admin/ads/:id', authMiddleware, roleMiddleware(['admin']), deleteAd);

module.exports = router;
