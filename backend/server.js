process.env.TZ = 'UTC'; // Force Node.js to operate in UTC to prevent timestamp shifting with PostgreSQL

require('dotenv').config();
const validateEnv = require('./utils/validateEnv');
validateEnv();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const { initializeDatabase } = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const newsRoutes = require('./routes/newsRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const schedulerRoutes = require('./routes/schedulerRoutes');
const deviceRoutes = require('./routes/deviceRoutes');
const adRoutes = require('./routes/adRoutes');
const { notFoundMiddleware, errorMiddleware } = require('./middleware/errorMiddleware');
const { initScheduler } = require('./services/reminderScheduler');
const { initCleanupScheduler } = require('./services/cleanupService');
const { initDraftScheduler } = require('./services/draftScheduler');
const { initCronJobs } = require('./cronJobs');

const isDev = process.env.NODE_ENV !== 'production';

// Build the allowed origins list
const configuredOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : [];

const devOrigins = [
  'http://localhost:3000',
  'http://localhost:5000',
  'http://localhost:8080',
];

const allowedOrigins = isDev
  ? [...new Set([...configuredOrigins, ...devOrigins])]
  : configuredOrigins;

if (!isDev && allowedOrigins.length === 0) {
  console.warn('[CORS] WARNING: ALLOWED_ORIGINS is not set in production mode. All origins will be blocked.');
}

const corsOptions = {
  origin: (origin, callback) => {
    // Allow non-browser requests (mobile apps, Postman, server-to-server) with no origin header
    if (!origin) return callback(null, true);

    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    console.warn(`[CORS REJECTED] Origin not allowed: ${origin}`);
    return callback(new Error(`CORS: Origin ${origin} is not allowed`), false);
  },
  credentials: true,
};

const app = express();
app.set('trust proxy', 1);
const PORT = process.env.PORT || 5000;

const {
  publicApiLimiter,
  loginLimiter,
  registerLimiter,
  forgotPasswordLimiter,
  otpLimiter,
  adminApiLimiter,
  refreshLimiter
} = require('./middleware/rateLimiters');

// 1. Security Headers (Helmet)
app.use(helmet());

// 2. CORS
app.use(cors(corsOptions));

// 3. Global Rate Limiter (Public APIs)
app.use(publicApiLimiter);

// Logging
app.use(morgan(isDev ? 'dev' : 'combined'));

// 4. Body Parsers (Strict Limits)
app.use(express.json({ limit: '20kb' }));
app.use(express.urlencoded({ extended: true, limit: '20kb' }));

// Middleware to log request timing
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[REQUEST_TIME] ${req.method} ${req.originalUrl} - ${duration}ms`);
  });
  next();
});

app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Updates API is running 🚀",
    version: "1.0.0",
  });
});
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Updates API is running' });
});

app.use('/api/auth/login', loginLimiter);
app.use('/api/auth/register', registerLimiter);
app.use('/api/auth/refresh', refreshLimiter);
app.use('/api/auth/forgot-password', forgotPasswordLimiter);
app.use('/api/auth/verify-reset-otp', otpLimiter);
app.use('/api/auth/reset-password', otpLimiter);

app.use('/api/auth', authRoutes);
app.use('/api/news', newsRoutes); // Public news endpoints
app.use('/api/categories', categoryRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/scheduler', adminApiLimiter, schedulerRoutes);
app.use('/api/device', deviceRoutes);
app.use('/api/ads', adRoutes);

const adminRoutes = require('./routes/adminRoutes');
app.use('/api/admin', adminApiLimiter, adminRoutes);

const analyticsRoutes = require('./routes/analyticsRoutes');
app.use('/api/analytics', analyticsRoutes);

const voiceRoutes = require('./routes/voiceRoutes');
app.use('/api/voice', voiceRoutes);

const chatRoutes = require('./routes/chatRoutes');
app.use('/api/chat', chatRoutes);

// --- APP LINKS VERIFICATION (ANDROID & IOS) ---
app.get('/.well-known/assetlinks.json', (req, res) => {
  res.json([{
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.isoftnix.updates",
      "sha256_cert_fingerprints": [
        process.env.ANDROID_SHA256 || "INSERT_YOUR_SHA256_HERE"
      ]
    }
  }]);
});

app.get('/.well-known/apple-app-site-association', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.json({
    "applinks": {
      "apps": [],
      "details": [
        {
          "appID": `${process.env.IOS_TEAM_ID || "INSERT_TEAM_ID"}.com.isoftnix.updates`,
          "paths": [ "/news/*" ]
        }
      ]
    }
  });
});

// Route for WhatsApp/Social Media Link Previews (Deep Linking)
app.get('/news/:id', async (req, res) => {
  try {
    const { pool } = require('./config/db');
    const result = await pool.query('SELECT title, image_url FROM news WHERE id = $1', [req.params.id]);
    
    if (result.rows.length === 0) return res.status(404).send('News not found');
    
    const news = result.rows[0];
    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Krrishi News</title>
        <meta property="og:title" content="${news.title.replace(/"/g, '&quot;')}" />
        <meta property="og:description" content="Read the full article on the Krrishi app" />
        <meta property="og:image" content="${news.image_url}" />
        <meta property="og:type" content="article" />
      </head>
      <body>
        <h2>${news.title}</h2>
        <p>To read this article, open the Krrishi App.</p>
        <script>
          // Attempt to open the app directly using custom URI scheme fallback
          window.location.href = "updates://news/${req.params.id}";
        </script>
      </body>
      </html>
    `;
    res.send(html);
  } catch (error) {
    res.status(500).send('Server Error');
  }
});

app.use(notFoundMiddleware);
app.use(errorMiddleware);

async function startServer() {
  try {
    await initializeDatabase();
    
    // Initialize scheduled tasks
    if (process.env.NODE_ENV !== 'test') {
      initScheduler();
      initCleanupScheduler();
      initDraftScheduler();
      initCronJobs();
    }
    
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
