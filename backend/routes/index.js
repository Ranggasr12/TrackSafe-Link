const express = require('express');
const statusRoutes = require('./status.routes');
const sensorRoutes = require('./sensor.routes');
const debugRoutes = require('./debug.routes');

const router = express.Router();

router.use(statusRoutes);
router.use(sensorRoutes);
router.use(debugRoutes);

module.exports = router;
