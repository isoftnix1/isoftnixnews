const INDIAN_MOBILE_PATTERN = /^[6-9]\d{9}$/;

function normalizeIndianPhone(value) {
  if (value == null || value === '') return null;

  let digits = String(value).trim().replace(/[\s\-()]/g, '');

  if (digits.startsWith('+91')) {
    digits = digits.slice(3);
  } else if (digits.startsWith('91') && digits.length === 12) {
    digits = digits.slice(2);
  } else if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.slice(1);
  }

  return digits;
}

function isValidIndianMobile(value) {
  const normalized = normalizeIndianPhone(value);
  return normalized != null && INDIAN_MOBILE_PATTERN.test(normalized);
}

module.exports = {
  INDIAN_MOBILE_PATTERN,
  normalizeIndianPhone,
  isValidIndianMobile,
};
