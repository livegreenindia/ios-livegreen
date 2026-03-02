const express = require('express');
const admin = require('firebase-admin');

module.exports = (db, authMiddleware) => {
  const router = express.Router();

  // Returns time series of { date, happiness, completionPercent }
  router.get('/series', authMiddleware, async (req, res) => {
    let uid = req.query.uid || req.user.uid;
    if (req.query.uid && req.query.uid !== req.user.uid) {
      if (!req.user || req.user.admin !== true) return res.status(403).json({ error: 'admin_required' });
    }
    const range = req.query.range || 'month';
    const now = new Date();
    let start = new Date(now);
    // For 'day' range, only return today's data
    if (range === 'day') {
      start = new Date(now);
      start.setHours(0, 0, 0, 0);
    } else if (range === 'week') {
      start.setDate(now.getDate() - 7);
    } else if (range === 'year') {
      start.setFullYear(now.getFullYear() - 1);
    } else {
      start.setMonth(now.getMonth() - 1);
    }
    const startStr = start.toISOString().slice(0, 10);

    try {
      // Fetch user profile to get wellness profile for expected activity count
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.exists ? userDoc.data() : {};
      const wellnessProfile = userData.wellness_profile || 'default';

      // Fetch happiness entries and existing dailySummaries in parallel
      // Note: Completions are stored with 'date' field (YYYY-MM-DD format)
      const [hapSnap, summarySnap, completionsSnap] = await Promise.all([
        db.collection('users').doc(uid).collection('happiness').where('date', '>=', startStr).orderBy('date').get(),
        db.collection('users').doc(uid).collection('dailySummaries').where('date', '>=', startStr).orderBy('date').get(),
        db.collection('users').doc(uid).collection('completions').where('date', '>=', startStr).get(),
      ]);

      // happiness map keyed by date (doc id is date)
      const hapMap = {};
      hapSnap.docs.forEach(d => { hapMap[d.id] = d.data().score; });

      // summaries map keyed by date
      const summaryMap = {};
      summarySnap.docs.forEach(d => { const data = d.data(); summaryMap[data.date] = data; });

      // compute completions per-day (count and sum weights)
      const compCountByDate = {}; // raw count
      completionsSnap.docs.forEach(d => {
        const data = d.data();
        const dt = data.date; // Completions use 'date' field
        if (!dt) return; // Skip if no date field
        compCountByDate[dt] = (compCountByDate[dt] || 0) + 1;
      });

      // count activities directly from Firestore; this list contains only
      // work‑related items and is shared by every user.  we compute it once
      // and reuse when building the series.
      const activitySnap = await db.collection('activities').get();
      const globalExpectedCount = activitySnap.size;

      // build date list from start to now (inclusive), in ascending order
      const series = [];
      const cur = new Date(start);
      const end = new Date(now);
      while (cur <= end) {
        const iso = cur.toISOString().slice(0,10);
        const count = compCountByDate[iso] || 0;
        
        if (summaryMap[iso]) {
          // Use pre-computed daily summary (most accurate)
          const s = summaryMap[iso];
          series.push({ 
            date: iso, 
            completionPercent: s.completionPercent || 0, 
            happiness: hapMap[iso] || null, 
            count,
            expectedCount: s.expectedCount || globalExpectedCount,
          });
        } else {
          // Calculate completion percent using global expected count
          const percent = globalExpectedCount === 0 ? 0 : Math.min(100, Math.round((count / globalExpectedCount) * 100));
          series.push({ 
            date: iso, 
            completionPercent: percent, 
            happiness: hapMap[iso] || null, 
            count,
            expectedCount: globalExpectedCount,
          });
        }
        cur.setDate(cur.getDate() + 1);
      }

      res.json({ series });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  return router;
};
