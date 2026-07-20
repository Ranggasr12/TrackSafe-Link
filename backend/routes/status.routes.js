const express = require('express');
const statusController = require('../controllers/status.controller');

const router = express.Router();

router.get('/status', statusController.getStatus);
router.get('/health', statusController.getHealth);

module.exports = router;
