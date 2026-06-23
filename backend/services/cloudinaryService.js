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

module.exports = {
  uploadToCloudinary,
  deleteFromCloudinary,
};
