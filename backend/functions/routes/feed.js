const express = require('express');
const admin = require('firebase-admin');

module.exports = (db, authMiddleware) => {
  const router = express.Router();

  // Create feed post (admin only) - inspiration message + optional image
  router.post('/', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { text, imageUrl } = req.body;
    if (!text && !imageUrl) return res.status(400).json({ error: 'text or image required' });

    try {
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.data();

      if (!userData || userData.role !== 'admin') {
        return res.status(403).json({
          error: 'forbidden',
          message: 'Only administrators can post to the inspiration feed',
        });
      }

      const authorName = req.user.name || userData.name || 'Admin';
      const authorPhoto = req.user.picture || userData.photoURL || null;

      const doc = await db.collection('feedPosts').add({
        uid,
        name: authorName,
        photoURL: authorPhoto,
        text: text || null,
        imageUrl: imageUrl || null,
        ts: admin.firestore.FieldValue.serverTimestamp(),
        likes: 0,
        commentsCount: 0,
      });
      res.json({ id: doc.id });
    } catch (err) {
      console.error('feed create error', err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Upload image (base64) - admin only - returns a downloadable URL
  router.post('/upload', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { filename, data } = req.body;
    if (!filename || !data) return res.status(400).json({ error: 'filename and data required' });

    try {
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.data();
      if (!userData || userData.role !== 'admin') {
        return res.status(403).json({ error: 'forbidden', message: 'Admin only' });
      }

      const bucket = admin.storage && admin.storage().bucket ? admin.storage().bucket() : null;
      if (!bucket) {
        return res.status(500).json({ error: 'storage_not_configured' });
      }

      const safeFilename = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
      const filePath = `feed/${Date.now()}_${safeFilename}`;
      const file = bucket.file(filePath);
      const buffer = Buffer.from(data, 'base64');

      const ext = safeFilename.includes('.') ? safeFilename.split('.').pop().toLowerCase() : '';
      let contentType = 'image/jpeg';
      if (ext === 'png') contentType = 'image/png';
      else if (ext === 'gif') contentType = 'image/gif';
      else if (ext === 'webp') contentType = 'image/webp';

      await file.save(buffer, {
        resumable: false,
        metadata: { contentType, cacheControl: 'public, max-age=31536000' },
      });

      try { await file.makePublic(); } catch (e) { console.warn('makePublic failed', e); }

      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
      res.json({ url: publicUrl });
    } catch (err) {
      console.error('feed upload error', err);
      res.status(500).json({ error: 'upload_failed', detail: err && err.message ? err.message : null });
    }
  });

  // List feed posts (all authenticated users can read)
  router.get('/', authMiddleware, async (req, res) => {
    try {
      const snap = await db.collection('feedPosts').orderBy('ts', 'desc').limit(50).get();
      const posts = [];
      for (const d of snap.docs) {
        const data = d.data();
        let commentsCount = 0;
        try {
          const commentsSnap = await d.ref.collection('comments').get();
          commentsCount = commentsSnap.size;
        } catch (e) {
          // ignore
        }
        posts.push({ id: d.id, commentsCount, ...data });
      }
      res.json({ posts });
    } catch (err) {
      console.error('feed list error', err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Like a feed post (toggle - all users)
  router.post('/:postId/like', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { postId } = req.params;
    try {
      const likeRef = db.collection('feedPosts').doc(postId).collection('likes').doc(uid);
      const likeDoc = await likeRef.get();
      if (likeDoc.exists) {
        // Unlike
        await likeRef.delete();
        await db.collection('feedPosts').doc(postId).update({
          likes: admin.firestore.FieldValue.increment(-1),
        });
        return res.json({ liked: false });
      }
      await likeRef.set({ uid, ts: admin.firestore.FieldValue.serverTimestamp() });
      await db.collection('feedPosts').doc(postId).update({
        likes: admin.firestore.FieldValue.increment(1),
      });
      res.json({ liked: true });
    } catch (err) {
      console.error('feed like error', err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Comment on feed post (all users)
  router.post('/:postId/comments', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { postId } = req.params;
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'text required' });
    try {
      const postRef = db.collection('feedPosts').doc(postId);
      const ref = postRef.collection('comments');
      const doc = await ref.add({
        uid,
        text,
        ts: admin.firestore.FieldValue.serverTimestamp(),
      });
      await postRef.update({ commentsCount: admin.firestore.FieldValue.increment(1) });
      res.json({ id: doc.id });
    } catch (err) {
      console.error('feed comment error', err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Get comments for a post
  router.get('/:postId/comments', authMiddleware, async (req, res) => {
    const { postId } = req.params;
    try {
      const snap = await db
        .collection('feedPosts')
        .doc(postId)
        .collection('comments')
        .orderBy('ts', 'asc')
        .limit(100)
        .get();
      const comments = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
      res.json({ comments });
    } catch (err) {
      console.error('feed comments error', err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Delete feed post (admin only)
  router.delete('/:postId', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { postId } = req.params;
    try {
      const userDoc = await db.collection('users').doc(uid).get();
      if (userDoc.data()?.role !== 'admin') {
        return res.status(403).json({ error: 'forbidden' });
      }
      await db.collection('feedPosts').doc(postId).delete();
      res.json({ deleted: true });
    } catch (err) {
      console.error('feed delete error', err);
      res.status(500).json({ error: 'failed' });
    }
  });

  return router;
};
