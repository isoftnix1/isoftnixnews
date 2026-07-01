const Category = require('../models/Category');
const { successResponse, errorResponse } = require('../utils/responseHandler');

async function listCategories(req, res, next) {
  try {
    const lang = req.query.lang || 'en';
    const categories = await Category.getAllCategories(lang);
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
    return successResponse(res, 201, category, 'Category created successfully');
  } catch (error) {
    return next(error);
  }
}

async function updateCategory(req, res, next) {
  try {
    const category = await Category.updateCategory(req.params.id, req.body);
    if (!category) return errorResponse(res, 404, 'Category not found');
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
