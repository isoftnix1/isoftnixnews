const express = require('express');
const {
  listNews,
  getNewsByIdController,
  createNews,
  updateNews,
  deleteNews,
} = require('../controllers/newsController');
const authMiddleware = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');
const upload = require('../middleware/uploadMiddleware');

const router = express.Router();

router.get('/', listNews);
router.get('/:id', getNewsByIdController);
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
  upload.fields([
    { name: 'image', maxCount: 1 },
    { name: 'video', maxCount: 1 },
  ]),
  updateNews
);
router.delete('/:id', authMiddleware, adminMiddleware, deleteNews);

module.exports = router;
