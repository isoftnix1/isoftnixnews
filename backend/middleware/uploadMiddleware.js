const multer = require('multer');
const path = require('path');

const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: {
    fileSize: 50 * 1024 * 1024,
  },
  fileFilter: (req, file, cb) => {
    const allowedImageTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'application/octet-stream'];
    const allowedVideoTypes = ['video/mp4', 'video/mov', 'video/webm'];

    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExts = ['.jpg', '.jpeg', '.png', '.webp', '.mp4', '.mov', '.webm'];

    if (
      (allowedImageTypes.includes(file.mimetype) ||
      allowedVideoTypes.includes(file.mimetype)) &&
      allowedExts.includes(ext)
    ) {
      return cb(null, true);
    }

    cb(new Error('Invalid file type. Only standard images and videos are allowed.'));
  },
});

module.exports = upload;
