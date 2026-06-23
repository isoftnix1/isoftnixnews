const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { validateRegisterInput, validateLoginInput } = require('../utils/validators');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const User = require('../models/User');

function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role, // This ensures the role is encoded in the JWT
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

async function register(req, res, next) {
  try {
    const validationError = validateRegisterInput(req.body);
    if (validationError) return errorResponse(res, 400, validationError);

    const existingUser = await User.findByEmail(req.body.email);
    if (existingUser) return errorResponse(res, 409, 'Email already registered');

    const passwordHash = await bcrypt.hash(req.body.password, 10);

    // Ensure role is handled correctly (defaulting to 'user' unless specified)
    const user = await User.createUser({
      name: req.body.name,
      email: req.body.email,
      phone: req.body.phone || null,
      passwordHash,
      role: req.body.role || 'user',
    });

    const token = generateToken(user);

    // Return the user object including the role so the frontend can redirect immediately
    return successResponse(res, 201, {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      },
      token
    }, 'User registered successfully');
  } catch (error) {
    return next(error);
  }
}

async function login(req, res, next) {
  try {
    const validationError = validateLoginInput(req.body);
    if (validationError) {
      return errorResponse(res, 400, validationError);
    }

    const user = await User.findByEmail(req.body.email);
    if (!user) {
      return errorResponse(res, 401, 'Invalid email or password');
    }

    const isPasswordValid = await bcrypt.compare(req.body.password, user.password_hash);
    if (!isPasswordValid) {
      return errorResponse(res, 401, 'Invalid email or password');
    }

    const token = generateToken(user);

    // CRITICAL: The frontend uses this 'role' property to decide where to navigate
    return successResponse(res, 200, {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role // 'admin' or 'user'
      },
      token
    }, 'Login successful');
  } catch (error) {
    console.error(`[Login Error] Internal server error:`, error);
    return next(error);
  }
}

async function getProfile(req, res, next) {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return errorResponse(res, 404, 'User not found');
    return successResponse(res, 200, { user }, 'Profile retrieved successfully');
  } catch (error) {
    return next(error);
  }
}

async function updateProfile(req, res, next) {
  try {
    const updates = {};
    if (req.body.name) updates.name = req.body.name;
    if (req.body.phone) updates.phone = req.body.phone;
    if (req.body.password) {
      updates.password_hash = await bcrypt.hash(req.body.password, 10);
    }

    if (Object.keys(updates).length === 0) {
      return errorResponse(res, 400, 'No update fields provided');
    }

    const updatedUser = await User.updateUser(req.user.id, updates);
    if (!updatedUser) return errorResponse(res, 404, 'User not found');

    return successResponse(res, 200, { user: updatedUser }, 'Profile updated successfully');
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  register,
  login,
  getProfile,
  updateProfile,
};