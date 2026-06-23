function validateEnv() {
  const required = [
    'JWT_SECRET',
    'DATABASE_URL',
    'CLOUDINARY_CLOUD_NAME',
    'CLOUDINARY_API_KEY',
    'CLOUDINARY_API_SECRET'
  ];

  const missing = required.filter(key => !process.env[key]);
  if (missing.length > 0) {
    console.error(`❌ FATAL ERROR: Missing required environment variables: ${missing.join(', ')}`);
    process.exit(1);
  }
}

module.exports = validateEnv;
