const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Cloud Function: Send notification when new club is created (for admins)
 * Triggered on club creation with pending status
 */
exports.notifyAdminOnClubCreation = functions.firestore
  .document('clubs/{clubId}')
  .onCreate(async (snap, context) => {
    try {
      const club = snap.data();

      // Only notify for pending clubs
      if (club.status !== 'pending') {
        return;
      }

      // Get admin users
      const adminsSnapshot = await db
        .collection('users')
        .where('role', '==', 'admin')
        .get();

      if (adminsSnapshot.empty) {
        console.log('No admin users found to notify');
        return;
      }

      const notificationPromises = [];
      const adminTokens = [];

      // Collect admin tokens
      for (const adminDoc of adminsSnapshot.docs) {
        const adminData = adminDoc.data();
        if (adminData.fcmToken) {
          adminTokens.push(adminData.fcmToken);
        }
      }

      // Send notifications to all admin devices
      if (adminTokens.length > 0) {
        const payload = {
          notification: {
            title: '🏕️ New Club for Review',
            body: `"${club.name}" awaits approval`,
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
          data: {
            clubId: snap.id,
            type: 'club_pending_review',
            screen: 'admin_club_approval',
          },
        };

        for (const token of adminTokens) {
          notificationPromises.push(
            messaging
              .sendToDevice(token, payload)
              .catch((error) => console.error(`Failed to send notification to ${token}:`, error))
          );
        }
      }

      await Promise.all(notificationPromises);
      console.log(`Notified admins about new club: ${snap.id}`);
    } catch (error) {
      console.error('Error in notifyAdminOnClubCreation:', error);
      throw error;
    }
  });

/**
 * Cloud Function: Send notification when club is approved
 * Triggered on club approval
 */
exports.notifyCreatorOnClubApproval = functions.firestore
  .document('clubs/{clubId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Only process status changes from pending to approved
      if (beforeData.status !== 'pending' || afterData.status !== 'approved') {
        return;
      }

      // Get creator's data
      const creatorDoc = await db.collection('users').doc(afterData.creatorId).get();

      if (!creatorDoc.exists) {
        console.log(`Creator ${afterData.creatorId} not found`);
        return;
      }

      const creator = creatorDoc.data();
      if (!creator.fcmToken) {
        console.log(`Creator ${afterData.creatorId} has no FCM token`);
        return;
      }

      // Send approval notification
      const payload = {
        notification: {
          title: '✅ Club Approved!',
          body: `Your club "${afterData.name}" has been approved and is now live`,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        data: {
          clubId: context.params.clubId,
          type: 'club_approved',
          screen: 'club_details',
        },
      };

      await messaging.sendToDevice(creator.fcmToken, payload);
      console.log(`Notified creator ${afterData.creatorId} about approval of club ${context.params.clubId}`);
    } catch (error) {
      console.error('Error in notifyCreatorOnClubApproval:', error);
      // Don't throw - we don't want to fail the update if notification fails
    }
  });

/**
 * Cloud Function: Send notification when club is rejected
 * Triggered on club rejection
 */
exports.notifyCreatorOnClubRejection = functions.firestore
  .document('clubs/{clubId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Only process status changes from pending to rejected
      if (beforeData.status !== 'pending' || afterData.status !== 'rejected') {
        return;
      }

      // Get creator's data
      const creatorDoc = await db.collection('users').doc(afterData.creatorId).get();

      if (!creatorDoc.exists) {
        console.log(`Creator ${afterData.creatorId} not found`);
        return;
      }

      const creator = creatorDoc.data();
      if (!creator.fcmToken) {
        console.log(`Creator ${afterData.creatorId} has no FCM token`);
        return;
      }

      // Send rejection notification
      const payload = {
        notification: {
          title: '❌ Club Not Approved',
          body: `Your club "${afterData.name}" requires some changes`,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        data: {
          clubId: context.params.clubId,
          type: 'club_rejected',
          rejectionReason: afterData.rejectionReason || '',
          screen: 'my_clubs',
        },
      };

      await messaging.sendToDevice(creator.fcmToken, payload);
      console.log(
        `Notified creator ${afterData.creatorId} about rejection of club ${context.params.clubId}`
      );
    } catch (error) {
      console.error('Error in notifyCreatorOnClubRejection:', error);
      // Don't throw - we don't want to fail the update if notification fails
    }
  });

/**
 * Cloud Function: Update activity count when activity is created
 * Triggered on activity creation
 */
exports.updateClubActivityCount = functions.firestore
  .document('clubs/{clubId}/activities/{activityId}')
  .onCreate(async (snap, context) => {
    try {
      await db.collection('clubs').doc(context.params.clubId).update({
        activityCount: admin.firestore.FieldValue.increment(1),
      });

      console.log(
        `Updated activity count for club ${context.params.clubId}`
      );
    } catch (error) {
      console.error('Error in updateClubActivityCount:', error);
      throw error;
    }
  });

/**
 * Cloud Function: Clean up clubs scheduled for deletion
 * Can be triggered on schedule (e.g., daily)
 */
exports.cleanupArchivedClubs = functions.pubsub
  .schedule('every 7 days')
  .onRun(async (context) => {
    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

      // Find archived clubs older than 30 days
      const archivedClubs = await db
        .collection('clubs')
        .where('status', '==', 'archived')
        .where('updatedAt', '<', thirtyDaysAgo)
        .limit(100)
        .get();

      let deletedCount = 0;

      for (const clubDoc of archivedClubs.docs) {
        // Delete activities
        const activities = await clubDoc.ref.collection('activities').get();
        for (const activityDoc of activities.docs) {
          await activityDoc.ref.delete();
        }

        // Delete members
        const members = await clubDoc.ref.collection('members').get();
        for (const memberDoc of members.docs) {
          await memberDoc.ref.delete();
        }

        // Delete club
        await clubDoc.ref.delete();
        deletedCount++;
      }

      console.log(`Cleaned up ${deletedCount} archived clubs`);
      return null;
    } catch (error) {
      console.error('Error in cleanupArchivedClubs:', error);
      throw error;
    }
  });

/**
 * HTTP Callable Function: Get club statistics for admin dashboard
 */
exports.getClubStatistics = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is admin
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can access this');
    }

    const clubsSnapshot = await db.collection('clubs').get();
    const clubs = clubsSnapshot.docs.map((doc) => doc.data());

    const stats = {
      totalClubs: clubs.length,
      approvedClubs: clubs.filter((c) => c.status === 'approved').length,
      pendingClubs: clubs.filter((c) => c.status === 'pending').length,
      rejectedClubs: clubs.filter((c) => c.status === 'rejected').length,
      archivedClubs: clubs.filter((c) => c.status === 'archived').length,
      totalMembers: clubs.reduce((sum, c) => sum + (c.memberCount || 0), 0),
      totalActivities: clubs.reduce((sum, c) => sum + (c.activityCount || 0), 0),
    };

    return stats;
  } catch (error) {
    console.error('Error in getClubStatistics:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get statistics');
  }
});
