const News = require('../models/News');
const Category = require('../models/Category');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const { validateNewsInput } = require('../utils/validators');
const { uploadToCloudinary, deleteFromCloudinary, extractCloudinaryPublicId } = require('../services/cloudinaryService');
const { sendNotificationToTokens } = require('../services/notificationService');
const { getTokensGroupedByLanguage, createNotification } = require('../models/Notification');
const User = require('../models/User');
const { validateFileSignature } = require('../utils/validateFileType');
const upload = require('../middleware/uploadMiddleware');
const { pool } = require('../config/db');

function isUuid(str) {
  return /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(str);
}

async function listNews(req, res, next) {
  try {
    const page = Number(req.query.page || 1);
    const limit = Number(req.query.limit || 10);
    const search = req.query.search || '';
    const categoryId = req.query.categoryId || null;
    const lang = req.query.lang || 'en';
    const startDate = req.query.startDate || null;
    const endDate = req.query.endDate || null;
    const isAdmin = req.user?.role === 'admin';

    const result = await News.getNewsPage({
      page,
      limit,
      search,
      categoryId,
      startDate,
      endDate,
      publishedOnly: !isAdmin,
    });

    // Map language specific columns to 'title' and 'content' for the response
    const mappedItems = result.items.map(item => {
      let title = item.title_en;
      let content = item.content_en;
      let category_name = item.category_name_en;

      let mappedCategories = item.categories || [];

      if (lang === 'hi') {
        title = item.title_hi || title;
        content = item.content_hi || content;
        category_name = item.category_name_hi || category_name;
        mappedCategories = mappedCategories.map(c => ({ ...c, name: c.name_hi || c.name_en }));
      } else if (lang === 'mr') {
        title = item.title_mr || title;
        content = item.content_mr || content;
        category_name = item.category_name_mr || category_name;
        mappedCategories = mappedCategories.map(c => ({ ...c, name: c.name_mr || c.name_en }));
      } else {
        mappedCategories = mappedCategories.map(c => ({ ...c, name: c.name_en }));
      }

      // Truncate content for list preview
      if (content && content.length > 200) {
        content = content.substring(0, 200);
      }

      return {
        ...item,
        title,
        content,
        category_name,
        categories: mappedCategories,
      };
    });

    result.items = mappedItems;

    return successResponse(res, 200, result);
  } catch (error) {
    return next(error);
  }
}

async function getNewsByIdController(req, res, next) {
  try {
    if (!isUuid(req.params.id)) return errorResponse(res, 400, 'Invalid article ID format');
    const isAdmin = req.user?.role === 'admin';
    const news = await News.getNewsById(req.params.id, { publishedOnly: !isAdmin });
    if (!news) return errorResponse(res, 404, 'News not found');

    const lang = req.query.lang || 'en';
    let title = news.title_en;
    let content = news.content_en;
    let category_name = news.category_name_en;

    let mappedCategories = news.categories || [];

    if (lang === 'hi') {
      title = news.title_hi || title;
      content = news.content_hi || content;
      category_name = news.category_name_hi || category_name;
      mappedCategories = mappedCategories.map(c => ({ ...c, name: c.name_hi || c.name_en }));
    } else if (lang === 'mr') {
      title = news.title_mr || title;
      content = news.content_mr || content;
      category_name = news.category_name_mr || category_name;
      mappedCategories = mappedCategories.map(c => ({ ...c, name: c.name_mr || c.name_en }));
    } else {
      mappedCategories = mappedCategories.map(c => ({ ...c, name: c.name_en }));
    }

    const mappedNews = {
      ...news,
      title,
      content,
      category_name,
      categories: mappedCategories,
    };

    return successResponse(res, 200, mappedNews);
  } catch (error) {
    return next(error);
  }
}

async function createNews(req, res, next) {
  try {
    const validationError = validateNewsInput(req.body);
    if (validationError) return errorResponse(res, 400, validationError);

    let categoryIds = req.body.categoryIds;
    if (typeof categoryIds === 'string') {
      categoryIds = [categoryIds];
      req.body.categoryIds = categoryIds;
    }
    // Just verify the primary category exists for validation
    if (categoryIds && categoryIds.length > 0) {
      const category = await Category.getCategoryById(categoryIds[0]);
      if (!category) return errorResponse(res, 404, 'Category not found');
    }

    const imageFile = req.files?.image?.[0];
    const videoFile = req.files?.video?.[0];

    // ── Per-type size enforcement ────────────────────────────────────────────
    if (imageFile && imageFile.size > upload.IMAGE_SIZE_LIMIT) {
      return res.status(400).json({
        success: false,
        message: "Image exceeds maximum allowed size.",
        maxSize: "5 MB"
      });
    }
    if (videoFile && videoFile.size > upload.VIDEO_SIZE_LIMIT) {
      return res.status(400).json({
        success: false,
        message: "Video exceeds maximum allowed size.",
        maxSize: "15 MB"
      });
    }

    // ── Magic-byte validation (must run before Cloudinary) ───────────────────
    if (imageFile) {
      const sigError = await validateFileSignature(imageFile);
      if (sigError) return res.status(422).json({ success: false, message: sigError, data: null });
    }
    if (videoFile) {
      const sigError = await validateFileSignature(videoFile);
      if (sigError) return res.status(422).json({ success: false, message: sigError, data: null });
    }

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
      title_en: req.body.title_en,
      content_en: req.body.content_en,
      title_hi: req.body.title_hi,
      content_hi: req.body.content_hi,
      title_mr: req.body.title_mr,
      content_mr: req.body.content_mr,
      authorId: req.user.id,
      categoryIds: req.body.categoryIds,
      imageUrl,
      videoUrl,
      source_name: req.body.source_name || null,
      source_url: req.body.source_url || null,
      isPublished: req.body.isPublished !== undefined ? req.body.isPublished === true || req.body.isPublished === 'true' : true,
    });

    const groupedTokens = await getTokensGroupedByLanguage();
    
    const sendBatch = async (tokens, title, body) => {
      if (tokens && tokens.length > 0) {
        // Trim body at a word boundary, roughly 120 chars
        let trimmedBody = body || 'New Article';
        trimmedBody = trimmedBody.replace(/\n/g, ' ').trim();
        if (trimmedBody.length > 120) {
          const sub = trimmedBody.substring(0, 120);
          trimmedBody = sub.substring(0, Math.min(sub.length, sub.lastIndexOf(' '))) + '...';
        }
        await sendNotificationToTokens(
          tokens,
          title || 'New Article',
          trimmedBody,
          { newsId: savedNews.id }
        );
      }
    };

    await Promise.all([
      sendBatch(groupedTokens.en, savedNews.title_en, savedNews.content_en),
      sendBatch(groupedTokens.hi, savedNews.title_hi, savedNews.content_hi),
      sendBatch(groupedTokens.mr, savedNews.title_mr, savedNews.content_mr)
    ]);

    // Save notification to database for all users so it appears in the app's notification center
    const allUsers = await User.getAllUsers();
    await Promise.all(
      allUsers.map((user) =>
        createNotification({
          userId: user.id,
          title: 'New article published',
          body: savedNews.title_en || 'New Article',
          data: { newsId: savedNews.id }
        })
      )
    );

    return successResponse(res, 201, savedNews, `News created and notifications sent to ${allUsers.length} users!`);
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

    // ── Per-type size enforcement ────────────────────────────────────────────
    if (imageFile && imageFile.size > upload.IMAGE_SIZE_LIMIT) {
      return res.status(400).json({
        success: false,
        message: "Image exceeds maximum allowed size.",
        maxSize: "5 MB"
      });
    }
    if (videoFile && videoFile.size > upload.VIDEO_SIZE_LIMIT) {
      return res.status(400).json({
        success: false,
        message: "Video exceeds maximum allowed size.",
        maxSize: "15 MB"
      });
    }

    // ── Magic-byte validation (must run before Cloudinary) ───────────────────
    if (imageFile) {
      const sigError = await validateFileSignature(imageFile);
      if (sigError) return res.status(422).json({ success: false, message: sigError, data: null });
    }
    if (videoFile) {
      const sigError = await validateFileSignature(videoFile);
      if (sigError) return res.status(422).json({ success: false, message: sigError, data: null });
    }

    let updates = {
      title_en: req.body.title_en,
      content_en: req.body.content_en,
      content_hi: req.body.content_hi,
      title_mr: req.body.title_mr,
      content_mr: req.body.content_mr,
      // category_id will be handled by the model if categoryIds is provided
      source_name: req.body.source_name === '' ? null : req.body.source_name,
      source_url: req.body.source_url === '' ? null : req.body.source_url,
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

    const categoryIds = req.body.categoryIds;
    const updatedNews = await News.updateNews(req.params.id, updates, categoryIds);
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

    // Step 1: Delete DB record immediately (user intent is to remove the article)
    await News.deleteNews(req.params.id);

    // Step 2: Best-effort Cloudinary cleanup — never blocks the response
    const imagePublicId = extractCloudinaryPublicId(existing.image_url);
    const videoPublicId = extractCloudinaryPublicId(existing.video_url);

    const cleanupPromises = [];
    if (imagePublicId) {
      cleanupPromises.push(
        deleteFromCloudinary(imagePublicId, 'image').catch(err =>
          console.warn(`[CLOUDINARY CLEANUP] Failed to delete image ${imagePublicId}:`, err.message)
        )
      );
    }
    if (videoPublicId) {
      cleanupPromises.push(
        deleteFromCloudinary(videoPublicId, 'video').catch(err =>
          console.warn(`[CLOUDINARY CLEANUP] Failed to delete video ${videoPublicId}:`, err.message)
        )
      );
    }

    // Fire cleanup in background — do not await, do not block response
    Promise.all(cleanupPromises);

    return successResponse(res, 200, null, 'News deleted successfully');
  } catch (error) {
    return next(error);
  }
}

async function recordNewsView(req, res, next) {
  try {
    const newsId = req.params.id;
    const userId = req.user.id;

    if (!isUuid(newsId)) return errorResponse(res, 400, 'Invalid article ID format');

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      
      const insertResult = await client.query(
        `INSERT INTO news_views (user_id, news_id) 
         VALUES ($1, $2) 
         ON CONFLICT (user_id, news_id) DO NOTHING`,
        [userId, newsId]
      );
      
      if (insertResult.rowCount > 0) {
        await client.query(
          `UPDATE news SET views_count = views_count + 1 WHERE id = $1`,
          [newsId]
        );
      }
      
      await client.query('COMMIT');
      return successResponse(res, 200, null, 'View recorded');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (error) {
    return next(error);
  }
}

async function getNewsAnalytics(req, res, next) {
  try {
    const newsId = req.params.id;
    if (!isUuid(newsId)) return errorResponse(res, 400, 'Invalid article ID format');

    const news = await News.getNewsById(newsId);
    if (!news) return errorResponse(res, 404, 'News not found');

    const usersResult = await pool.query('SELECT COUNT(*) as count FROM users WHERE is_active = true');
    const totalUsers = parseInt(usersResult.rows[0].count, 10);
    const viewedUsers = news.views_count || 0;
    const notViewedUsers = Math.max(0, totalUsers - viewedUsers);
    const viewPercentage = totalUsers > 0 ? ((viewedUsers / totalUsers) * 100).toFixed(1) : '0.0';

    return successResponse(res, 200, {
      totalUsers,
      viewedUsers,
      notViewedUsers,
      viewPercentage,
      reminderStatus: news.reminder_status,
      reminderSent: news.reminder_sent_count || 0,
      publishedAt: news.published_at || news.created_at,
    });
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
  recordNewsView,
  getNewsAnalytics,
};
