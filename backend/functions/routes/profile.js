const express = require('express');

module.exports = (db, authMiddleware, requireAuth) => {
  const router = express.Router();

  if (typeof requireAuth !== 'function') {
    requireAuth = (req, res, next) => {
      if (req.user && req.user.uid) return next();
      return res.status(401).json({ error: 'Unauthorized' });
    };
  }

  // Returns basic profile information for the signed-in user
  router.get('/', authMiddleware, requireAuth, async (req, res) => {
    try {
      const decoded = req.user || {};
      const uid = decoded.uid;
      // Try to read an application profile from Firestore if present
      let profile = {};
      try {
        const snap = await db.collection('users').doc(uid).get();
        if (snap.exists) profile = snap.data();
      } catch (e) {
        // ignore; fall back to token fields
        console.error('profile read error', e);
      }

      res.json({
        uid,
        email: decoded.email || profile.email || null,
        name: decoded.name || profile.name || null,
        photoURL: decoded.picture || profile.photoURL || null,
        profile,
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  return router;
};
