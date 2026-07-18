/**
 * Firebase Admin — single initialization for Vercel Serverless.
 * Credentials HANYA dari environment variables (bukan serviceAccount.json).
 */

const admin = require('firebase-admin');
const logger = require('./logger');

let db = null;

function getRequiredEnv(name) {
  const value = process.env[name];
  if (value === undefined || value === null || String(value).trim() === '') {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return String(value);
}

/**
 * Normalisasi FIREBASE_PRIVATE_KEY dari Vercel / .env.
 * Menangani: quote wrapping, literal \n, CRLF.
 */
function sanitizePrivateKey(raw) {
  let key = String(raw).trim();

  if (
    (key.startsWith('"') && key.endsWith('"')) ||
    (key.startsWith("'") && key.endsWith("'"))
  ) {
    key = key.slice(1, -1);
  }

  key = key.replace(/\\n/g, '\n').replace(/\r\n/g, '\n').trim();

  if (!key.includes('BEGIN PRIVATE KEY') && !key.includes('BEGIN RSA PRIVATE KEY')) {
    throw new Error(
      'Invalid FIREBASE_PRIVATE_KEY: expected PEM private key (BEGIN PRIVATE KEY)',
    );
  }

  return key;
}

/**
 * Initialize Firebase once (safe across warm serverless invocations).
 * Gagal transient di-retry pada request berikutnya (tidak sticky permanen).
 * @returns {admin.database.Database}
 */
function initFirebase() {
  if (db) return db;

  try {
    const projectId = getRequiredEnv('FIREBASE_PROJECT_ID').trim();
    const clientEmail = getRequiredEnv('FIREBASE_CLIENT_EMAIL').trim();
    const privateKey = sanitizePrivateKey(getRequiredEnv('FIREBASE_PRIVATE_KEY'));
    const databaseURL = getRequiredEnv('FIREBASE_DATABASE_URL').trim();

    if (!databaseURL.startsWith('https://') || !databaseURL.includes('firebaseio.com')) {
      // asia-southeast1 uses firebasedatabase.app — terima keduanya
      if (!databaseURL.includes('firebasedatabase.app') && !databaseURL.includes('firebaseio.com')) {
        throw new Error(
          'Invalid FIREBASE_DATABASE_URL: must be a Firebase Realtime Database URL',
        );
      }
    }

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
        databaseURL,
      });
      logger.info('[firebase] initialized for project:', projectId);
    }

    db = admin.database();
    return db;
  } catch (error) {
    db = null;
    logger.error('[firebase] init failed:', error.message);
    throw error;
  }
}

/**
 * @returns {admin.database.Database}
 */
function getDatabase() {
  return initFirebase();
}

function isFirebaseReady() {
  try {
    initFirebase();
    return true;
  } catch (_) {
    return false;
  }
}

module.exports = {
  admin,
  initFirebase,
  getDatabase,
  isFirebaseReady,
  sanitizePrivateKey,
};
