const cloudinary = require('../config/cloudinary');

async function uploadToCloudinary(file, folder = 'news') {
  if (!file) return null;

  const result = await new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        resource_type: 'auto',
      },
      (error, uploaded) => {
        if (error) return reject(error);
        resolve(uploaded);
      }
    );

    stream.end(file.buffer);
  });

  return result;
}

async function deleteFromCloudinary(publicId, resourceType = 'image') {
  if (!publicId) return;
  await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
}

/**
 * Extracts the Cloudinary public_id from a secure_url.
 * Example input:  https://res.cloudinary.com/djnzq0i1v/image/upload/v1234/news/images/abc123.jpg
 * Example output: news/images/abc123
 * Returns null if the URL is not a valid Cloudinary URL.
 */
function extractCloudinaryPublicId(url) {
  if (!url || typeof url !== 'string') return null;
  try {
    // Match the path after /upload/v<version>/
    const match = url.match(/\/upload\/(?:v\d+\/)?(.+?)(\.[^.]+)?$/);
    if (!match) return null;
    return match[1]; // e.g. news/images/abc123
  } catch {
    return null;
  }
}

module.exports = {
  uploadToCloudinary,
  deleteFromCloudinary,
  extractCloudinaryPublicId,
};
