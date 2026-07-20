/**
 * Retry helper for transient Firebase write failures.
 */

const logger = require('../config/logger');

/**
 * @param {() => Promise<T>} fn
 * @param {{ retries?: number, label?: string }} [options]
 * @returns {Promise<T>}
 */
async function withFirebaseRetry(fn, options = {}) {
  const retries = options.retries ?? 3;
  const label = options.label || 'write';

  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const result = await fn();
      logger.info(`[firebase] Firebase Write Success (${label})`);
      return result;
    } catch (error) {
      const isLast = attempt >= retries;
      if (isLast) {
        logger.error(`[firebase] Firebase Write Failed (${label}):`, error.message);
        throw error;
      }
      const delayMs = 1000 * attempt;
      logger.info(
        `[firebase] Retry Firebase (${label}) attempt ${attempt}/${retries} in ${delayMs}ms`,
      );
      await new Promise((resolve) => { setTimeout(resolve, delayMs); });
    }
  }

  throw new Error('Firebase retry exhausted');
}

module.exports = { withFirebaseRetry };
