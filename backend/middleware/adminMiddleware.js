const { errorResponse } = require('../utils/responseHandler');

function adminMiddleware(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return errorResponse(res, 403, 'Admin access required');
  }

  return next();
}

module.exports = adminMiddleware;
