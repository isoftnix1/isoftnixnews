const NodeCache = require('node-cache');

// Standard TTL is 10 minutes (600 seconds)
// checkperiod checks for expired keys every 2 minutes (120 seconds)
const cache = new NodeCache({ stdTTL: 600, checkperiod: 120 });

/**
 * Get a value from the cache
 */
function getCache(key) {
  const value = cache.get(key);
  if (value) {
    console.log(`\n[CACHE] ⚡ HIT: Loaded instantly from memory -> ${key}`);
  } else {
    console.log(`\n[CACHE] 🐢 MISS: Fetching from database -> ${key}`);
  }
  return value;
}

/**
 * Set a value in the cache
 * @param {string} key Cache key
 * @param {any} val Value to cache
 * @param {number} [ttl] Optional TTL in seconds (overrides stdTTL)
 */
function setCache(key, val, ttl) {
  if (ttl !== undefined) {
    cache.set(key, val, ttl);
  } else {
    cache.set(key, val);
  }
  console.log(`[CACHE] 💾 SAVED to memory -> ${key}\n`);
}

/**
 * Delete a specific key
 */
function deleteCache(key) {
  cache.del(key);
}

/**
 * Delete all keys that start with a specific pattern/prefix
 * This is extremely useful for invalidating all paginated news queries when a new article is added.
 */
function deletePattern(prefix) {
  const keys = cache.keys();
  const keysToDelete = keys.filter(key => key.startsWith(prefix));
  if (keysToDelete.length > 0) {
    cache.del(keysToDelete);
    console.log(`[CACHE] Invalidated ${keysToDelete.length} keys starting with "${prefix}"`);
  }
}

/**
 * Clear the entire cache
 */
function clearAllCache() {
  cache.flushAll();
  console.log('[CACHE] Flushed all keys');
}

module.exports = {
  getCache,
  setCache,
  deleteCache,
  deletePattern,
  clearAllCache,
};
