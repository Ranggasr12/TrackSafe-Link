const express = require('express');
const deviceController = require('../controllers/device.controller');

const router = express.Router();

// Device management
router.post('/device/register', deviceController.postRegister);
router.post('/device/heartbeat', deviceController.postHeartbeat);
router.post('/device/pair', deviceController.postPair);
router.post('/device/unpair', deviceController.postUnpair);
router.post('/device/location', deviceController.postLocation);
router.post('/device/status', deviceController.postStatus);
router.get('/device/pairing/:deviceId', deviceController.getPairing);
router.get('/device/list', deviceController.getDevices);
router.get('/devices', deviceController.getDevices);
router.get('/device/:deviceId', deviceController.getDevice);

// Backend & History
router.get('/backend/status', deviceController.getBackendStatus);
router.get('/history', deviceController.getHistory);
router.get('/backend/history', deviceController.getHistory);

module.exports = router;