/**
 * One-off script to seed default activities. Run with:
 *   node seedActivities.js <path-to-serviceAccount.json>
 *
 * How to get the service account JSON:
 *   1. Open https://console.firebase.google.com/project/livegreen-bf838/settings/serviceaccounts/adminsdk
 *   2. Click "Generate new private key"
 *   3. Save the downloaded file (e.g. serviceAccount.json) anywhere on your machine
 *   4. Run: node .\seedActivities.js .\serviceAccount.json
 *
 * The Admin SDK bypasses Firestore security rules, so no emulator needed.
 */
const admin = require('firebase-admin');
const path  = require('path');

const serviceAccountPath = process.argv[2];
if (!serviceAccountPath) {
  console.error('Usage: node seedActivities.js <path-to-serviceAccount.json>');
  console.error('Download the key from: https://console.firebase.google.com/project/livegreen-bf838/settings/serviceaccounts/adminsdk');
  process.exit(1);
}

const serviceAccount = require(path.resolve(serviceAccountPath));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();


// list of work‑related wellness activities that will be shown to every
// user.  the admin can later add/remove documents from the `activities`
// collection using the Firebase console or by editing this script and re‑
// running it against the emulator/production project.
// full set of activities derived from the previous "Working" schedule.  Each
// document includes a timeSlot field so the client can group them just as it
// did before (morning/midday/afternoon/evening/weekend).  weight/category are
// preserved for compatibility, but feel free to add/remove items later via the
// console.
const activities = [
  // morning slot (weekday)
  {
    name: 'Mindfulness Bell Reminder',
    category: 'mindfulness',
    subtitle: 'Set a recurring mindfulness bell throughout the day',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },
  {
    name: 'Body Scan Meditation',
    category: 'mindfulness',
    subtitle: 'Practice mindfulness',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },
  {
    name: 'Go out in sunlight',
    category: 'health',
    subtitle: 'Exposure to morning sun',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },
  {
    name: 'Exercise',
    category: 'fitness',
    subtitle: 'Morning workout routine',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },
  {
    name: 'Gardening and composting',
    category: 'nature',
    subtitle: 'Connect with nature',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },
  {
    name: 'Breathing Exercise',
    category: 'mindfulness',
    subtitle: 'Meditation and mindfulness',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },
  {
    name: 'Finish the shower with cold water',
    category: 'health',
    subtitle: 'Cold water therapy',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },
  {
    name: 'No whatsapp or social media',
    category: 'digital_wellness',
    subtitle: 'Digital detox in the morning',
    timeSlot: 'Morning (6am-9am)',
    timeSlotOrder: 0,
    isWellnessActivity: true,
  },

  // mid-day slot (weekday)
  {
    name: 'Eat the food with protein, fibers and nutrients',
    category: 'nutrition',
    subtitle: 'Balanced mid-day meal',
    timeSlot: 'Mid-Day (9am-2pm)',
    timeSlotOrder: 1,
    isWellnessActivity: true,
  },
  {
    name: 'Check light intensity and maintain above 500 lux',
    category: 'health',
    subtitle: 'Proper workspace lighting',
    timeSlot: 'Mid-Day (9am-2pm)',
    timeSlotOrder: 1,
    isWellnessActivity: true,
  },
  {
    name: 'Keep spine straight',
    category: 'posture',
    subtitle: 'Maintain good posture',
    timeSlot: 'Mid-Day (9am-2pm)',
    timeSlotOrder: 1,
    isWellnessActivity: true,
  },
  {
    name: 'Every 15 min look at long horizon',
    category: 'eye_health',
    subtitle: '20-20-20 rule',
    timeSlot: 'Mid-Day (9am-2pm)',
    timeSlotOrder: 1,
    isWellnessActivity: true,
  },
  {
    name: 'Deep work',
    category: 'productivity',
    subtitle: 'Concentrated focus session',
    timeSlot: 'Mid-Day (9am-2pm)',
    timeSlotOrder: 1,
    isWellnessActivity: true,
  },

  // afternoon slot (weekday)
  {
    name: 'Eat lunch mindfully',
    category: 'nutrition',
    subtitle: 'Mindful eating',
    timeSlot: 'Afternoon (2:30pm-6pm)',
    timeSlotOrder: 2,
    isWellnessActivity: true,
  },
  {
    name: 'Take walk and observe nature around you',
    category: 'nature',
    subtitle: 'Nature walk',
    timeSlot: 'Afternoon (2:30pm-6pm)',
    timeSlotOrder: 2,
    isWellnessActivity: true,
  },
  {
    name: 'Do minor work like sending emails, administrative tasks',
    category: 'productivity',
    subtitle: 'Light office tasks',
    timeSlot: 'Afternoon (2:30pm-6pm)',
    timeSlotOrder: 2,
    isWellnessActivity: true,
  },

  // evening slot (weekday)
  {
    name: 'Play a game for 15-30 minutes (Chess, table tennis, Sudoku)',
    category: 'mental_fitness',
    subtitle: 'Cognitive games',
    timeSlot: 'Evening (7pm-10pm)',
    timeSlotOrder: 3,
    isWellnessActivity: true,
  },
  {
    name: 'Spend time with family, no screens, no social media',
    category: 'social',
    subtitle: 'Device-free family time',
    timeSlot: 'Evening (7pm-10pm)',
    timeSlotOrder: 3,
    isWellnessActivity: true,
  },
  {
    name: 'Listen to calming music',
    category: 'relaxation',
    subtitle: 'Relaxing audio for the evening',
    timeSlot: 'Evening (7pm-10pm)',
    timeSlotOrder: 3,
    isWellnessActivity: true,
  },
  {
    name: 'use warm color (amber) Led light (100-200 lux)',
    category: 'sleep_hygiene',
    subtitle: 'Warm evening lighting',
    timeSlot: 'Evening (7pm-10pm)',
    timeSlotOrder: 3,
    isWellnessActivity: true,
  },
  {
    name: 'Reduce the light intensity below 50lux one hour before sleep, do star gazing for 10 minutes',
    category: 'sleep_hygiene',
    subtitle: 'Dim lights and stargaze',
    timeSlot: 'Evening (7pm-10pm)',
    timeSlotOrder: 3,
    isWellnessActivity: true,
  },

  // weekend activities
  {
    name: 'Birding',
    category: 'nature',
    subtitle: 'Connect with wildlife',
    timeSlot: 'Weekend',
    timeSlotOrder: 4,
    isWellnessActivity: true,
  },
  {
    name: 'Tree identification',
    category: 'nature',
    subtitle: 'Learn about trees',
    timeSlot: 'Weekend',
    timeSlotOrder: 4,
    isWellnessActivity: true,
  },
  {
    name: 'Swimming or physical sports',
    category: 'fitness',
    subtitle: 'Active recreation',
    timeSlot: 'Weekend',
    timeSlotOrder: 4,
    isWellnessActivity: true,
  },
  {
    name: 'Trekking and camping',
    category: 'nature',
    subtitle: 'Outdoor adventure',
    timeSlot: 'Weekend',
    timeSlotOrder: 4,
    isWellnessActivity: true,
  },
  {
    name: 'Cycling or walking in natural terrain',
    category: 'fitness',
    subtitle: 'Trail exercise',
    timeSlot: 'Weekend',
    timeSlotOrder: 4,
    isWellnessActivity: true,
  },
];

async function seed() {
  const col = db.collection('activities');

  // clear existing docs first so re-running is idempotent
  console.log('Clearing existing activities…');
  const existing = await col.get();
  const deleteBatch = db.batch();
  existing.docs.forEach(d => deleteBatch.delete(d.ref));
  await deleteBatch.commit();

  // write new docs 500 at a time (Firestore batch limit)
  const CHUNK = 500;
  for (let i = 0; i < activities.length; i += CHUNK) {
    const batch = db.batch();
    activities.slice(i, i + CHUNK).forEach(item => {
      const doc = typeof item === 'string' ? { name: item } : item;
      console.log('  +', doc.name);
      batch.set(col.doc(), doc);
    });
    await batch.commit();
  }

  console.log('\nDone – all activities written to Firestore.');
  process.exit(0);
}

seed().catch(err => { console.error(err.message || err); process.exit(1); });
