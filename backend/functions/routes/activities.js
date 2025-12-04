const express = require('express');
const admin = require('firebase-admin');

module.exports = (db, authMiddleware, adminOnly) => {
  const router = express.Router();

  // Get list of activities (public). If Authorization Bearer token is present and valid,
  // include `completed: true` for activities the user completed for the given date.
  router.get('/', async (req, res) => {
    try {
      const snap = await db.collection('activities').orderBy('name').get();
      const activities = snap.docs.map(d => ({ id: d.id, ...d.data() }));

      // Optional: if client provides Authorization header, try to verify and include per-activity completed flag
      let uid = null;
      const auth = req.headers.authorization;
      if (auth && auth.startsWith('Bearer ')) {
        const idToken = auth.split('Bearer ')[1];
        try {
          const decoded = await admin.auth().verifyIdToken(idToken);
          uid = decoded.uid;
        } catch (err) {
          // invalid token: ignore and return public activities without completed flag
          console.warn('Invalid token while trying to compute per-activity completion flag');
        }
      }

      if (uid) {
        const date = req.query.date || new Date().toISOString().slice(0,10);
        const compSnap = await db.collection('users').doc(uid).collection('completions').where('date', '==', date).get();
        const completedSet = new Set(compSnap.docs.map(d => d.data().activityId));
        const enriched = activities.map(a => ({ ...a, completed: completedSet.has(a.id) }));
        return res.json({ activities: enriched });
      }

      res.json({ activities });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Admin: create or update activity
  router.post('/', authMiddleware, adminOnly, async (req, res) => {
    const { id, name, weight } = req.body;
    if (!name) return res.status(400).json({ error: 'name required' });
    try {
      if (id) {
        await db.collection('activities').doc(id).set({ name, weight }, { merge: true });
        return res.json({ id });
      }
      const doc = await db.collection('activities').add({ name, weight: weight || 1 });
      res.json({ id: doc.id });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // User: mark activity completion for today (server-side dedupe by user/activity/localDate)
  // Supports both regular activities from 'activities' collection and wellness activities (prefixed with 'wellness_')
  router.post('/:activityId/complete', authMiddleware, async (req, res) => {
    const { activityId } = req.params;
    const uid = req.user.uid;
    // Prefer client-provided localDate (YYYY-MM-DD) when available to respect user's timezone
    const clientLocalDate = req.body.localDate;
    const isoDate = req.body.date || new Date().toISOString();
    const date = clientLocalDate || isoDate.slice(0, 10);
    // Client can provide weight for wellness activities
    const clientWeight = req.body.weight;

    try {
      // Determine weight: prefer client-provided weight, then lookup from activities collection, then default to 1
      let weight = 1;
      const isWellnessActivity = activityId.startsWith('wellness_');
      
      if (clientWeight !== undefined && clientWeight !== null) {
        // Use client-provided weight (wellness activities send this)
        weight = Number(clientWeight) || 1;
      } else if (!isWellnessActivity) {
        // Only lookup weight for non-wellness activities (they exist in activities collection)
        const aDoc = await db.collection('activities').doc(activityId).get();
        weight = (aDoc.exists && aDoc.data() && aDoc.data().weight) ? aDoc.data().weight : 1;
      }

      const docId = `${date}_${activityId}`;
      const ref = db.collection('users').doc(uid).collection('completions').doc(docId);
      const existing = await ref.get();
      if (existing.exists) {
        // Duplicate completion for this user/activity/localDate — reject gracefully
        return res.status(409).json({ error: 'already_completed', date, activityId });
      }

      // Include uid in the completion record to make cross-user queries possible
      // Also include isWellnessActivity flag for analytics
      await ref.set({ 
        uid, 
        activityId, 
        date, 
        completed: true, 
        weight, 
        isWellnessActivity,
        ts: admin.firestore.FieldValue.serverTimestamp() 
      });
      res.json({ ok: true });
    } catch (err) {
      console.error('Error completing activity:', err);
      res.status(500).json({ error: 'failed', message: err.message });
    }
  });

  return router;
};
