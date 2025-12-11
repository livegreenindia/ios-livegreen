const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

admin.initializeApp();
const db = admin.firestore();

// Startup debug log to help diagnose deployment/router loading issues
console.log('API startup', { NODE_ENV: process.env.NODE_ENV, DISABLE_AUTH: process.env.DISABLE_AUTH });

const app = express();
app.use(cors({ origin: true }));
app.use(bodyParser.json());

// Auth middleware: verify Firebase ID token and attach user to req
async function authMiddleware(req, res, next) {
  // For production we require a valid Authorization header. If you need a
  // development bypass, set DISABLE_AUTH explicitly in your local environment
  // (NOT recommended on deployed environments).
  if (process.env.DISABLE_AUTH === 'true' && process.env.NODE_ENV !== 'production') {
    console.warn('DISABLE_AUTH is enabled (development only)');
    req.user = { uid: process.env.DEV_UID || 'dev-user' };
    return next();
  }

  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    console.warn('Auth header missing or malformed', { auth: !!auth });
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const idToken = auth.split('Bearer ')[1];
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    req.user = decoded;
    // Helpful debug log to correlate incoming requests with token subject
    console.log('Auth success', { uid: decoded.uid, aud: decoded.aud || decoded.firebase && decoded.firebase.sign_in_provider });
    next();
  } catch (err) {
    console.error('Auth error verifying token', err && err.code ? err.code : err);
    res.status(401).json({ error: 'Invalid token' });
  }
}

// Require-auth middleware: use this on routes that must have a valid signed-in user.
function requireAuth(req, res, next) {
  if (req.user && req.user.uid) return next();
  return res.status(401).json({ error: 'Unauthorized' });
}

// Admin middleware
function adminOnly(req, res, next) {
  if (req.user && req.user.admin === true) return next();
  return res.status(403).json({ error: 'Admin only' });
}

// Routes
const activitiesRouter = require('./routes/activities')(db, authMiddleware, adminOnly);
const happinessRouter = require('./routes/happiness')(db, authMiddleware);
const forumRouter = require('./routes/forum')(db, authMiddleware);
const profileRouter = require('./routes/profile')(db, authMiddleware, requireAuth);
const devicesRouter = require('./routes/devices')(db, authMiddleware);
const adminRouter = require('./routes/admin')(db, authMiddleware, adminOnly);
const summaryRouter = require('./routes/summary')(db, authMiddleware);
const organizationsRouter = require('./routes/organizations')(db, authMiddleware, adminOnly);
const paymentsRouter = require('./routes/payments')(db, authMiddleware, requireAuth);
const fitbitRouter = require('./routes/fitbit')(db, authMiddleware, requireAuth);

app.use('/activities', activitiesRouter);
app.use('/happiness', happinessRouter);
app.use('/forum', forumRouter);
app.use('/profile', profileRouter);
app.use('/devices', devicesRouter);
app.use('/admin', adminRouter);
app.use('/summary', summaryRouter);
app.use('/organizations', organizationsRouter);
app.use('/payments', paymentsRouter);
app.use('/fitbit', fitbitRouter);

// Debug routes - only expose small helpers when not in production
if (process.env.NODE_ENV !== 'production') {
  app.get('/debug/whoami', authMiddleware, (req, res) => {
    // return the decoded token claims to help debug auth from the client
    return res.json({ user: req.user || null });
  });
}

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Export main API function
exports.api = functions.https.onRequest(app);

// Register scheduled functions with error handling
try {
  const { computeDailySummary } = require('./computeDailySummary');
  if (computeDailySummary) {
    exports.computeDailySummary = computeDailySummary;
    console.log('computeDailySummary registered successfully');
  }
} catch (e) {
  console.warn('computeDailySummary not available:', e.message);
}

try {
  const { cleanupOldForumPosts } = require('./cleanupOldForumPosts');
  if (cleanupOldForumPosts) {
    exports.cleanupOldForumPosts = cleanupOldForumPosts;
    console.log('cleanupOldForumPosts registered successfully');
  }
} catch (e) {
  console.warn('cleanupOldForumPosts not available:', e.message);
}

// Export Fitbit PKCE cleanup scheduled function
try {
  const { cleanupFitbitPkce } = require('./cleanup_fitbit_pkce');
  if (cleanupFitbitPkce) {
    exports.cleanupFitbitPkce = cleanupFitbitPkce;
    console.log('cleanupFitbitPkce registered successfully');
  }
} catch (e) {
  console.error('Failed to register cleanupFitbitPkce:', e.message);
}

// Export activity reminder notification scheduler (8 PM evening)
try {
  const { sendActivityReminders } = require('./sendActivityReminders');
  if (sendActivityReminders) {
    exports.sendActivityReminders = sendActivityReminders;
    console.log('sendActivityReminders registered successfully');
  }
} catch (e) {
  console.error('Failed to register sendActivityReminders:', e.message);
}

// Export morning reminder notification scheduler (10 AM)
try {
  const { sendMorningReminders } = require('./sendMorningReminders');
  if (sendMorningReminders) {
    exports.sendMorningReminders = sendMorningReminders;
    console.log('sendMorningReminders registered successfully');
  }
} catch (e) {
  console.error('Failed to register sendMorningReminders:', e.message);
}

// Export social media usage checker (every 3 hours)
try {
  const { checkSocialMediaUsage } = require('./checkSocialMediaUsage');
  if (checkSocialMediaUsage) {
    exports.checkSocialMediaUsage = checkSocialMediaUsage;
    console.log('checkSocialMediaUsage registered successfully');
  }
} catch (e) {
  console.error('Failed to register checkSocialMediaUsage:', e.message);
}

// Export midday reminder (1 PM - selective for streak protection & nudges)
try {
  const { sendMiddayReminders } = require('./sendMiddayReminders');
  if (sendMiddayReminders) {
    exports.sendMiddayReminders = sendMiddayReminders;
    console.log('sendMiddayReminders registered successfully');
  }
} catch (e) {
  console.error('Failed to register sendMiddayReminders:', e.message);
}

// Export real-time achievement notifications (on activity completion)
try {
  const { onActivityCompletion } = require('./achievementNotifications');
  if (onActivityCompletion) {
    exports.onActivityCompletion = onActivityCompletion;
    console.log('onActivityCompletion registered successfully');
  }
} catch (e) {
  console.error('Failed to register onActivityCompletion:', e.message);
}

// Export club notification functions
try {
  const {
    notifyAdminOnClubCreation,
    notifyCreatorOnClubApproval,
    notifyCreatorOnClubRejection,
    updateClubActivityCount,
    cleanupArchivedClubs,
    getClubStatistics,
  } = require('./clubNotifications');
  
  if (notifyAdminOnClubCreation) {
    exports.notifyAdminOnClubCreation = notifyAdminOnClubCreation;
    console.log('notifyAdminOnClubCreation registered successfully');
  }
  if (notifyCreatorOnClubApproval) {
    exports.notifyCreatorOnClubApproval = notifyCreatorOnClubApproval;
    console.log('notifyCreatorOnClubApproval registered successfully');
  }
  if (notifyCreatorOnClubRejection) {
    exports.notifyCreatorOnClubRejection = notifyCreatorOnClubRejection;
    console.log('notifyCreatorOnClubRejection registered successfully');
  }
  if (updateClubActivityCount) {
    exports.updateClubActivityCount = updateClubActivityCount;
    console.log('updateClubActivityCount registered successfully');
  }
  if (cleanupArchivedClubs) {
    exports.cleanupArchivedClubs = cleanupArchivedClubs;
    console.log('cleanupArchivedClubs registered successfully');
  }
  if (getClubStatistics) {
    exports.getClubStatistics = getClubStatistics;
    console.log('getClubStatistics registered successfully');
  }
} catch (e) {
  console.error('Failed to register club functions:', e.message);
}

// Admin setup endpoint (one-time use, should be removed after setup)
app.post('/setup-admin', async (req, res) => {
  const { email, secretKey } = req.body;
  
  // Simple secret key protection - change this!
  if (secretKey !== 'livegreen-setup-2025') {
    return res.status(403).json({ error: 'Invalid secret key' });
  }
  
  try {
    // Get user by email from Firebase Auth
    const userRecord = await admin.auth().getUserByEmail(email);
    const uid = userRecord.uid;
    
    // Create or update user document with admin role
    await db.collection('users').doc(uid).set({
      email: email,
      role: 'admin',
      isAdmin: true,
      displayName: userRecord.displayName || email.split('@')[0],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    res.json({ 
      success: true, 
      message: `Admin role set for ${email}`,
      uid: uid 
    });
  } catch (error) {
    console.error('Setup admin error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Export the Express app for deploy_index.js to wrap
module.exports = app;

// If run directly with `node index.js`, start an HTTP server for quick local testing
if (require.main === module) {
  const port = process.env.PORT || 5001;
  app.listen(port, () => {
    // eslint-disable-next-line no-console
    console.log(`Dev server listening on http://127.0.0.1:${port}`);
  });
}