const express = require('express');
const statusRoutes = require('./status.routes');
const sensorRoutes = require('./sensor.routes');
const deviceRoutes = require('./device.routes');
const debugRoutes = require('./debug.routes');

const router = express.Router();

router.use(statusRoutes);
// Device routes sebelum sensor agar /device/heartbeat tidak tertangkap pola lain.
router.use(deviceRoutes);
router.use(sensorRoutes);
router.use(debugRoutes);

module.exports = router;
