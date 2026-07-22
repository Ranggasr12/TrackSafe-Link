# Graph Report - D:\app  (2026-07-22)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1160 nodes · 1559 edges · 66 communities (64 shown, 2 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 89 edges (avg confidence: 0.52)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `fc2778bc`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- dashboard_screen.dart
- device.service.js
- map_screen.dart
- constants.dart
- history_model.dart
- firebase_service.dart
- mqtt.service.js
- local_notification_service.dart
- system_labels.dart
- monitoring_model.dart
- scripts
- app_state_provider.dart
- alarm_audio_service.dart
- app_colors.dart
- device_pairing_provider.dart
- monitoring_provider.dart
- main.dart
- notification_listener_widget.dart
- manage_devices_screen.dart
- app.js
- mqtt.config.js
- monitoring_repository.dart
- pairing_model.dart
- settings_provider.dart
- device_pairing_screen.dart
- formatters.dart
- device.controller.js
- main_shell.dart
- device_monitor_card.dart
- firebase.js
- simulate-vercel.js
- State
- splash_screen.dart
- package:flutter/material.dart
- app_stage.dart
- routes/index.js
- history_screen.dart
- setting_screen.dart
- ../theme/app_colors.dart
- manifest.json
- status.controller.js
- sensor.controller.js
- StatelessWidget
- notification_service.dart
- sync-env-from-sa.js
- statistic_card.dart
- status_helper.dart
- statistics_screen.dart
- logger.js
- debug.controller.js
- simulate-mqtt.js
- vercel.json
- package:flutter/foundation.dart
- simulate-receiver.js
- utils/constants.dart
- ../models/monitoring_model.dart
- widget_test.dart
- simulate-gps.js
- simulate-devices.js
- backend_status_http_response.dart
- MainActivity
- backend_status_http_client_io.dart

## God Nodes (most connected - your core abstractions)
1. `getDatabase()` - 26 edges
2. `MonitoringProvider` - 15 edges
3. `DevicePairingProvider` - 14 edges
4. `scripts` - 12 edges
5. `initFirebase()` - 10 edges
6. `withFirebaseRetry()` - 9 edges
7. `error()` - 8 edges
8. `loadDevice()` - 8 edges
9. `routeMessage()` - 8 edges
10. `envInt()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `getDevice()` --indirect_call--> `error()`  [INFERRED]
  backend/controllers/sensor.controller.js → backend/config/logger.js
- `getHistory()` --indirect_call--> `error()`  [INFERRED]
  backend/controllers/sensor.controller.js → backend/config/logger.js
- `getDevice()` --indirect_call--> `error()`  [INFERRED]
  backend/controllers/device.controller.js → backend/config/logger.js
- `getDevices()` --indirect_call--> `error()`  [INFERRED]
  backend/controllers/device.controller.js → backend/config/logger.js
- `getHistory()` --indirect_call--> `error()`  [INFERRED]
  backend/controllers/device.controller.js → backend/config/logger.js

## Import Cycles
- None detected.

## Communities (66 total, 2 thin omitted)

### Community 0 - "dashboard_screen.dart"
Cohesion: 0.03
Nodes (68): backendLabel, _batteryDisplay, _blinkController, build, _clockTimer, createState, _currentTime, date (+60 more)

### Community 1 - "device.service.js"
Cohesion: 0.06
Nodes (48): getDatabase(), buildDeviceSummary(), deviceStatusEngine, getBackendStatus(), { getDatabase }, getDeviceDetail(), getPairingInfo(), historyService (+40 more)

### Community 2 - "map_screen.dart"
Cohesion: 0.04
Nodes (50): _appendTrackIfMoved, _blinkController, build, _buildInfoPanel, _colorForStatus, createState, _dateId, dispose (+42 more)

### Community 3 - "constants.dart"
Cohesion: 0.04
Nodes (50): acknowledgeReArmSec, AppConstants, appName, appTagline, backendBaseUrl, backendHealthUrl, backendHeartbeatFreshSec, backendStatusPath (+42 more)

### Community 4 - "history_model.dart"
Cohesion: 0.05
Nodes (41): backend_status_http_response.dart, Client, dart:convert, dart:io, ackTime, battery, dateLabel, description (+33 more)

### Community 5 - "firebase_service.dart"
Cohesion: 0.05
Nodes (41): dart:async, FirebaseDatabase?, backendOnline, BackendStatusResult, BackendStatusService, check, configured, dispose (+33 more)

### Community 6 - "mqtt.service.js"
Cohesion: 0.09
Nodes (37): alarmService, connectInternal(), deviceService, deviceStatusEngine, ensureHeartbeat(), { getDatabase, initFirebase }, getMqttHealthLabel(), getMqttStatus() (+29 more)

### Community 7 - "local_notification_service.dart"
Cohesion: 0.05
Nodes (36): alarm_audio_service.dart, AlarmAudioService, cancelAll, channelCritical, _channelDescription, _channelId, _channelName, channelOffline (+28 more)

### Community 8 - "system_labels.dart"
Cohesion: 0.05
Nodes (36): DeviceLinkStatus, DeviceLinkStatusLabel, DeviceLinkStatusResolver, fromBackend, gpsFixFromCoords, hasCoreTelemetry, hasHeartbeat, isFresh (+28 more)

### Community 9 - "monitoring_model.dart"
Cohesion: 0.06
Nodes (34): DateTime get, double?, alarm, battery, connectionStatus, copyWith, dateTime, deviceId (+26 more)

### Community 10 - "scripts"
Cohesion: 0.06
Nodes (33): dependencies, cors, dotenv, express, firebase-admin, mqtt, description, devDependencies (+25 more)

### Community 11 - "app_state_provider.dart"
Cohesion: 0.06
Nodes (33): attachRepository, _backendLabel, backendOnline, _backendStatusSubscription, batteryLabel, dispose, _ensureFirebaseReady, firebaseConnected (+25 more)

### Community 12 - "alarm_audio_service.dart"
Cohesion: 0.07
Nodes (27): AlarmAudioKind? get, AudioPlayer?, AlarmAudioKind, _criticalAsset, _doInitialize, initialize, _initialized, _installWebUnlockListener (+19 more)

### Community 13 - "app_colors.dart"
Cohesion: 0.07
Nodes (26): acknowledged, AppColors, background, cardDark, danger, dangerSoft, neutral, noise (+18 more)

### Community 14 - "device_pairing_provider.dart"
Cohesion: 0.08
Nodes (24): _backendApi, _busy, clearPairing, DevicePairResult, dispose, _ensureFirebase, _errorMessage, _firebase (+16 more)

### Community 15 - "monitoring_provider.dart"
Cohesion: 0.08
Nodes (24): displayBattery, displayDistance, displaySignal, dispose, _errorMessage, _hasValidData, initialize, _isInitialized (+16 more)

### Community 16 - "main.dart"
Cohesion: 0.08
Nodes (23): firebase_options.dart, appState, appStateProvider, build, devicePairingProvider, firebaseService, initializeApp, initializeDateFormatting (+15 more)

### Community 17 - "notification_listener_widget.dart"
Cohesion: 0.11
Nodes (20): SettingsProvider, build, child, createState, didChangeAppLifecycleState, dispose, _evaluate, initState (+12 more)

### Community 18 - "manage_devices_screen.dart"
Cohesion: 0.12
Nodes (17): ChangeNotifier, device_pairing_screen.dart, AppStateProvider, DevicePairingProvider, initState, initState, build, _gantiDevice (+9 more)

### Community 19 - "app.js"
Cohesion: 0.13
Nodes (12): apiRoutes, app, cors, { errorHandler }, express, { initFirebase }, { notFoundHandler }, statusController (+4 more)

### Community 20 - "mqtt.config.js"
Cohesion: 0.26
Nodes (16): buildBrokerUrl(), buildClientOptions(), envBool(), envInt(), envString(), getQos(), getSubscribePattern(), getTopicRoot() (+8 more)

### Community 21 - "monitoring_repository.dart"
Cohesion: 0.12
Nodes (16): MonitoringModel, _cachedMonitoring, connect, dispose, _ensureConnected, _firebaseService, getCurrentMonitoring, isConnected (+8 more)

### Community 22 - "pairing_model.dart"
Cohesion: 0.12
Nodes (15): bool?, fromMap, id, paired, PairingModel, _parseInt, receiverBattery, receiverId (+7 more)

### Community 23 - "settings_provider.dart"
Cohesion: 0.12
Nodes (15): bool get, double get, _alarmVolume, _darkMode, isLoaded, load, _loaded, _notificationEnabled (+7 more)

### Community 24 - "device_pairing_screen.dart"
Cohesion: 0.15
Nodes (15): MonitoringProvider, didChangeDependencies, allowBack, build, createState, DevicePairingScreen, _DevicePairingScreenState, dispose (+7 more)

### Community 25 - "formatters.dart"
Cohesion: 0.12
Nodes (15): battery, _chartDay, _date, _dateTime, distance, Formatters, fromTimestamp, noDataLabel (+7 more)

### Community 26 - "device.controller.js"
Cohesion: 0.16
Nodes (7): error(), deviceService, getDevice(), getDevices(), getHistory(), getPairing(), logger

### Community 27 - "main_shell.dart"
Cohesion: 0.14
Nodes (14): dashboard_screen.dart, build, createState, _index, MainShell, _MainShellState, _pages, _splashDone (+6 more)

### Community 28 - "device_monitor_card.dart"
Cohesion: 0.14
Nodes (13): batteryLabel, build, DeviceMonitorCard, gpsFixLabel, icon, label, lastUpdateLabel, leadingIcon (+5 more)

### Community 29 - "firebase.js"
Cohesion: 0.21
Nodes (10): admin, getRequiredEnv(), initFirebase(), logger, sanitizePrivateKey(), app, bootstrap(), { initFirebase } (+2 more)

### Community 30 - "simulate-vercel.js"
Cohesion: 0.27
Nodes (12): checkFile(), fail(), fs, http, invoke(), main(), ok(), path (+4 more)

### Community 31 - "State"
Cohesion: 0.23
Nodes (13): DashboardScreen, _DashboardScreenState, _MapCard, _MapCardState, AppBootstrap, _AppBootstrapState, MapScreen, _MapScreenState (+5 more)

### Community 32 - "splash_screen.dart"
Cohesion: 0.17
Nodes (11): Animation, AnimationController, build, _controller, createState, dispose, _fade, initState (+3 more)

### Community 33 - "package:flutter/material.dart"
Cohesion: 0.17
Nodes (10): app_colors.dart, AppTheme, dark, light, build, isAcknowledged, status, StatusCard (+2 more)

### Community 34 - "app_stage.dart"
Cohesion: 0.17
Nodes (11): alarmEnabled, AppStage, backendEnabled, backendHealthCheckEnabled, current, esp32Expected, firebaseEnabled, localNotificationEnabled (+3 more)

### Community 35 - "routes/index.js"
Cohesion: 0.18
Nodes (9): deviceController, express, router, debugRoutes, deviceRoutes, express, router, sensorRoutes (+1 more)

### Community 36 - "history_screen.dart"
Cohesion: 0.18
Nodes (10): HistoryModel, build, _eventColor, _eventIcon, filterAlarmOnly, HistoryScreen, icon, item (+2 more)

### Community 37 - "setting_screen.dart"
Cohesion: 0.18
Nodes (10): build, _Card, children, SettingScreen, List, manage_devices_screen.dart, MaterialPageRoute, package:provider/provider.dart (+2 more)

### Community 38 - "../theme/app_colors.dart"
Cohesion: 0.22
Nodes (9): BatteryCard, build, percent, build, signal, SignalCard, int?, ../theme/app_colors.dart (+1 more)

### Community 39 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 40 - "status.controller.js"
Cohesion: 0.24
Nodes (8): isFirebaseReady(), getHealth(), getStatus(), { isFirebaseReady }, telemetryService, express, router, statusController

### Community 41 - "sensor.controller.js"
Cohesion: 0.20
Nodes (7): getDevice(), getHistory(), logger, telemetryService, express, router, sensorController

### Community 42 - "StatelessWidget"
Cohesion: 0.20
Nodes (10): TrackSafeApp, _AlarmHistoryCard, _DeviceInfoCard, _HeaderCard, _KondisiCard, _QuickStatsCard, _StatusCard, _HistoryTile (+2 more)

### Community 43 - "notification_service.dart"
Cohesion: 0.22
Nodes (8): alarm_service.dart, body, bodyFromLevel, fromAlarmLevel, NotificationAction, NotificationService, title, titleFromLevel

### Community 44 - "sync-env-from-sa.js"
Cohesion: 0.22
Nodes (8): fs, lines, out, path, privateKeyEscaped, sa, saPath, saPathCandidates

### Community 45 - "statistic_card.dart"
Cohesion: 0.22
Nodes (8): Color, build, color, icon, StatisticCard, title, value, IconData

### Community 46 - "status_helper.dart"
Cohesion: 0.22
Nodes (8): constants.dart, color, icon, label, softColor, StatusHelper, subtitle, title

### Community 47 - "statistics_screen.dart"
Cohesion: 0.22
Nodes (8): build, _countByStatus, filterAlarmOnly, StatisticsScreen, _toMs, ../models/history_model.dart, providers/app_state_provider.dart, ../widgets/statistic_card.dart

### Community 48 - "logger.js"
Cohesion: 0.29
Nodes (4): debug(), isProduction(), deviceService, logger

### Community 49 - "debug.controller.js"
Cohesion: 0.25
Nodes (4): telemetryService, debugController, express, router

### Community 50 - "simulate-mqtt.js"
Cohesion: 0.29
Nodes (6): client, evaluateRule(), mqtt, nextSenderPayload(), options, PORT

### Community 51 - "vercel.json"
Cohesion: 0.25
Nodes (7): includeFiles, maxDuration, functions, api/index.js, rewrites, $schema, version

### Community 52 - "package:flutter/foundation.dart"
Cohesion: 0.25
Nodes (7): android, DefaultFirebaseOptions, web, windows, package:firebase_core/firebase_core.dart, package:flutter/foundation.dart, static const FirebaseOptions

### Community 53 - "simulate-receiver.js"
Cohesion: 0.52
Nodes (6): BASE_URL, ensureRegistered(), jitter(), postJson(), sendHeartbeat(), tickOnce()

### Community 54 - "utils/constants.dart"
Cohesion: 0.33
Nodes (5): AlarmLevel, AlarmService, describe, fromStatus, utils/constants.dart

### Community 55 - "../models/monitoring_model.dart"
Cohesion: 0.33
Nodes (5): isOffline, OfflineDetector, _thresholdMs, ../models/monitoring_model.dart, static int get

### Community 56 - "widget_test.dart"
Cohesion: 0.33
Nodes (5): main, package:flutter_test/flutter_test.dart, package:tracksafe_app/models/monitoring_model.dart, package:tracksafe_app/utils/constants.dart, package:tracksafe_app/utils/status_helper.dart

### Community 57 - "simulate-gps.js"
Cohesion: 0.60
Nodes (4): jitter(), nextPayload(), sendOnce(), STATUSES

### Community 58 - "simulate-devices.js"
Cohesion: 0.67
Nodes (3): BASE_URL, main(), postJson()

### Community 59 - "backend_status_http_response.dart"
Cohesion: 0.50
Nodes (3): BackendStatusHttpResponse, body, statusCode

## Knowledge Gaps
- **749 isolated node(s):** `express`, `cors`, `apiRoutes`, `statusController`, `{ notFoundHandler }` (+744 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MonitoringProvider` connect `device_pairing_screen.dart` to `dashboard_screen.dart`, `map_screen.dart`, `monitoring_provider.dart`, `main.dart`, `notification_listener_widget.dart`, `manage_devices_screen.dart`, `State`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `DevicePairingProvider` connect `manage_devices_screen.dart` to `setting_screen.dart`, `device_pairing_provider.dart`, `main.dart`, `device_pairing_screen.dart`, `main_shell.dart`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **Why does `DeviceLinkStatus` connect `system_labels.dart` to `device_monitor_card.dart`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **What connects `express`, `cors`, `apiRoutes` to the rest of the system?**
  _749 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `dashboard_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.028985507246376812 - nodes in this community are weakly interconnected._
- **Should `device.service.js` be split into smaller, more focused modules?**
  _Cohesion score 0.05632360471070148 - nodes in this community are weakly interconnected._
- **Should `map_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0392156862745098 - nodes in this community are weakly interconnected._