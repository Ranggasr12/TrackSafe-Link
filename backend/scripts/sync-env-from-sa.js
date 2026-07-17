/**
 * One-shot helper: build .env from serviceAccountKey.json.json
 * Run: node scripts/sync-env-from-sa.js
 * Then hapus service account dari repo sebelum push/deploy jika perlu.
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

const lines = [
  '# TrackSafe Backend — local only (DO NOT COMMIT)',
  'NODE_ENV=development',
  'PORT=3000',
  '',
  `FIREBASE_PROJECT_ID=${sa.project_id}`,
  `FIREBASE_CLIENT_EMAIL=${sa.client_email}`,
  `FIREBASE_PRIVATE_KEY="${privateKeyEscaped}"`,
  'FIREBASE_DATABASE_URL=https://tracksafe-link-default-rtdb.asia-southeast1.firebasedatabase.app',
  '',
];

const out = path.join(__dirname, '..', '.env');
fs.writeFileSync(out, lines.join('\n'), 'utf8');
console.log('Wrote', out);
console.log('Also set the same 4 vars in Vercel Dashboard → Environment Variables');
