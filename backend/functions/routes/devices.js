const express = require('express');
const admin = require('firebase-admin');
// node-fetch removed since Fitbit flows are disabled

module.exports = (db, authMiddleware) => {
  const router = express.Router();

  // Ingest device data for a user (e.g., steps, heart_rate) - clients or webhooks post here
  router.post('/ingest', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { device, metrics, timestamp } = req.body; // metrics: { steps: 123, hr: 60 }
    if (!device || !metrics) return res.status(400).json({ error: 'device and metrics required' });
    const ts = timestamp || new Date().toISOString();
    try {
      const doc = await db.collection('users').doc(uid).collection('deviceData').add({ device, metrics, ts, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      res.json({ id: doc.id });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Get aggregated device metrics for charting
  router.get('/aggregate', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { metric = 'steps', range = 'month' } = req.query;
    // simple aggregation: sum per day over range
    const now = new Date();
    const start = new Date(now);
    if (range === 'week') start.setDate(now.getDate() - 7);
    else if (range === 'year') start.setFullYear(now.getFullYear() - 1);
    else start.setMonth(now.getMonth() - 1);
    const startStr = start.toISOString();
    try {
      const snap = await db.collection('users').doc(uid).collection('deviceData').where('ts', '>=', startStr).get();
      const perDay = {};
      snap.docs.forEach(d => {
        const data = d.data();
        const day = data.ts.slice(0, 10);
        const val = data.metrics && data.metrics[metric] ? data.metrics[metric] : 0;
        perDay[day] = (perDay[day] || 0) + val;
      });
      res.json({ metric, perDay });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Fitbit integration removed. Re-enable via a dedicated provider service if needed.

  return router;
};
