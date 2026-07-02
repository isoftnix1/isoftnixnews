function isNonEmpty(value) {
  if (typeof value !== 'string') return false;
  return value.trim().length > 0;
}

const { isValidIndianMobile } = require('./phoneUtils');

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function validateRegisterInput({ name, email, password, phone }) {
  if (!isNonEmpty(name)) return 'Name is required';
  if (!isEmail(email)) return 'Valid email is required';

  if (!isValidIndianMobile(phone)) {
    return 'Enter a valid 10-digit Indian mobile number (starting with 6–9)';
  }
  
  const strongPasswordRegex = /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$/;
  if (!password || !strongPasswordRegex.test(password)) {
    return 'Password must be at least 8 characters and contain: an uppercase letter, a lowercase letter, a number, and a special character (@$!%*#?&)';
  }
  return null;
}

function validateLoginInput({ email, password }) {
  if (!isEmail(email)) return 'Valid email is required';
  if (!isNonEmpty(password)) return 'Password is required';
  return null;
}

function validateNewsInput({ title_en, content_en, title_hi, content_hi, title_mr, content_mr, categoryIds, source_name, source_url }) {
  if (!isNonEmpty(title_en)) return 'English title is required';
  if (!isNonEmpty(content_en)) return 'English content is required';
  if (!isNonEmpty(title_hi)) return 'Hindi title is required';
  if (!isNonEmpty(content_hi)) return 'Hindi content is required';
  if (!isNonEmpty(title_mr)) return 'Marathi title is required';
  if (!isNonEmpty(content_mr)) return 'Marathi content is required';
  
  if (!categoryIds || !Array.isArray(categoryIds) || categoryIds.length === 0) {
    return 'At least one category must be selected';
  }

  if (source_url && isNonEmpty(source_url)) {
    try {
      new URL(source_url);
    } catch (_) {
      return 'Valid source URL is required';
    }
    if (!isNonEmpty(source_name)) return 'Source name is required when source URL is provided';
  }

  if (source_name && isNonEmpty(source_name)) {
    if (!source_url || !isNonEmpty(source_url)) return 'Source URL is required when source name is provided';
  }

  return null;
}

module.exports = {
  validateRegisterInput,
  validateLoginInput,
  validateNewsInput,
};
