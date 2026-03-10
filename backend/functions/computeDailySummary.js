const functions = require('firebase-functions');
const admin = require('firebase-admin');

// we now store the list of "work" activities in Firestore; every user
// gets the same set regardless of profile.  expected counts are computed by
// counting documents in that collection, which keeps the daily summaries
// aligned with whatever the admin has seeded.

// Check if a date is weekend (Saturday or Sunday)
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Get expected activity count by querying Firestore.  The profile parameter is
// ignored but kept for backwards compatibility.
async function getExpectedActivityCount(profile, date, db) {
  try {
    const snap = await db.collection('activities').get();
    return snap.size;
  } catch (e) {
    console.error('Error counting activities', e);
    return 0;
  }
}

// Computes daily completion percent for all users once per day (UTC midnight)
exports.scheduledDailySummary = functions.pubsub.schedule('0 1 * * *').timeZone('UTC').onRun(async (context) => {
  const auth = admin.auth();
  const db = admin.firestore();
  console.log('Running scheduledDailySummary - Activity-based progress calculation');
  let nextPageToken;
  let processedCount = 0;
  
  do {
    const listUsersResult = await auth.listUsers(1000, nextPageToken);
    
    for (const userRecord of listUsersResult.users) {
      const uid = userRecord.uid;
      
      try {
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        const dateStr = yesterday.toISOString().slice(0, 10);

        // Get user's wellness profile
        const userDoc = await db.collection('users').doc(uid).get();
        const userData = userDoc.exists ? userDoc.data() : {};
        const wellnessProfile = userData.wellness_profile || 'default';
        
        // Get expected activity count (profile ignored) by querying the
        // activities collection in Firestore.
        const expectedActivities = await getExpectedActivityCount(wellnessProfile, yesterday, db);
        
        // Count completed activities for that date
        // Note: Completions are stored with 'date' field (YYYY-MM-DD format)
        const compSnap = await db.collection('users')
          .doc(uid)
          .collection('completions')
          .where('date', '==', dateStr)
          .get();
        
        const completedCount = compSnap.size;
        
        // Calculate completion percent based on completed vs expected activities
        // Cap at 100% even if user completes more than expected
        const completionPercent = expectedActivities === 0 
          ? 0 
          : Math.min(100, Math.round((completedCount / expectedActivities) * 100));

        // Store the summary with additional metadata
        await db.collection('users')
          .doc(uid)
          .collection('dailySummaries')
          .doc(dateStr)
          .set({ 
            date: dateStr, 
            completionPercent,
            completedCount,
            expectedCount: expectedActivities,
            profile: wellnessProfile,
            isWeekend: isWeekend(yesterday),
            ts: admin.firestore.FieldValue.serverTimestamp() 
          }, { merge: true });
        
        processedCount++;
      } catch (err) {
        console.error('Error processing user', uid, err);
      }
    }
    
    nextPageToken = listUsersResult.pageToken;
  } while (nextPageToken);
  
  console.log(`Processed ${processedCount} users for daily summary`);
  return null;
});

// HTTP endpoint to manually compute daily summary for a user (for testing)
exports.computeUserDailySummary = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const { uid, date } = req.query;
  
  if (!uid) {
    return res.status(400).json({ error: 'uid required' });
  }
  
  try {
    const targetDate = date ? new Date(date) : new Date();
    const dateStr = targetDate.toISOString().slice(0, 10);
    
    // Get user's wellness profile
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const wellnessProfile = userData.wellness_profile || 'default';
    
    // Get expected activity count from Firestore collection
    const expectedActivities = await getExpectedActivityCount(wellnessProfile, targetDate, db);
    
    // Count completed activities
    // Note: Completions are stored with 'date' field (YYYY-MM-DD format)
    const compSnap = await db.collection('users')
      .doc(uid)
      .collection('completions')
      .where('date', '==', dateStr)
      .get();
    
    const completedCount = compSnap.size;
    const completionPercent = expectedActivities === 0 
      ? 0 
      : Math.min(100, Math.round((completedCount / expectedActivities) * 100));
    
    // Store summary
    await db.collection('users')
      .doc(uid)
      .collection('dailySummaries')
      .doc(dateStr)
      .set({ 
        date: dateStr, 
        completionPercent,
        completedCount,
        expectedCount: expectedActivities,
        profile: wellnessProfile,
        isWeekend: isWeekend(targetDate),
        ts: admin.firestore.FieldValue.serverTimestamp() 
      }, { merge: true });
    
    res.json({
      uid,
      date: dateStr,
      profile: wellnessProfile,
      completedCount,
      expectedCount: expectedActivities,
      completionPercent,
      isWeekend: isWeekend(targetDate)
    });
  } catch (err) {
    console.error('Error computing summary:', err);
    res.status(500).json({ error: err.message });
  }
});
