/**
 * TrackSafe Backend — Railway production entry point.
 * Express REST API + MQTT HiveMQ subscriber dalam satu proses persistent.
 *
 * Usage:
 *   npm start          # Railway / production
 *   npm run dev        # local development (same process)
 */

require('dotenv').config();

const app = require('./app');
const mqttService = require('./services/mqtt.service');
const logger = require('./config/logger');
const { initFirebase } = require('./config/firebase');

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '0.0.0.0';

function gracefulShutdown(signal) {
  logger.info(`[server] ${signal} — shutting down gracefully`);
  mqttService.stopMqtt();
  process.exit(0);
}

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

process.on('uncaughtException', (err) => {
  logger.error('[server] uncaughtException:', err.message);
});

process.on('unhandledRejection', (reason) => {
  logger.error('[server] unhandledRejection:', reason);
});

function bootstrap() {
  try {
    initFirebase();
    logger.info('[server] Firebase initialized');
  } catch (error) {
    logger.error('[server] Firebase init failed (retries on first request):', error.message);
  }

  app.listen(PORT, HOST, () => {
    logger.info(`[server] Express Started — http://${HOST}:${PORT}`);

    const mqtt = mqttService.startMqtt();
    if (mqtt.enabled) {
      logger.info('[server] MQTT subscriber enabled — connecting to HiveMQ');
    } else {
      logger.info('[server] MQTT subscriber disabled (MQTT_ENABLED=false)');
    }

    logger.info('[server] Backend Ready');
  });
}

bootstrap();
