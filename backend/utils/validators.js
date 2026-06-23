function isNonEmpty(value) {
  if (typeof value !== 'string') return false;
  return value.trim().length > 0;
}

function isEmail(value) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function validateRegisterInput({ name, email, password }) {
  if (!isNonEmpty(name)) return 'Name is required';
  if (!isEmail(email)) return 'Valid email is required';
  
  const strongPasswordRegex = /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$/;
  if (!password || !strongPasswordRegex.test(password)) {
    return 'Password must be at least 8 characters long and contain at least one letter and one number';
  }
  return null;
}

function validateLoginInput({ email, password }) {
  if (!isEmail(email)) return 'Valid email is required';
  if (!isNonEmpty(password)) return 'Password is required';
  return null;
}

function validateNewsInput({ title, content, categoryId }) {
  if (!isNonEmpty(title)) return 'Title is required';
  if (!isNonEmpty(content)) return 'Content is required';
  if (!isNonEmpty(categoryId)) return 'Category is required';
  return null;
}

module.exports = {
  validateRegisterInput,
  validateLoginInput,
  validateNewsInput,
};
