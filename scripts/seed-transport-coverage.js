#!/usr/bin/env node
/**
 * Seeds config/transport_coverage in Firestore.
 *
 * Option A — Firebase Console (no CLI auth):
 *   Firestore → Start collection `config` → document `transport_coverage`
 *   Fields: regionName (string), zipPrefixes (array), zipCodes (array)
 *
 * Option B — This script (needs Application Default Credentials):
 *   gcloud auth application-default login --project care-signal-ai
 *   node scripts/seed-transport-coverage.js
 */
const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'care-signal-ai';

admin.initializeApp({ projectId });

const doc = {
  regionName: 'San Francisco Bay Area',
  zipPrefixes: ['940', '941', '943', '944', '945', '950', '951'],
  zipCodes: [],
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
};

async function main() {
  const ref = admin.firestore().doc('config/transport_coverage');
  await ref.set(doc, { merge: true });
  const snap = await ref.get();
  console.log(`Seeded ${ref.path} on ${projectId}:`);
  console.log(JSON.stringify(snap.data(), null, 2));
}

main().catch((err) => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});
