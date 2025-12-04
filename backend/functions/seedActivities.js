/**
 * One-off script to seed default activities. Run with:
 * node seedActivities.js
 * Ensure GOOGLE_APPLICATION_CREDENTIALS is set to a service account JSON when running locally.
 */
const admin = require('firebase-admin');

try {
  // When running against the emulator locally, some environments don't set
  // the GOOGLE_CLOUD_PROJECT properly. Provide a sensible default so the
  // script can write to the emulator.
  const projectId = process.env.GOOGLE_CLOUD_PROJECT || 'livegreen-bf838';
  admin.initializeApp({ projectId });
} catch (e) {}
const db = admin.firestore();

const activities = [
  'Birding', 'Visiting Park', 'Cold Water Shower', 'Gardening', 'Composting', 'Sky Watch', 'Sun Ray Exposure'
];

async function seed() {
  for (const name of activities) {
    console.log('Adding', name);
    await db.collection('activities').add({ name, weight: 1 });
  }
  console.log('Done');
  process.exit(0);
}

seed().catch(err => { console.error(err); process.exit(1); });
