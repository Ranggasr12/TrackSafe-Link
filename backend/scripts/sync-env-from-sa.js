/**
 * One-shot helper: build .env from serviceAccountKey*.json
 * Run: node scripts/sync-env-from-sa.js
 *
 * Development Only — script lokal untuk generate .env.
 * JANGAN commit .env atau serviceAccountKey*.json.
 */
const fs = require('fs');
const path = require('path');

const saPathCandidates = [
  path.join(__dirname, '..', 'serviceAccountKey.json'),
  path.join(__dirname, '..', 'serviceAccountKey.json.json'),
];

const saPath = saPathCandidates.find((p) => fs.existsSync(p));
if (!saPath) {
  console.error('serviceAccountKey not found');
  process.exit(1);
}

const sa = JSON.parse(fs.readFileSync(saPath, 'utf8'));
const privateKeyEscaped = String(sa.private_key).replace(/\n/g, '\\n');

// Development Only — URL RTDB dari env jika ada, else dari project_id SA.
const databaseUrl =
  process.env.FIREBASE_DATABASE_URL ||
  `https://${sa.project_id}-default-rtdb.asia-southeast1.firebasedatabase.app`;

const lines = [
  '# TrackSafe Backend — local only (DO NOT COMMIT)',
  'NODE_ENV=development',
  'PORT=3000',
  '',
  `FIREBASE_PROJECT_ID=${sa.project_id}`,
  `FIREBASE_CLIENT_EMAIL=${sa.client_email}`,
  `FIREBASE_PRIVATE_KEY="${privateKeyEscaped}"`,
  `FIREBASE_DATABASE_URL=${databaseUrl}`,
  '',
  'FRONTEND_URL=',
  'ALLOWED_ORIGIN=',
  '',
];

const out = path.join(__dirname, '..', '.env');
fs.writeFileSync(out, lines.join('\n'), 'utf8');
console.log('Wrote', out);
console.log('Also set the same vars in Vercel Dashboard → Environment Variables');
