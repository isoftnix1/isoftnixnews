const { errorResponse } = require('../utils/responseHandler');

function notFoundMiddleware(req, res, next) {
  return errorResponse(res, 404, `Route not found: ${req.originalUrl}`);
}

function errorMiddleware(err, req, res, next) {
  console.error(err.stack || err);

  const status = err.status || 500;
  const message = err.message || 'Something went wrong';

  return errorResponse(res, status, message);
}

module.exports = {
  notFoundMiddleware,
  errorMiddleware,
};
