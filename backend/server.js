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
const { notFoundMiddleware, errorMiddleware } = require('./middleware/errorMiddleware');
const { initScheduler } = require('./services/reminderScheduler');
const { initCleanupScheduler } = require('./services/cleanupService');

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

const adminRoutes = require('./routes/adminRoutes');
app.use('/api/admin', adminApiLimiter, adminRoutes);

const analyticsRoutes = require('./routes/analyticsRoutes');
app.use('/api/analytics', analyticsRoutes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

async function startServer() {
  try {
    await initializeDatabase();
    
    // Initialize scheduled tasks
    if (process.env.NODE_ENV !== 'test') {
      initScheduler();
      initCleanupScheduler();
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
