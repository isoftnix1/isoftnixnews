const { pool } = require('../config/db');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const { uploadToCloudinary } = require('../services/cloudinaryService');

async function getActiveAds(req, res, next) {
  try {
    const result = await pool.query(
      'SELECT id, company_name, title, description, image_url, video_url, target_url, views_count, clicks_count FROM advertisements WHERE is_active = TRUE ORDER BY created_at DESC'
    );
    return successResponse(res, 200, result.rows, 'Active ads retrieved successfully');
  } catch (error) {
    return next(error);
  }
}

async function createAd(req, res, next) {
  try {
    const { company_name, title, description, target_url, is_active } = req.body;

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

    const result = await pool.query(
      `INSERT INTO advertisements (company_name, title, description, image_url, video_url, target_url, is_active) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [company_name, title, description || null, imageUrl, videoUrl, target_url, is_active !== undefined ? is_active : true]
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
    const result = await pool.query(
      'UPDATE advertisements SET views_count = views_count + 1 WHERE id = $1 RETURNING views_count',
      [id]
    );
    if (result.rowCount === 0) {
      return errorResponse(res, 404, 'Advertisement not found');
    }
    return successResponse(res, 200, result.rows[0], 'View recorded');
  } catch (error) {
    return next(error);
  }
}

async function recordAdClick(req, res, next) {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'UPDATE advertisements SET clicks_count = clicks_count + 1 WHERE id = $1 RETURNING clicks_count',
      [id]
    );
    if (result.rowCount === 0) {
      return errorResponse(res, 404, 'Advertisement not found');
    }
    return successResponse(res, 200, result.rows[0], 'Click recorded');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getActiveAds,
  createAd,
  deleteAd,
  recordAdView,
  recordAdClick,
};
