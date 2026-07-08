const Category = require('../models/Category');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const cache = require('../utils/cache');

async function listCategories(req, res, next) {
  try {
    const lang = req.query.lang || 'en';
    const cacheKey = `categories_${lang}`;

    // 1. Check cache
    const cachedCategories = cache.getCache(cacheKey);
    if (cachedCategories) {
      return successResponse(res, 200, cachedCategories);
    }

    // 2. Fetch from DB
    const categories = await Category.getAllCategories(lang);

    // 3. Set cache for 1 hour (3600 seconds)
    cache.setCache(cacheKey, categories, 3600);

    return successResponse(res, 200, categories);
  } catch (error) {
    return next(error);
  }
}

async function createCategory(req, res, next) {
  try {
    const { name, slug } = req.body;
    if (!name || !slug) {
      return errorResponse(res, 400, 'Name and slug are required');
    }

    const category = await Category.createCategory({ name, slug });
    
    // Invalidate category cache globally
    cache.deletePattern('categories_');

    return successResponse(res, 201, category, 'Category created successfully');
  } catch (error) {
    return next(error);
  }
}

async function updateCategory(req, res, next) {
  try {
    const category = await Category.updateCategory(req.params.id, req.body);
    if (!category) return errorResponse(res, 404, 'Category not found');
    
    // Invalidate category cache globally
    cache.deletePattern('categories_');

    return successResponse(res, 200, category, 'Category updated successfully');
  } catch (error) {
    return next(error);
  }
}

async function deleteCategory(req, res, next) {
  try {
    const category = await Category.getCategoryById(req.params.id);
    if (!category) return errorResponse(res, 404, 'Category not found');

    await Category.deleteCategory(req.params.id);
    
    // Invalidate category cache globally
    cache.deletePattern('categories_');

    return successResponse(res, 200, null, 'Category deleted successfully');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listCategories,
  createCategory,
  updateCategory,
  deleteCategory,
};
