const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Wellness activity counts per profile (based on wellness_schedule_data.dart)
// Each profile has different number of daily activities
const WELLNESS_ACTIVITY_COUNTS = {
  // Working profile: 6 morning + 6 mid-day + 3 afternoon + 5 evening = 20 weekday, 6 weekend
  'Working': { weekday: 20, weekend: 6 },
  // Student profile: 6 morning + 6 mid-day + 3 afternoon + 5 evening = 20 weekday, 6 weekend
  'Student': { weekday: 20, weekend: 6 },
  // Housewife profile: 6 morning + 6 mid-day + 3 afternoon + 5 evening = 20 weekday, 6 weekend
  'Housewife': { weekday: 20, weekend: 6 },
  // Retired profile: 6 morning + 6 mid-day + 3 afternoon + 5 evening = 20 weekday, 6 weekend
  'Retired': { weekday: 20, weekend: 6 },
  // Default for users without profile
  'default': { weekday: 10, weekend: 5 }
};

// Check if a date is weekend (Saturday or Sunday)
function isWeekend(date) {
  const day = date.getDay();
  return day === 0 || day === 6; // 0 = Sunday, 6 = Saturday
}

// Get expected activity count for user based on their profile and day type
function getExpectedActivityCount(profile, date) {
  const counts = WELLNESS_ACTIVITY_COUNTS[profile] || WELLNESS_ACTIVITY_COUNTS['default'];
  return isWeekend(date) ? counts.weekend : counts.weekday;
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
        
        // Get expected activity count based on profile and day type
        const expectedActivities = getExpectedActivityCount(wellnessProfile, yesterday);
        
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
    
    // Get expected activity count
    const expectedActivities = getExpectedActivityCount(wellnessProfile, targetDate);
    
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
