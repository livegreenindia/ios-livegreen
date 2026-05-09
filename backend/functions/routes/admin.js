const express = require('express');
const admin = require('firebase-admin');

module.exports = (db, authMiddleware, adminOnly) => {
  const router = express.Router();

  // List users (admin only) - merged Firebase Auth + Firestore data
  router.get('/users', authMiddleware, adminOnly, async (req, res) => {
    try {
      // Fetch all Auth users (handles pagination)
      const authUsers = [];
      let pageToken;
      do {
        const result = await admin.auth().listUsers(1000, pageToken);
        authUsers.push(...result.users);
        pageToken = result.pageToken;
      } while (pageToken);

      // Fetch all Firestore user documents
      const firestoreSnap = await db.collection('users').get();
      const firestoreMap = {};
      firestoreSnap.forEach(doc => {
        firestoreMap[doc.id] = doc.data();
      });

      // Merge
      const users = authUsers.map(u => {
        const fsData = firestoreMap[u.uid] || {};
        return {
          uid: u.uid,
          email: u.email || fsData.email || '',
          displayName: u.displayName || fsData.name || fsData.displayName || '',
          photoURL: u.photoURL || fsData.photoURL || '',
          role: fsData.role || (u.customClaims && u.customClaims.admin ? 'admin' : 'user'),
          isAdmin: fsData.role === 'admin' || (u.customClaims && u.customClaims.admin === true),
          feedAccess: fsData.feedAccess === true || fsData.role === 'admin',
          plan: fsData.plan || 'Free',
          createdAt: u.metadata.creationTime || null,
          lastSignIn: u.metadata.lastSignInTime || null,
        };
      });

      res.json({ users });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // View a user's data (admin only)
  router.get('/users/:uid/data', authMiddleware, adminOnly, async (req, res) => {
    const { uid } = req.params;
    try {
      const userRef = db.collection('users').doc(uid);
      const [hapSnap, compSnap, devSnap] = await Promise.all([
        userRef.collection('happiness').orderBy('date', 'desc').limit(100).get(),
        userRef.collection('completions').orderBy('date', 'desc').limit(500).get(),
        userRef.collection('deviceData').orderBy('ts', 'desc').limit(500).get(),
      ]);
      res.json({
        happiness: hapSnap.docs.map(d => d.data()),
        completions: compSnap.docs.map(d => d.data()),
        deviceData: devSnap.docs.map(d => d.data()),
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Send broadcast push notification to all users (admin only)
  router.post('/broadcast-notification', authMiddleware, adminOnly, async (req, res) => {
    const { title, body, imageUrl } = req.body;
    if (!title || !body) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    try {
      // Collect all FCM tokens from users collection
      const usersSnap = await db.collection('users').get();
      const tokens = [];
      usersSnap.forEach(doc => {
        const token = doc.data().fcmToken;
        if (token) tokens.push(token);
      });

      if (tokens.length === 0) {
        return res.json({ success: true, sent: 0, message: 'No FCM tokens found' });
      }

      // FCM sendEachForMulticast — max 500 per batch
      const BATCH = 500;
      let successCount = 0;
      let failureCount = 0;

      for (let i = 0; i < tokens.length; i += BATCH) {
        const batch = tokens.slice(i, i + BATCH);
        const message = {
          notification: { title, body, ...(imageUrl ? { imageUrl } : {}) },
          data: { type: 'broadcast', click_action: 'FLUTTER_NOTIFICATION_CLICK' },
          android: {
            priority: 'high',
            notification: { channelId: 'default', sound: 'default' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
          tokens: batch,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        successCount += response.successCount;
        failureCount += response.failureCount;

        // Remove invalid tokens from Firestore
        const staleTokenRemoves = [];
        response.responses.forEach((r, idx) => {
          if (!r.success && (
            r.error?.code === 'messaging/invalid-registration-token' ||
            r.error?.code === 'messaging/registration-token-not-registered'
          )) {
            staleTokenRemoves.push(batch[idx]);
          }
        });

        if (staleTokenRemoves.length > 0) {
          const tokenSet = new Set(staleTokenRemoves);
          const staleQuery = await db.collection('users')
            .where('fcmToken', 'in', staleTokenRemoves.slice(0, 10))
            .get();
          const batch2 = db.batch();
          staleQuery.forEach(doc => {
            if (tokenSet.has(doc.data().fcmToken)) {
              batch2.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
            }
          });
          await batch2.commit();
        }
      }

      console.log(`[BroadcastNotification] sent=${successCount} failed=${failureCount} total=${tokens.length}`);
      return res.json({ success: true, sent: successCount, failed: failureCount, total: tokens.length });
    } catch (err) {
      console.error('[BroadcastNotification] error', err);
      return res.status(500).json({ error: err.message || 'Failed to send notifications' });
    }
  });

  return router;
};
