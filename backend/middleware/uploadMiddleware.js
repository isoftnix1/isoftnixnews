const multer = require('multer');
const path = require('path');

// ─── Limits ────────────────────────────────────────────────────────────────
const IMAGE_SIZE_LIMIT = 5 * 1024 * 1024;   // 5 MB
const VIDEO_SIZE_LIMIT = 100 * 1024 * 1024; // 100 MB

// ─── Allowlists ─────────────────────────────────────────────────────────────
const ALLOWED_IMAGE_MIMES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
]);

const ALLOWED_VIDEO_MIMES = new Set([
  'video/mp4',
  'video/quicktime', // .mov
  'video/webm',
]);

const ALLOWED_IMAGE_EXTS = new Set(['.jpg', '.jpeg', '.png', '.webp']);
const ALLOWED_VIDEO_EXTS = new Set(['.mp4', '.mov', '.webm']);

// ─── Storage ─────────────────────────────────────────────────────────────────
const storage = multer.memoryStorage();

// ─── File filter ─────────────────────────────────────────────────────────────
function fileFilter(req, file, cb) {
  const ext = path.extname(file.originalname).toLowerCase();
  const isImageField = file.fieldname === 'image';
  const isVideoField = file.fieldname === 'video';

  // Some clients (e.g. Flutter http/dio) send files as application/octet-stream.
  // In that case, fall back to extension-based MIME detection.
  const isOctetStream = file.mimetype === 'application/octet-stream';

  if (isImageField) {
    if (!isOctetStream && !ALLOWED_IMAGE_MIMES.has(file.mimetype)) {
      return cb(
        Object.assign(
          new Error(`Invalid image type "${file.mimetype}". Allowed: jpeg, jpg, png, webp`),
          { status: 400 }
        )
      );
    }
    if (!ALLOWED_IMAGE_EXTS.has(ext)) {
      return cb(
        Object.assign(
          new Error(`Invalid image extension "${ext}". Allowed: .jpg, .jpeg, .png, .webp`),
          { status: 400 }
        )
      );
    }
    return cb(null, true);
  }

  if (isVideoField) {
    if (!isOctetStream && !ALLOWED_VIDEO_MIMES.has(file.mimetype)) {
      return cb(
        Object.assign(
          new Error(`Invalid video type "${file.mimetype}". Allowed: mp4, mov, webm`),
          { status: 400 }
        )
      );
    }
    if (!ALLOWED_VIDEO_EXTS.has(ext)) {
      return cb(
        Object.assign(
          new Error(`Invalid video extension "${ext}". Allowed: .mp4, .mov, .webm`),
          { status: 400 }
        )
      );
    }
    return cb(null, true);
  }

  // Unknown field name — reject
  return cb(
    Object.assign(new Error(`Unexpected upload field: "${file.fieldname}"`), { status: 400 })
  );
}

// ─── Multer instance ─────────────────────────────────────────────────────────
// limits.fileSize is set to the larger video cap.
// Image size is enforced in the newsController after the buffer is available.
const upload = multer({
  storage,
  limits: {
    fileSize: VIDEO_SIZE_LIMIT,
  },
  fileFilter,
});

// Export the per-type constants so the controller can enforce the image cap.
upload.IMAGE_SIZE_LIMIT = IMAGE_SIZE_LIMIT;
upload.VIDEO_SIZE_LIMIT = VIDEO_SIZE_LIMIT;

module.exports = upload;
