const admin = require('firebase-admin');

// Initialize admin SDK with service account for local scripts
let serviceAccount;
try {
  serviceAccount = require('./serviceAccountKey.json');
} catch (e) {
  console.error('Missing serviceAccountKey.json. Please download it from Firebase Console.');
  process.exit(1);
}
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'livegreen-bf838'
  });
} catch (e) {
  // App might already be initialized
}

const db = admin.firestore();

async function seedData() {
  try {
    // Seed some initial activities
    const activities = [
      { name: 'Use Public Transport', impact: 5, category: 'Transportation' },
      { name: 'Recycle Waste', impact: 3, category: 'Waste Management' },
      { name: 'Plant a Tree', impact: 8, category: 'Environment' },
      { name: 'Use Reusable Bags', impact: 2, category: 'Shopping' },
      { name: 'Save Water', impact: 4, category: 'Resource Conservation' }
    ];

    console.log('Seeding activities...');
    for (const activity of activities) {
      await db.collection('activities').add({
        ...activity,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // Seed some forum posts
    const forumPosts = [
      { text: 'Welcome to LiveGreen! Share your eco-friendly tips here.', userId: 'system', userName: 'LiveGreen Admin' },
      { text: 'Started using public transport today. Feeling great about reducing my carbon footprint!', userId: 'system', userName: 'LiveGreen Admin' },
      { text: 'Anyone interested in organizing a community cleanup this weekend?', userId: 'system', userName: 'LiveGreen Admin' }
    ];

    console.log('Seeding forum posts...');
    for (const post of forumPosts) {
      await db.collection('forum').add({
        ...post,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    console.log('Data seeding completed successfully!');
  } catch (error) {
    console.error('Error seeding data:', error);
  }
}

seedData().then(() => process.exit());