const express = require('express');
const debugController = require('../controllers/debug.controller');

const router = express.Router();

// Endpoint khusus debugging / pengujian E2E (tidak mengubah API utama)
router.get('/debug/device/:deviceId', debugController.getDebugDevice);
router.get('/debug/history', debugController.getDebugHistory);

module.exports = router;
