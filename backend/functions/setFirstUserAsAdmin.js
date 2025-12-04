/**
 * Helper script to set the first user (or specific user) as admin
 * 
 * Usage:
 * node setFirstUserAsAdmin.js
 * 
 * This will list all users and let you choose one to make admin
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function listAllUsers() {
  try {
    const listUsersResult = await admin.auth().listUsers(1000);
    return listUsersResult.users;
  } catch (error) {
    console.error('Error listing users:', error);
    return [];
  }
}

async function setAdminRole(uid, email) {
  try {
    // Update user document in Firestore
    await db.collection('users').doc(uid).set(
      {
        role: 'admin',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(`\n✅ Successfully set ${email} as admin!`);
    console.log(`   User UID: ${uid}`);
    console.log(`   Role: admin\n`);
    
    return true;
  } catch (error) {
    console.error('❌ Error setting admin role:', error.message);
    return false;
  }
}

async function main() {
  console.log('🔍 Fetching all users...\n');
  
  const users = await listAllUsers();
  
  if (users.length === 0) {
    console.log('❌ No users found in the system.');
    console.log('   Please create a user account first through the app.\n');
    process.exit(1);
  }

  console.log(`Found ${users.length} user(s):\n`);
  
  users.forEach((user, index) => {
    console.log(`${index + 1}. ${user.email || 'No email'}`);
    console.log(`   UID: ${user.uid}`);
    console.log(`   Display Name: ${user.displayName || 'Not set'}`);
    console.log(`   Created: ${user.metadata.creationTime}\n`);
  });

  // If only one user, make them admin automatically
  if (users.length === 1) {
    console.log(`Only one user found. Setting ${users[0].email} as admin...\n`);
    await setAdminRole(users[0].uid, users[0].email);
    process.exit(0);
  }

  // If multiple users, ask which one
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  rl.question('Enter the number of the user to make admin (or press Ctrl+C to cancel): ', async (answer) => {
    const index = parseInt(answer) - 1;
    
    if (index >= 0 && index < users.length) {
      const selectedUser = users[index];
      await setAdminRole(selectedUser.uid, selectedUser.email);
    } else {
      console.log('❌ Invalid selection.');
    }
    
    rl.close();
    process.exit(0);
  });
}

main();
