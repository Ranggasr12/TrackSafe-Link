/**
 * Simulasi deployment Vercel (tanpa akun Vercel).
 *
 * Development Only — script uji lokal sebelum deploy.
 *
 * Mengecek:
 * - MODULE_NOT_FOUND / require graph
 * - Express export (function)
 * - Env vars & private key sanitizing
 * - Invokasi handler ala Serverless (paths /api/* dan stripped /*)
 * - Routing 404 / 400 / 200
 *
 * Usage: node scripts/simulate-vercel.js
 */

require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const path = require('path');
const http = require('http');
const fs = require('fs');

const ROOT = path.join(__dirname, '..');
const results = [];

function ok(name, detail) {
  results.push({ name, pass: true, detail });
  console.log(`  ✅ ${name}${detail ? ` — ${detail}` : ''}`);
}

function fail(name, detail) {
  results.push({ name, pass: false, detail });
  console.error(`  ❌ ${name} — ${detail}`);
}

function section(title) {
  console.log(`\n=== ${title} ===`);
}

function checkFile(rel) {
  const full = path.join(ROOT, rel);
  if (!fs.existsSync(full)) {
    fail(`file:${rel}`, 'missing');
    return false;
  }
  ok(`file:${rel}`, 'exists');
  return true;
}

async function invoke(app, { method, url, body }) {
  return new Promise((resolve, reject) => {
    const server = app.listen(0, '127.0.0.1', () => {
      // Development Only — loopback untuk harness uji lokal
      const { port } = server.address();
      const payload = body ? JSON.stringify(body) : null;
      const req = http.request(
        {
          hostname: '127.0.0.1',
          port,
          path: url,
          method,
          headers: {
            'Content-Type': 'application/json',
            ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
          },
        },
        (res) => {
          let data = '';
          res.on('data', (c) => {
            data += c;
          });
          res.on('end', () => {
            server.close();
            let json = null;
            try {
              json = JSON.parse(data);
            } catch (_) {
              json = data;
            }
            resolve({ status: res.statusCode, body: json });
          });
        },
      );
      req.on('error', (err) => {
        server.close();
        reject(err);
      });
      if (payload) req.write(payload);
      req.end();
    });
  });
}

async function main() {
  console.log('TrackSafe — Vercel deploy simulation\n');

  // 1. Struktur & config
  section('Project structure');
  [
    'api/index.js',
    'app.js',
    'vercel.json',
    'package.json',
    'config/firebase.js',
    'controllers/status.controller.js',
    'controllers/sensor.controller.js',
    'routes/index.js',
    'middleware/errorHandler.js',
    'services/telemetry.service.js',
  ].forEach(checkFile);

  // 2. vercel.json
  section('vercel.json');
  try {
    const vercel = JSON.parse(fs.readFileSync(path.join(ROOT, 'vercel.json'), 'utf8'));
    if (!vercel.rewrites || !vercel.rewrites.length) {
      fail('rewrites', 'missing rewrites[]');
    } else {
      const dest = vercel.rewrites[0].destination;
      if (dest === '/api/index.js' || dest === '/api' || dest === '/api/index') {
        ok('rewrites.destination', dest);
      } else {
        fail('rewrites.destination', `unexpected: ${dest}`);
      }
      if (vercel.builds) {
        fail('legacy builds', 'masih memakai builds[] (legacy) — sebaiknya rewrites saja');
      } else {
        ok('no legacy builds', 'OK');
      }
    }
    if (vercel.functions && vercel.functions['api/index.js']) {
      const fn = vercel.functions['api/index.js'];
      ok('functions.api/index.js', `maxDuration=${fn.maxDuration}, includeFiles=${!!fn.includeFiles}`);
    } else {
      fail('functions', 'api/index.js tidak dikonfigurasi');
    }
  } catch (e) {
    fail('vercel.json parse', e.message);
  }

  // 3. package.json dependencies
  section('Dependencies');
  const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
  for (const dep of ['express', 'firebase-admin', 'cors', 'dotenv']) {
    if (pkg.dependencies && pkg.dependencies[dep]) {
      ok(`dep:${dep}`, pkg.dependencies[dep]);
    } else {
      fail(`dep:${dep}`, 'missing in dependencies');
    }
    try {
      require.resolve(dep, { paths: [ROOT] });
      ok(`resolve:${dep}`, 'node_modules OK');
    } catch (e) {
      fail(`resolve:${dep}`, e.message);
    }
  }
  if (pkg.dependencies && pkg.dependencies.mqtt) {
    fail('dep:mqtt', 'MQTT tidak boleh ada di Serverless HTTP-only');
  } else {
    ok('no mqtt dependency', 'OK');
  }
  if (pkg.engines && String(pkg.engines.node).includes('20')) {
    ok('engines.node', pkg.engines.node);
  } else {
    fail('engines.node', 'disarankan node 20.x untuk Vercel');
  }

  // 4. Environment variables
  section('Environment variables');
  const required = [
    'FIREBASE_PROJECT_ID',
    'FIREBASE_CLIENT_EMAIL',
    'FIREBASE_PRIVATE_KEY',
    'FIREBASE_DATABASE_URL',
  ];
  for (const key of required) {
    if (process.env[key]) ok(`env:${key}`, 'SET');
    else fail(`env:${key}`, 'MISSING — set di Vercel Dashboard');
  }

  // 5. Private key sanitize
  section('FIREBASE_PRIVATE_KEY sanitization');
  try {
    const { sanitizePrivateKey } = require('../config/firebase');
    const raw = process.env.FIREBASE_PRIVATE_KEY || '';
    const sanitized = sanitizePrivateKey(raw);
    if (sanitized.includes('BEGIN') && sanitized.includes('\n')) {
      ok('sanitizePrivateKey', 'PEM dengan newline valid');
    } else {
      fail('sanitizePrivateKey', 'hasil sanitasi tidak valid');
    }
    // Simulate Vercel-style quoted value
    const quoted = `"${raw.replace(/\n/g, '\\n')}"`;
    const fromQuoted = sanitizePrivateKey(quoted);
    if (fromQuoted.includes('BEGIN PRIVATE KEY')) {
      ok('sanitize quoted+escaped', 'OK');
    } else {
      fail('sanitize quoted+escaped', 'gagal');
    }
  } catch (e) {
    fail('sanitizePrivateKey', e.message);
  }

  // 6. Module graph / Express export
  section('MODULE_NOT_FOUND & Express export');
  let app;
  try {
    // Clear cache to simulate cold start
    Object.keys(require.cache).forEach((k) => {
      if (k.includes(`${path.sep}backend${path.sep}`) || k.includes('/backend/')) {
        delete require.cache[k];
      }
    });
    app = require('../api/index.js');
    if (typeof app === 'function') {
      ok('api/index.js export', 'function (Express app)');
    } else {
      fail('api/index.js export', `type=${typeof app}`);
    }
  } catch (e) {
    fail('require api/index.js', e.message);
    printSummary();
    process.exit(1);
  }

  // Detect accidental listen in loaded modules — can't easily; skip

  // 7. Serverless-style route invocations
  section('Function invocation (routing)');
  const cases = [
    { name: 'GET /api/status', method: 'GET', url: '/api/status', expect: 200 },
    { name: 'GET /status (stripped prefix)', method: 'GET', url: '/status', expect: 200 },
    { name: 'GET /health', method: 'GET', url: '/health', expect: 200 },
    {
      name: 'POST /api/sensor valid',
      method: 'POST',
      url: '/api/sensor',
      body: {
        deviceId: 'sender01',
        status: 'NORMAL',
        distance: 320,
        battery: 88,
        signal: 22,
        latitude: -6.914744,
        longitude: 107.60981,
        speed: 4.2,
        timestamp: Math.floor(Date.now() / 1000),
      },
      expect: 200,
    },
    {
      name: 'POST /sensor (stripped)',
      method: 'POST',
      url: '/sensor',
      body: {
        deviceId: 'sender01',
        status: 'NOISE',
        distance: 200,
        battery: 88,
        signal: 18,
        latitude: -6.914744,
        longitude: 107.60981,
        speed: 0,
        timestamp: Math.floor(Date.now() / 1000),
      },
      expect: 200,
    },
    {
      name: 'POST /api/sensor invalid (400)',
      method: 'POST',
      url: '/api/sensor',
      body: { deviceId: 'sender01' },
      expect: 400,
    },
    {
      name: 'POST /api/sensor invalid GPS latitude (400)',
      method: 'POST',
      url: '/api/sensor',
      body: {
        deviceId: 'sender01',
        status: 'NORMAL',
        distance: 120,
        battery: 90,
        signal: 20,
        latitude: 99,
        longitude: 107.60981,
        speed: 1,
        timestamp: Math.floor(Date.now() / 1000),
      },
      expect: 400,
    },
    {
      name: 'POST /api/sensor invalid GPS speed (400)',
      method: 'POST',
      url: '/api/sensor',
      body: {
        deviceId: 'sender01',
        status: 'NORMAL',
        distance: 120,
        battery: 90,
        signal: 20,
        latitude: -6.914744,
        longitude: 107.60981,
        speed: -1,
        timestamp: Math.floor(Date.now() / 1000),
      },
      expect: 400,
    },
    {
      name: 'GET /api/device/sender01',
      method: 'GET',
      url: '/api/device/sender01',
      expect: 200,
    },
    {
      name: 'GET /api/devices',
      method: 'GET',
      url: '/api/devices',
      expect: 200,
    },
    {
      name: 'POST /api/device/heartbeat',
      method: 'POST',
      url: '/api/device/heartbeat',
      body: {
        deviceId: 'sender01',
        battery: 90,
        signal: 20,
        gpsFix: true,
        latitude: -6.914744,
        longitude: 107.60981,
      },
      expect: 200,
    },
    {
      name: 'POST /api/device/heartbeat unknown device (404)',
      method: 'POST',
      url: '/api/device/heartbeat',
      body: {
        deviceId: 'device-does-not-exist-xyz',
        battery: 10,
        signal: 1,
      },
      expect: 404,
    },
    { name: 'GET unknown (404)', method: 'GET', url: '/api/does-not-exist', expect: 404 },
  ];

  for (const c of cases) {
    try {
      const res = await invoke(app, c);
      if (res.status === c.expect) {
        ok(c.name, `HTTP ${res.status}`);
      } else {
        fail(c.name, `expected ${c.expect}, got ${res.status} body=${JSON.stringify(res.body)}`);
      }
      if (c.url.includes('status') && res.status === 200) {
        if (res.body && res.body.backend === 'online' && res.body.firebase === 'connected') {
          ok(`${c.name} payload`, 'backend online + firebase connected');
        } else {
          fail(`${c.name} payload`, JSON.stringify(res.body));
        }
      }
      if (c.url === '/api/device/sender01' && res.status === 200) {
        const b = res.body || {};
        if (
          typeof b.exists === 'boolean'
          && typeof b.deviceType === 'string'
          && typeof b.status === 'string'
          && b.success === true
          && b.data != null
        ) {
          ok(`${c.name} payload`, `exists=${b.exists} type=${b.deviceType} status=${b.status}`);
        } else {
          fail(`${c.name} payload`, JSON.stringify(b));
        }
      }
      if (c.url === '/api/devices' && res.status === 200) {
        const b = res.body || {};
        if (b.success === true && Array.isArray(b.devices)) {
          ok(`${c.name} payload`, `count=${b.count}`);
        } else {
          fail(`${c.name} payload`, JSON.stringify(b));
        }
      }
      if (c.url === '/api/device/heartbeat' && res.status === 200) {
        const b = res.body || {};
        if (b.success === true && b.updated === true && typeof b.status === 'string') {
          ok(`${c.name} payload`, `status=${b.status}`);
        } else {
          fail(`${c.name} payload`, JSON.stringify(b));
        }
      }
    } catch (e) {
      fail(c.name, e.message);
    }
  }

  printSummary();
  // Firebase Admin menjaga event loop — paksa keluar setelah simulasi
  setTimeout(() => process.exit(process.exitCode || 0), 100);
}

function printSummary() {
  section('Summary');
  const passed = results.filter((r) => r.pass).length;
  const failed = results.filter((r) => !r.pass).length;
  console.log(`Passed: ${passed}`);
  console.log(`Failed: ${failed}`);
  if (failed > 0) {
    console.log('\nPOTENSI ERROR SEBELUM DEPLOY — perbaiki item ❌ di atas.');
    process.exitCode = 1;
  } else {
    console.log('\nSiap deploy ke Vercel: vercel --prod');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
