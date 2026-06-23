const News = require('../models/News');
const Category = require('../models/Category');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const { validateNewsInput } = require('../utils/validators');
const { uploadToCloudinary } = require('../services/cloudinaryService');
const { sendNotificationToTokens } = require('../services/notificationService');
const { getAllTokens, createNotification } = require('../models/Notification');
const User = require('../models/User');

function isUuid(str) {
  return /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(str);
}

async function listNews(req, res, next) {
  try {
    const page = Number(req.query.page || 1);
    const limit = Number(req.query.limit || 10);
    const search = req.query.search || '';
    const categoryId = req.query.categoryId || null;

    const result = await News.getNewsPage({ page, limit, search, categoryId });
    return successResponse(res, 200, result);
  } catch (error) {
    return next(error);
  }
}

async function getNewsByIdController(req, res, next) {
  try {
    if (!isUuid(req.params.id)) return errorResponse(res, 400, 'Invalid article ID format');
    const news = await News.getNewsById(req.params.id);
    if (!news) return errorResponse(res, 404, 'News not found');
    return successResponse(res, 200, news);
  } catch (error) {
    return next(error);
  }
}

async function createNews(req, res, next) {
  try {
    const validationError = validateNewsInput(req.body);
    if (validationError) return errorResponse(res, 400, validationError);

    const category = await Category.getCategoryById(req.body.categoryId);
    if (!category) return errorResponse(res, 404, 'Category not found');

    const imageFile = req.files?.image?.[0];
    const videoFile = req.files?.video?.[0];

    let imageUrl = req.body.imageUrl || null;
    let videoUrl = req.body.videoUrl || null;

    if (imageFile) {
      const uploadedImage = await uploadToCloudinary(imageFile, 'news/images');
      imageUrl = uploadedImage?.secure_url || null;
    }

    if (videoFile) {
      const uploadedVideo = await uploadToCloudinary(videoFile, 'news/videos');
      videoUrl = uploadedVideo?.secure_url || null;
    }

    const savedNews = await News.createNews({
      title: req.body.title,
      content: req.body.content,
      authorId: req.user.id,
      categoryId: req.body.categoryId,
      imageUrl,
      videoUrl,
      isPublished: req.body.isPublished !== undefined ? req.body.isPublished === true || req.body.isPublished === 'true' : true,
    });

    const tokens = await getAllTokens();
    if (tokens.length) {
      await sendNotificationToTokens(
        tokens,
        'New article published',
        savedNews.title,
        { newsId: savedNews.id }
      );
    }

    // Save notification to database for all users so it appears in the app's notification center
    const allUsers = await User.getAllUsers();
    await Promise.all(
      allUsers.map((user) =>
        createNotification({
          userId: user.id,
          title: 'New article published',
          body: savedNews.title,
          data: { newsId: savedNews.id }
        })
      )
    );

    return successResponse(res, 201, savedNews, 'News created successfully');
  } catch (error) {
    return next(error);
  }
}

async function updateNews(req, res, next) {
  try {
    if (!isUuid(req.params.id)) return errorResponse(res, 400, 'Invalid article ID format');
    const existing = await News.getNewsById(req.params.id);
    if (!existing) return errorResponse(res, 404, 'News not found');

    const imageFile = req.files?.image?.[0];
    const videoFile = req.files?.video?.[0];

    let updates = {
      title: req.body.title,
      content: req.body.content,
      category_id: req.body.categoryId,
      is_published: req.body.isPublished,
    };

    if (imageFile) {
      const uploadedImage = await uploadToCloudinary(imageFile, 'news/images');
      updates.image_url = uploadedImage?.secure_url || null;
    } else if (req.body.imageUrl === '') {
      updates.image_url = null;
    } else if (req.body.imageUrl) {
      updates.image_url = req.body.imageUrl;
    }

    if (videoFile) {
      const uploadedVideo = await uploadToCloudinary(videoFile, 'news/videos');
      updates.video_url = uploadedVideo?.secure_url || null;
    } else if (req.body.videoUrl === '') {
      updates.video_url = null;
    } else if (req.body.videoUrl) {
      updates.video_url = req.body.videoUrl;
    }

    Object.keys(updates).forEach((key) => {
      if (updates[key] === undefined) delete updates[key];
      if (updates[key] === '') delete updates[key];
    });

    const updatedNews = await News.updateNews(req.params.id, updates);
    return successResponse(res, 200, updatedNews, 'News updated successfully');
  } catch (error) {
    return next(error);
  }
}

async function deleteNews(req, res, next) {
  try {
    if (!isUuid(req.params.id)) return errorResponse(res, 400, 'Invalid article ID format');
    const existing = await News.getNewsById(req.params.id);
    if (!existing) return errorResponse(res, 404, 'News not found');

    await News.deleteNews(req.params.id);
    return successResponse(res, 200, null, 'News deleted successfully');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listNews,
  getNewsByIdController,
  createNews,
  updateNews,
  deleteNews,
};
