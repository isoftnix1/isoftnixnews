const express = require('express');
const {
  listNews,
  getNewsByIdController,
  createNews,
  updateNews,
  deleteNews,
} = require('../controllers/newsController');
const authMiddleware = require('../middleware/authMiddleware');
const optionalAuthMiddleware = require('../middleware/authMiddleware').optionalAuthMiddleware;
const adminMiddleware = require('../middleware/adminMiddleware');
const upload = require('../middleware/uploadMiddleware');
const validate = require('../middleware/validateRequest');
const schemas = require('../utils/schemas');

const router = express.Router();

// Public routes (optional auth allows admins to include drafts)
router.get('/', optionalAuthMiddleware, validate(schemas.newsQuery, 'query'), listNews);
router.get('/:id', optionalAuthMiddleware, validate(schemas.uuidParam, 'params'), getNewsByIdController);

// Admin-only routes
router.post(
  '/',
  authMiddleware,
  adminMiddleware,
  upload.fields([
    { name: 'image', maxCount: 1 },
    { name: 'video', maxCount: 1 },
  ]),
  createNews
);
router.put(
  '/:id',
  authMiddleware,
  adminMiddleware,
  validate(schemas.uuidParam, 'params'),
  upload.fields([
    { name: 'image', maxCount: 1 },
    { name: 'video', maxCount: 1 },
  ]),
  updateNews
);
router.delete('/:id', authMiddleware, adminMiddleware, validate(schemas.uuidParam, 'params'), deleteNews);

module.exports = router;
