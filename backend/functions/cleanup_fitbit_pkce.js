const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Scheduled function to clean up expired PKCE verifiers
exports.cleanupFitbitPkce = functions.pubsub
  .schedule('every 15 minutes')
  .timeZone('UTC')
  .onRun(async (context) => {
    const db = admin.firestore();
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
    
    console.log('Running Fitbit PKCE cleanup...', { cutoffTime: fifteenMinutesAgo });
    
    try {
      const snapshot = await db.collection('fitbit_pkce')
        .where('created_at', '<', fifteenMinutesAgo)
        .get();
      
      if (snapshot.empty) {
        console.log('No expired PKCE verifiers to clean up');
        return null;
      }
      
      const batch = db.batch();
      snapshot.docs.forEach(doc => {
        console.log('Deleting expired PKCE verifier:', doc.id);
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`Successfully cleaned up ${snapshot.size} expired PKCE verifiers`);
      
      return { cleaned: snapshot.size };
    } catch (error) {
      console.error('Error cleaning up PKCE verifiers:', error);
      throw error;
    }
  });