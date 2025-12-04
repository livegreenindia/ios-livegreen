// Small explicit deploy entry point to help firebase discover functions exports
const app = require('./index');
const functions = require('firebase-functions');

// Export named function "api" same as index.js
exports.api = functions.https.onRequest(app);

console.log('deploy_index loaded');

// A tiny public health-check function used for smoke tests. This is separate
// from the main `api` Express app so we can safely make it publicly invokable
// without exposing the primary API surface.
exports.healthCheck = functions.https.onRequest((req, res) => {
	res.json({ status: 'ok', time: new Date().toISOString() });
});

// Export scheduled notification functions
try {
  const { cleanupOldForumPosts } = require('./cleanupOldForumPosts');
  if (cleanupOldForumPosts) {
    exports.cleanupOldForumPosts = cleanupOldForumPosts;
  }
} catch (e) {
  console.error('Failed to export cleanupOldForumPosts:', e.message);
}

try {
  const { cleanupFitbitPkce } = require('./cleanup_fitbit_pkce');
  if (cleanupFitbitPkce) {
    exports.cleanupFitbitPkce = cleanupFitbitPkce;
  }
} catch (e) {
  console.error('Failed to export cleanupFitbitPkce:', e.message);
}

try {
  const { sendActivityReminders } = require('./sendActivityReminders');
  if (sendActivityReminders) {
    exports.sendActivityReminders = sendActivityReminders;
  }
} catch (e) {
  console.error('Failed to export sendActivityReminders:', e.message);
}

try {
  const { sendMorningReminders } = require('./sendMorningReminders');
  if (sendMorningReminders) {
    exports.sendMorningReminders = sendMorningReminders;
  }
} catch (e) {
  console.error('Failed to export sendMorningReminders:', e.message);
}

try {
  const { checkSocialMediaUsage } = require('./checkSocialMediaUsage');
  if (checkSocialMediaUsage) {
    exports.checkSocialMediaUsage = checkSocialMediaUsage;
  }
} catch (e) {
  console.error('Failed to export checkSocialMediaUsage:', e.message);
}

try {
  const { sendMiddayReminders } = require('./sendMiddayReminders');
  if (sendMiddayReminders) {
    exports.sendMiddayReminders = sendMiddayReminders;
  }
} catch (e) {
  console.error('Failed to export sendMiddayReminders:', e.message);
}

try {
  const { onActivityCompletion } = require('./achievementNotifications');
  if (onActivityCompletion) {
    exports.onActivityCompletion = onActivityCompletion;
  }
} catch (e) {
  console.error('Failed to export onActivityCompletion:', e.message);
}

// Build stamp to force redeploy when package.json changes
console.log('deploy_index buildStamp: 2025-12-03T12:00:00Z');
