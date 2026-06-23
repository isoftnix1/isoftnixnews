const jwt = require('jsonwebtoken');
const { successResponse, errorResponse } = require('../utils/responseHandler');

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return errorResponse(res, 401, 'Access token is required');
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    return next();
  } catch (error) {
    return errorResponse(res, 401, 'Invalid or expired token');
  }
}

module.exports = authMiddleware;
