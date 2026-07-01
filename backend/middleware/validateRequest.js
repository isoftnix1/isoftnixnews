const { errorResponse } = require('../utils/responseHandler');

/**
 * Reusable Joi validation middleware factory.
 * @param {import('joi').ObjectSchema} schema - The Joi schema to validate against.
 * @param {'body'|'query'|'params'} property - Which part of the request to validate.
 */
function validate(schema, property = 'body') {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false,       // Return all errors, not just the first
      stripUnknown: true,      // Silently remove unknown fields
      allowUnknown: property === 'query', // Query strings often have extra fields
    });

    if (error) {
      const errors = error.details.map(d => d.message.replace(/['"]/g, ''));
      console.warn(`[VALIDATION FAILED] ${req.method} ${req.path} | errors: ${errors.join('; ')}`);
      return errorResponse(res, 400, 'Validation failed', errors);
    }

    // Replace req[property] with the sanitized/coerced value from Joi
    req[property] = value;
    return next();
  };
}

module.exports = validate;
