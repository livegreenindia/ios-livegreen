const express = require('express');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

module.exports = (db, authMiddleware) => {
  const router = express.Router();

  // Record happiness for the day
  router.post('/', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { score, date } = req.body;
    if (typeof score !== 'number' || score < 1 || score > 10) return res.status(400).json({ error: 'score 1-10 required' });
    const day = date || new Date().toISOString().slice(0, 10);
    try {
    console.log('HAPPINESS POST', { uid, score, date: day });
    // include uid in the stored document for easier per-user queries
    await db.collection('users').doc(uid).collection('happiness').doc(day).set({ uid, score, date: day, ts: FieldValue.serverTimestamp() });
      res.json({ ok: true });
    } catch (err) {
      console.error('HAPPINESS ERROR', { uid, score, date: day, error: err });
      res.status(500).json({ error: 'failed', details: err && err.message ? err.message : String(err) });
    }
  });

  // Aggregation endpoint for charting: query params range=week|month|year, startDate
  // Optional query param `uid` allows admins to request another user's aggregate data
  router.get('/aggregate', authMiddleware, async (req, res) => {
    let uid = req.query.uid || req.user.uid;
    // if requesting another user's data, require admin
    if (req.query.uid && req.query.uid !== req.user.uid) {
      if (!req.user || req.user.admin !== true) return res.status(403).json({ error: 'admin_required' });
    }
    const range = req.query.range || 'month';
    // determine start date
    const now = new Date();
    let start = new Date(now);
    if (range === 'week') start.setDate(now.getDate() - 7);
    else if (range === 'year') start.setFullYear(now.getFullYear() - 1);
    else start.setMonth(now.getMonth() - 1);
    const startStr = start.toISOString().slice(0, 10);
    try {
      const hapSnap = await db.collection('users').doc(uid).collection('happiness').where('date', '>=', startStr).orderBy('date').get();
      const hap = hapSnap.docs.map(d => d.data());

      // fetch completion percentages per day
      const compSnap = await db.collection('users').doc(uid).collection('completions').where('date', '>=', startStr).orderBy('date').get();
      const perDay = {};
      compSnap.docs.forEach(d => {
        const dt = d.data().date;
        perDay[dt] = (perDay[dt] || 0) + 1;
      });

      res.json({ happiness: hap, completionsPerDay: perDay });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  return router;
};
