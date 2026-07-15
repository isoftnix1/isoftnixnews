const { pool } = require('../config/db');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const { uploadToCloudinary } = require('../services/cloudinaryService');

async function getActiveAds(req, res, next) {
  try {
    console.log('[AdController] Fetching active ads for user (Filtering by start_date and end_date)');
    const result = await pool.query(
      'SELECT id, company_name, title, description, image_url, video_url, target_url, views_count, clicks_count FROM advertisements WHERE is_active = TRUE AND (start_date IS NULL OR NOW() >= start_date) AND (end_date IS NULL OR NOW() <= end_date) ORDER BY created_at DESC'
    );
    return successResponse(res, 200, result.rows, 'Active ads retrieved successfully');
  } catch (error) {
    return next(error);
  }
}

async function getAllAds(req, res, next) {
  try {
    console.log('[AdController] Admin fetching ALL ads (ignoring dates for analytics)');
    const result = await pool.query('SELECT * FROM advertisements ORDER BY created_at DESC');
    return successResponse(res, 200, result.rows, 'All ads retrieved successfully');
  } catch (error) {
    return next(error);
  }
}

async function createAd(req, res, next) {
  try {
    const { company_name, title, description, target_url, is_active, start_date, end_date } = req.body;

    if (!company_name || !title || !target_url) {
      return errorResponse(res, 400, 'Company name, title, and target URL are required');
    }

    const imageFile = req.files?.image?.[0];
    const videoFile = req.files?.video?.[0];

    let imageUrl = null;
    let videoUrl = null;

    if (imageFile) {
      const uploadedImage = await uploadToCloudinary(imageFile, 'ads/images');
      imageUrl = uploadedImage?.secure_url || null;
    }

    if (videoFile) {
      const uploadedVideo = await uploadToCloudinary(videoFile, 'ads/videos');
      videoUrl = uploadedVideo?.secure_url || null;
    }

    console.log(`[AdController] Creating Ad: "${title}" - Scheduled from: ${start_date || 'Now'} to ${end_date || 'Forever'}`);

    const result = await pool.query(
      `INSERT INTO advertisements (company_name, title, description, image_url, video_url, target_url, is_active, start_date, end_date) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
      [company_name, title, description || null, imageUrl, videoUrl, target_url, is_active !== undefined ? is_active : true, start_date || null, end_date || null]
    );

    return successResponse(res, 201, result.rows[0], 'Advertisement created successfully');
  } catch (error) {
    return next(error);
  }
}

// Simple internal mock generator for testing if no ads exist
async function ensureSeedAd() {
  const result = await pool.query('SELECT count(*) FROM advertisements');
  if (parseInt(result.rows[0].count) === 0) {
    await pool.query(`
      INSERT INTO advertisements (company_name, title, description, image_url, target_url)
      VALUES (
        'EcoStride', 
        'Step Into Tomorrow', 
        'The most sustainable running shoe ever made. Made from 100% recycled ocean plastic.', 
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=800&q=80', 
        'https://example.com'
      )
    `);
  }
}
ensureSeedAd();

async function deleteAd(req, res, next) {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'DELETE FROM advertisements WHERE id = $1 RETURNING *',
      [id]
    );
    if (result.rowCount === 0) {
      return errorResponse(res, 404, 'Advertisement not found');
    }
    return successResponse(res, 200, null, 'Advertisement deleted successfully');
  } catch (error) {
    return next(error);
  }
}

async function recordAdView(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    // Only update if the user isn't already in the array
    const result = await pool.query(
      `UPDATE advertisements 
       SET views_count = views_count + 1, 
           viewed_by_users = array_append(viewed_by_users, $2)
       WHERE id = $1 AND NOT ($2 = ANY(viewed_by_users)) 
       RETURNING views_count`,
      [id, userId]
    );

    // If rowCount is 0, it either means ad not found OR user already viewed it.
    // We will just fetch the current count to return success in both cases without throwing error.
    if (result.rowCount === 0) {
      const checkAd = await pool.query('SELECT views_count FROM advertisements WHERE id = $1', [id]);
      if (checkAd.rowCount === 0) return errorResponse(res, 404, 'Advertisement not found');
      return successResponse(res, 200, checkAd.rows[0], 'Already viewed by this user');
    }
    return successResponse(res, 200, result.rows[0], 'View recorded');
  } catch (error) {
    return next(error);
  }
}

async function recordAdClick(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const result = await pool.query(
      `UPDATE advertisements 
       SET clicks_count = clicks_count + 1, 
           clicked_by_users = array_append(clicked_by_users, $2)
       WHERE id = $1 AND NOT ($2 = ANY(clicked_by_users)) 
       RETURNING clicks_count`,
      [id, userId]
    );

    if (result.rowCount === 0) {
      const checkAd = await pool.query('SELECT clicks_count FROM advertisements WHERE id = $1', [id]);
      if (checkAd.rowCount === 0) return errorResponse(res, 404, 'Advertisement not found');
      return successResponse(res, 200, checkAd.rows[0], 'Already clicked by this user');
    }
    return successResponse(res, 200, result.rows[0], 'Click recorded');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getActiveAds,
  getAllAds,
  createAd,
  deleteAd,
  recordAdView,
  recordAdClick,
};
