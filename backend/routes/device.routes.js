const express = require('express');
const deviceController = require('../controllers/device.controller');

const router = express.Router();

// Urutan penting: /device/heartbeat sebelum /device/:deviceId
router.post('/device/heartbeat', deviceController.postHeartbeat);
router.get('/devices', deviceController.getDevices);
router.get('/device/:deviceId', deviceController.getDevice);

module.exports = router;
