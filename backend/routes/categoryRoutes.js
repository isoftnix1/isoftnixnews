const express = require('express');
const {
  listCategories,
  createCategory,
  updateCategory,
  deleteCategory,
} = require('../controllers/categoryController');
const { authMiddleware } = require('../middleware/authMiddleware');
const adminMiddleware = require('../middleware/adminMiddleware');
const validate = require('../middleware/validateRequest');
const schemas = require('../utils/schemas');

const router = express.Router();

router.get('/', listCategories);
router.post('/', authMiddleware, adminMiddleware, validate(schemas.createCategory), createCategory);
router.put('/:id', authMiddleware, adminMiddleware, validate(schemas.uuidParam, 'params'), updateCategory);
router.delete('/:id', authMiddleware, adminMiddleware, validate(schemas.uuidParam, 'params'), deleteCategory);

module.exports = router;
