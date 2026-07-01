/**
 * validateFileType.js
 *
 * Inspects actual file bytes (magic numbers / file signatures) using `file-type`.
 * This prevents renamed/spoofed files (e.g. virus.exe -> virus.jpg) from passing
 * MIME-type and extension checks alone.
 *
 * Returns null if the file is valid, or a descriptive error string if invalid.
 */
const fileType = require('file-type');

// Maps each fieldname to the real MIME types we accept from file-type detection
const VALID_SIGNATURES = {
  image: new Set(['image/jpeg', 'image/png', 'image/webp']),
  video: new Set(['video/mp4', 'video/quicktime', 'video/webm']),
};

/**
 * @param {import('multer').File} file - Multer file object with a .buffer property.
 * @returns {Promise<string|null>} Error message string, or null if file is valid.
 */
async function validateFileSignature(file) {
  if (!file || !file.buffer || file.buffer.length === 0) {
    return 'Uploaded file is empty or unreadable';
  }

  let detected;
  try {
    detected = await fileType.fromBuffer(file.buffer);
  } catch {
    return 'Could not read file signature';
  }

  const validSet = VALID_SIGNATURES[file.fieldname];

  // If file-type cannot detect a known signature, reject it
  if (!detected) {
    return `File "${file.originalname}" has an unrecognised format. Only jpeg, png, webp images and mp4, mov, webm videos are accepted`;
  }

  // If the detected real type is not in the allowed set for this field, reject
  if (!validSet || !validSet.has(detected.mime)) {
    return `File "${file.originalname}" appears to be "${detected.mime}" but was uploaded as ${file.fieldname}. Upload rejected`;
  }

  return null; // valid
}

module.exports = { validateFileSignature };
