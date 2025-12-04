const express = require('express');
const admin = require('firebase-admin');

module.exports = (db, authMiddleware, adminOnly) => {
  const router = express.Router();

  // Create organization (admin of org becomes owner)
  router.post('/', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: 'name required' });
    try {
      const orgRef = await db.collection('organizations').add({ name, owner: uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      // add member mapping
      await orgRef.collection('members').doc(uid).set({ role: 'owner', uid, joinedAt: admin.firestore.FieldValue.serverTimestamp() });
      res.json({ id: orgRef.id });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Add member to org (owner or admin in org)
  router.post('/:orgId/members', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { orgId } = req.params;
    const { memberUid, role } = req.body;
    if (!memberUid) return res.status(400).json({ error: 'memberUid required' });
    try {
      // check if requester is owner/admin
      const requester = await db.collection('organizations').doc(orgId).collection('members').doc(uid).get();
      if (!requester.exists) return res.status(403).json({ error: 'not member' });
      const requesterRole = requester.data().role;
      if (requesterRole !== 'owner' && requesterRole !== 'admin') return res.status(403).json({ error: 'insufficient role' });

      await db.collection('organizations').doc(orgId).collection('members').doc(memberUid).set({ uid: memberUid, role: role || 'member', joinedAt: admin.firestore.FieldValue.serverTimestamp() });
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // List org members
  router.get('/:orgId/members', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { orgId } = req.params;
    try {
      // check if requester is member
      const requester = await db.collection('organizations').doc(orgId).collection('members').doc(uid).get();
      if (!requester.exists) return res.status(403).json({ error: 'not member' });
      const snap = await db.collection('organizations').doc(orgId).collection('members').get();
      res.json({ members: snap.docs.map(d => d.data()) });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  return router;
};
