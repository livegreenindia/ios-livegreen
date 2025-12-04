const admin = require('firebase-admin');

// Set project ID
process.env.GCLOUD_PROJECT = 'livegreen-bf838';
process.env.FIRESTORE_EMULATOR_HOST = undefined; // Use production

// Initialize Firebase Admin with application default credentials
admin.initializeApp({
  projectId: 'livegreen-bf838'
});

console.log('✅ Firebase Admin initialized\n');

// Direct implementation to send test notifications
async function sendTestNotification(type) {
  const db = admin.firestore();
  const today = new Date().toISOString().substring(0, 10);
  
  try {
    console.log(`\n🔔 Sending ${type} notifications...`);
    
    // Get all users with FCM tokens
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} total users`);
    
    let sent = 0;
    let failed = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      
      if (!fcmToken) {
        continue;
      }
      
      let message;
      
      if (type === 'morning') {
        message = {
          notification: {
            title: '🌅 Good Morning! (TEST)',
            body: 'This is a test morning notification from your wellness app!',
          },
          data: {
            type: 'morning_reminder_test',
            date: today,
          },
          token: fcmToken,
          android: {
            priority: 'high',
            notification: {
              icon: 'ic_notification',
              color: '#38e07b',
              defaultSound: true,
            },
          },
        };
      } else if (type === 'social') {
        message = {
          notification: {
            title: '📱 Social Media Alert (TEST)',
            body: 'This is a test social media usage notification!',
          },
          data: {
            type: 'social_media_test',
            date: today,
          },
          token: fcmToken,
          android: {
            priority: 'high',
            notification: {
              icon: 'ic_notification',
              color: '#FF9800',
              defaultSound: true,
            },
          },
        };
      } else if (type === 'activity') {
        message = {
          notification: {
            title: '🌿 Activity Reminder (TEST)',
            body: 'This is a test evening activity notification!',
          },
          data: {
            type: 'activity_reminder_test',
            date: today,
          },
          token: fcmToken,
          android: {
            priority: 'high',
            notification: {
              icon: 'ic_notification',
              color: '#38e07b',
              defaultSound: true,
            },
          },
        };
      }
      
      try {
        await admin.messaging().send(message);
        sent++;
        console.log(`  ✅ Sent to user ${uid.substring(0, 8)}...`);
      } catch (error) {
        failed++;
        console.log(`  ❌ Failed for user ${uid.substring(0, 8)}...: ${error.code}`);
        
        // Remove invalid tokens
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
          await db.collection('users').doc(uid).update({ 
            fcmToken: admin.firestore.FieldValue.delete() 
          });
          console.log(`     🗑️  Removed invalid token`);
        }
      }
    }
    
    console.log(`\n📊 ${type.toUpperCase()} Results: ${sent} sent, ${failed} failed`);
    return { sent, failed };
    
  } catch (error) {
    console.error(`❌ Error in ${type} test:`, error);
    throw error;
  }
}

async function runTests() {
  console.log('🚀 Starting Notification Tests...');
  
  try {
    await sendTestNotification('morning');
    await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
    
    await sendTestNotification('social');
    await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
    
    await sendTestNotification('activity');
    
    console.log('\n✅ All test notifications sent!\n');
  } catch (error) {
    console.error('\n❌ Test failed:', error);
  }
  
  process.exit(0);
}

runTests();
