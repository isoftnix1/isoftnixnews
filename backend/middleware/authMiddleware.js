const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { errorResponse } = require('../utils/responseHandler');

function extractBearerToken(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  return authHeader.split(' ')[1];
}

async function resolveUserFromToken(token) {
  const decoded = jwt.verify(token, process.env.JWT_SECRET, {
    algorithms: ['HS256'],
  });

  const userId = decoded.sub || decoded.id;
  const user = await User.findAuthUserById(userId);
  if (!user) {
    return null;
  }

  if (!user.is_active) {
    return { inactive: true };
  }

  return {
    id: user.id,
    email: user.email,
    role: user.role,
  };
}

async function authMiddleware(req, res, next) {
  const token = extractBearerToken(req);

  if (!token) {
    return errorResponse(res, 401, 'Access token is required');
  }

  try {
    const user = await resolveUserFromToken(token);
    if (!user) {
      return errorResponse(res, 401, 'Invalid or expired token');
    }
    if (user.inactive) {
      return errorResponse(res, 403, 'Account is deactivated');
    }

    req.user = user;
    return next();
  } catch (error) {
    return errorResponse(res, 401, 'Invalid or expired token');
  }
}

/**
 * Optionally attaches req.user when a valid Bearer token is present.
 * Invalid or missing tokens do not block public routes.
 */
async function optionalAuthMiddleware(req, res, next) {
  const token = extractBearerToken(req);

  if (!token) {
    return next();
  }

  try {
    const user = await resolveUserFromToken(token);
    if (user && !user.inactive) {
      req.user = user;
    }
  } catch (error) {
    // Treat invalid optional tokens as anonymous access on public routes.
  }

  return next();
}

function roleMiddleware(allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return errorResponse(res, 403, 'You do not have permission to perform this action');
    }
    next();
  };
}

module.exports = {
  authMiddleware,
  optionalAuthMiddleware,
  roleMiddleware,
};
