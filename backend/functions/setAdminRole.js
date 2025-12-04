/**
 * Helper script to set a user as admin
 * 
 * Usage:
 * node setAdminRole.js <user-email>
 * 
 * Example:
 * node setAdminRole.js admin@livegreen.com
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (uses default credentials from environment)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function setAdminRole(email) {
  try {
    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    const uid = userRecord.uid;

    console.log(`Found user: ${email} (UID: ${uid})`);

    // Update user document in Firestore
    await db.collection('users').doc(uid).set(
      {
        role: 'admin',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(`✅ Successfully set ${email} as admin!`);
    console.log(`User UID: ${uid}`);
    console.log(`Role: admin`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting admin role:', error.message);
    process.exit(1);
  }
}

// Get email from command line arguments
const email = process.argv[2];

if (!email) {
  console.error('❌ Usage: node setAdminRole.js <user-email>');
  console.error('Example: node setAdminRole.js admin@livegreen.com');
  process.exit(1);
}

console.log(`Setting admin role for: ${email}`);
setAdminRole(email);
