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
const { notFoundMiddleware, errorMiddleware } = require('./middleware/errorMiddleware');

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

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { message: 'Too many login attempts from this IP, please try again after 15 minutes' },
  standardHeaders: true,
  legacyHeaders: false,
});

const passwordResetLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 3,
  message: { message: 'Too many password reset attempts from this IP, please try again after 15 minutes' },
  standardHeaders: true,
  legacyHeaders: false,
});

const verifyOtpLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { message: 'Too many verification attempts from this IP, please try again after 15 minutes' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(helmet());
app.use(cors(corsOptions));
app.use(limiter);
app.use(morgan(isDev ? 'dev' : 'combined'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

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
app.use('/api/auth/register', loginLimiter);
app.use('/api/auth/forgot-password', passwordResetLimiter);
app.use('/api/auth/verify-reset-otp', verifyOtpLimiter);
app.use('/api/auth/reset-password', verifyOtpLimiter);
app.use('/api/auth', authRoutes);
app.use('/api/news', newsRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/notifications', notificationRoutes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

async function startServer() {
  try {
    await initializeDatabase();
    
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
