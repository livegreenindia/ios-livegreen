const express = require('express');

module.exports = (db, authMiddleware, adminOnly) => {
  const router = express.Router();

  // List users (admin only) - basic listing using Firebase Auth listUsers
  router.get('/users', authMiddleware, adminOnly, async (req, res) => {
    try {
      // list up to 1000 users
      const list = await require('firebase-admin').auth().listUsers(1000);
      const users = list.users.map(u => ({ uid: u.uid, email: u.email, displayName: u.displayName, customClaims: u.customClaims }));
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

  return router;
};
