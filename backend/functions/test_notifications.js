const admin = require('firebase-admin');

// Set project ID
process.env.GCLOUD_PROJECT = 'livegreen-bf838';

// Initialize Firebase Admin
try {
  const serviceAccount = require('./livegreen-bf838-firebase-adminsdk-9yktb-a82f1feaf2.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'livegreen-bf838'
  });
  console.log('✅ Firebase Admin initialized');
} catch (e) {
  console.log('Admin already initialized or using default credentials');
}

async function testMorningReminders() {
  console.log('\n=== Testing Morning Reminders ===');
  const { sendMorningReminders } = require('./sendMorningReminders');
  const mockEvent = { timestamp: new Date().toISOString() };
  
  try {
    const result = await sendMorningReminders(mockEvent);
    console.log('✅ Morning Reminders Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('❌ Morning Reminders Error:', error.message);
  }
}

async function testSocialMediaCheck() {
  console.log('\n=== Testing Social Media Usage Check ===');
  const { checkSocialMediaUsage } = require('./checkSocialMediaUsage');
  const mockEvent = { timestamp: new Date().toISOString() };
  
  try {
    const result = await checkSocialMediaUsage(mockEvent);
    console.log('✅ Social Media Check Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('❌ Social Media Check Error:', error.message);
  }
}

async function testActivityReminders() {
  console.log('\n=== Testing Activity Reminders ===');
  const { sendActivityReminders } = require('./sendActivityReminders');
  const mockEvent = { timestamp: new Date().toISOString() };
  
  try {
    const result = await sendActivityReminders(mockEvent);
    console.log('✅ Activity Reminders Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.error('❌ Activity Reminders Error:', error.message);
  }
}

async function runAllTests() {
  console.log('🚀 Starting Notification Tests...\n');
  
  await testMorningReminders();
  await testSocialMediaCheck();
  await testActivityReminders();
  
  console.log('\n✅ All tests completed!\n');
  process.exit(0);
}

runAllTests().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
