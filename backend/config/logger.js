/**
 * Lightweight logger — tanpa dependency baru.
 * Development: debug boleh. Production: hanya info penting + error.
 */

const isProduction = () =>
  String(process.env.NODE_ENV || '').toLowerCase() === 'production';

function debug(...args) {
  if (!isProduction()) {
    console.log(...args);
  }
}

function info(...args) {
  console.log(...args);
}

function error(...args) {
  console.error(...args);
}

module.exports = {
  isProduction,
  debug,
  info,
  error,
};
