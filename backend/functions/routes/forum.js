const express = require('express');
const admin = require('firebase-admin');

module.exports = (db, authMiddleware) => {
  const router = express.Router();

  // Create post (text + optional image URL) - Admin only
  router.post('/', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { text, imageUrl } = req.body;
    if (!text && !imageUrl) return res.status(400).json({ error: 'text or image required' });
    
    try {
      // Check if user is admin
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.data();
      
      if (!userData || userData.role !== 'admin') {
        return res.status(403).json({ 
          error: 'forbidden', 
          message: 'Only administrators can create posts' 
        });
      }

      // Try to enrich post with author name and photo from token if available
      const authorName = req.user.name || null;
      const authorPhoto = req.user.picture || null;
      const doc = await db.collection('forumPosts').add({
        uid,
        name: authorName,
        photoURL: authorPhoto,
        text: text || null,
        imageUrl: imageUrl || null,
        ts: admin.firestore.FieldValue.serverTimestamp(),
        likes: 0,
      });
      res.json({ id: doc.id });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Upload image (base64) -> returns a downloadable URL
  // Expects { filename, data } where data is base64 (no data: prefix)
  router.post('/upload', authMiddleware, async (req, res) => {
    const { filename, data } = req.body;
    if (!filename || !data) return res.status(400).json({ error: 'filename and data required' });
    try {
      const bucket = admin.storage && admin.storage().bucket ? admin.storage().bucket() : null;
      if (!bucket) {
        console.error('Storage bucket not configured');
        return res.status(500).json({ error: 'storage_not_configured' });
      }

      // Sanitize filename and build a stable path
      const safeFilename = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
      const filePath = `forum/${Date.now()}_${safeFilename}`;
      const file = bucket.file(filePath);

      const buffer = Buffer.from(data, 'base64');

      // Determine contentType: prefer explicit header, otherwise guess from extension
      let contentType = (req.headers['content-type'] || '').toString();
      if (contentType.isEmpty == null && contentType == '') {
        // naive guess from extension
        const ext = (safeFilename.split('.').length > 1) ? safeFilename.split('.').pop().toLowerCase() : '';
        switch (ext) {
          case 'png': contentType = 'image/png'; break;
          case 'gif': contentType = 'image/gif'; break;
          case 'webp': contentType = 'image/webp'; break;
          case 'jpg':
          case 'jpeg':
          default:
            contentType = 'image/jpeg';
        }
      }

      // Save with cache-control to enable client/CDN caching
      await file.save(buffer, { resumable: false, metadata: { contentType, cacheControl: 'public, max-age=31536000' } });

      // Make the file publicly readable (best-effort)
      try {
        await file.makePublic();
      } catch (e) {
        console.warn('makePublic failed, continuing', e);
      }

      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;
      res.json({ url: publicUrl });
    } catch (err) {
      console.error('upload error', err && err.stack ? err.stack : err);
      // expose some diagnostic info for deploy-time testing, but keep message stable for clients
      res.status(500).json({ error: 'upload_failed', detail: (err && err.message) ? err.message : null });
    }
  });

  // List posts (paged)
  router.get('/', async (req, res) => {
    try {
      const snap = await db.collection('forumPosts').orderBy('ts', 'desc').limit(50).get();
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
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Comment on post
  router.post('/:postId/comments', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { postId } = req.params;
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: 'text required' });
    try {
      const postRef = db.collection('forumPosts').doc(postId);
      const ref = postRef.collection('comments');
      const doc = await ref.add({ uid, text, ts: admin.firestore.FieldValue.serverTimestamp() });
      // Atomically increment commentsCount on the parent post document
      await postRef.update({ commentsCount: admin.firestore.FieldValue.increment(1) });
      res.json({ id: doc.id });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  // Like a post
  router.post('/:postId/like', authMiddleware, async (req, res) => {
    const uid = req.user.uid;
    const { postId } = req.params;
    try {
      const likeRef = db.collection('forumPosts').doc(postId).collection('likes').doc(uid);
      const likeDoc = await likeRef.get();
      if (likeDoc.exists) return res.json({ liked: true });
      await likeRef.set({ uid, ts: admin.firestore.FieldValue.serverTimestamp() });
      await db.collection('forumPosts').doc(postId).update({ likes: admin.firestore.FieldValue.increment(1) });
      res.json({ liked: true });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'failed' });
    }
  });

  return router;
};
