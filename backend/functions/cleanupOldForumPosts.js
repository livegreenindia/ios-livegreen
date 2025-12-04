const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Deletes forum posts older than 15 days. Runs once daily.
exports.cleanupOldForumPosts = functions.pubsub.schedule('0 3 * * *').timeZone('UTC').onRun(async (context) => {
  const db = admin.firestore();
  const storage = admin.storage && admin.storage().bucket ? admin.storage().bucket() : null;
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 15);
  console.log('cleanupOldForumPosts running, cutoff=', cutoff.toISOString());

  try {
    const snap = await db.collection('forumPosts').where('ts', '<', admin.firestore.Timestamp.fromDate(cutoff)).get();
    console.log('Found', snap.size, 'old forum posts');
    for (const doc of snap.docs) {
      const data = doc.data();
      const docId = doc.id;
      try {
        // If the post had an imageUrl pointing to storage.googleapis.com, attempt deleting the file
        if (data.imageUrl && storage) {
          try {
            const url = data.imageUrl.toString();
            // expect format https://storage.googleapis.com/<bucket>/<path>
            const parts = url.split('/');
            const idx = parts.indexOf(storage.name);
            let path = null;
            if (idx >= 0) {
              path = parts.slice(idx + 1).join('/');
            } else {
              // fallback: last two segments may be bucket and path
              path = parts.slice(3).join('/');
            }
            if (path) {
              const file = storage.file(path);
              await file.delete().catch(e => { console.warn('failed to delete storage file', path, e && e.message); });
            }
          } catch (e) { console.warn('error deleting image for post', docId, e && e.message); }
        }

        // Delete subcollections (comments, likes)
        const commentsRef = db.collection('forumPosts').doc(docId).collection('comments');
        const commentsSnap = await commentsRef.get();
        for (const c of commentsSnap.docs) {
          await c.ref.delete().catch(() => {});
        }

        const likesRef = db.collection('forumPosts').doc(docId).collection('likes');
        const likesSnap = await likesRef.get();
        for (const l of likesSnap.docs) {
          await l.ref.delete().catch(() => {});
        }

        // Finally delete the post document
        await db.collection('forumPosts').doc(docId).delete();
        console.log('Deleted old post', docId);
      } catch (inner) {
        console.error('Error deleting post', docId, inner && inner.message);
      }
    }
  } catch (err) {
    console.error('cleanupOldForumPosts failed', err && err.stack ? err.stack : err);
  }
  return null;
});
