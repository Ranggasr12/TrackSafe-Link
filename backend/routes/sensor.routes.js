const express = require('express');
const sensorController = require('../controllers/sensor.controller');

const router = express.Router();

// Endpoint spek utama ESP32
router.post('/sensor', sensorController.postSensor);

// Alias kompatibilitas firmware lama
router.post('/telemetry', sensorController.postSensor);
router.post('/data', sensorController.postSensor);

// GET /device/:deviceId dipindah ke device.routes (respons diperkaya, backward compatible).
router.get('/history', sensorController.getHistory);

module.exports = router;
