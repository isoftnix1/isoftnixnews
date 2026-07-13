const { errorResponse } = require('../utils/responseHandler');

function notFoundMiddleware(req, res, next) {
  return errorResponse(res, 404, `Route not found: ${req.originalUrl}`);
}

function errorMiddleware(err, req, res, next) {
  // Always log the full error (with stack trace) to the server console.
  // This ensures developers can always debug issues from server logs.
  console.error(err.stack || err);

  const status = err.status || 500;
  const isDev = process.env.NODE_ENV !== 'production';

  // In production, never expose raw library/database error messages for 5xx errors.
  // These can leak internal schema details (e.g. table names, column names, DB ports).
  // For 4xx client errors, the message is safe to show (it was written by us intentionally).
  // In development, always show the full message for easy debugging.
  const message = status < 500
    ? (err.message || 'Request error')
    : (isDev ? (err.message || 'Something went wrong') : 'An internal server error occurred. Please try again later.');

  return errorResponse(res, status, message);
}

module.exports = {
  notFoundMiddleware,
  errorMiddleware,
};
