const express = require('express');
const statusController = require('../controllers/status.controller');

const router = express.Router();

router.get('/status', statusController.getStatus);

// Alias kompatibilitas health check lama
router.get('/health', statusController.getStatus);

module.exports = router;
