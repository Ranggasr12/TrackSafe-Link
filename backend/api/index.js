/**
 * Vercel Serverless Function entrypoint.
 *
 * WAJIB:
 * - module.exports = app  (Express request listener)
 * - Jangan panggil app.listen()
 */

try {
  const app = require('../app');

  if (typeof app !== 'function') {
    console.error('[api/index] Express export error: app is not a function');
    throw new Error('Express app export invalid — expected a function');
  }

  module.exports = app;
} catch (error) {
  // Fallback agar Vercel menampilkan error JSON, bukan crash mentah
  console.error('[api/index] MODULE_NOT_FOUND / boot error:', error.message);
  module.exports = (req, res) => {
    res.statusCode = 500;
    res.setHeader('Content-Type', 'application/json');
    res.end(
      JSON.stringify({
        success: false,
        error: 'Function Invocation Failed',
        detail: error.message,
      }),
    );
  };
}
