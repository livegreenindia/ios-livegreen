Functions README

Setup
1. Install dependencies:
   - cd functions; npm install
2. To run locally, install Firebase CLI and run emulators:
   - firebase emulators:start --only functions,firestore

Authentication
- The client (Flutter) should authenticate via Firebase Auth (Google/Facebook). The client must pass the ID token in Authorization header: "Bearer <idToken>".
- To create an admin: set custom claim `admin: true` for a user. Example:

  const admin = require('firebase-admin');
  admin.auth().setCustomUserClaims(uid, { admin: true });

Seed default activities
- From functions folder run: `node seedActivities.js` (ensure GOOGLE_APPLICATION_CREDENTIALS or firebase emulators)

Deployment steps
1. Ensure Firebase CLI is configured with your project: `firebase login` and `firebase use --add` to select project.
2. Deploy functions and rules:

   firebase deploy --only functions,firestore:rules

3. To set environment variables for functions (e.g., third-party provider credentials), use:

   firebase functions:config:set provider.client_id="YOUR_CLIENT_ID" provider.client_secret="YOUR_CLIENT_SECRET" provider.redirect_uri="https://.../oauth/callback"

   Then deploy again. In code you can access via `functions.config().provider.client_id` or set them as standard environment variables via the GCP console.

   For Razorpay specifically, you can set the keys using functions config or environment variables. Examples:

   # Using functions config
   firebase functions:config:set razorpay.key_id="rzp_test_..." razorpay.key_secret="your_secret"

   # Or set OS environment variables (useful for CI / local emulators):
   setx RAZORPAY_KEY_ID "rzp_test_..."
   setx RAZORPAY_KEY_SECRET "your_secret"

   In code you can read them via `functions.config().razorpay.key_id` / `functions.config().razorpay.key_secret`
   or via `process.env.RAZORPAY_KEY_ID` and `process.env.RAZORPAY_KEY_SECRET`.

Local testing notes
- When using the emulators, you'll need to provide service account credentials or run the emulator with `--import`/`--export` to persist data.
- Provider OAuth callbacks require a reachable redirect URI for third-party providers; consider using a tunnel (ngrok) for local testing and configure the redirect in the provider's developer console.

Flutter integration examples

- Authentication: use `firebase_auth` package (Google and Facebook providers). Obtain an ID token for authenticated calls:

   final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
   final headers = { 'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json' };

- Mark activity complete:

   POST https://<HOST>/activities/<activityId>/complete
   Headers: Authorization: Bearer <idToken>
   Body: { "date": "2025-10-01" }

- Record happiness:
   POST /happiness
   Body: { "score": 7 }

- Fetch series for chart:
   GET /summary/series?range=week
   Response: { series: [ { date: '2025-10-01', completionPercent: 57, happiness: 7 }, ... ] }

- Ingest device data (client-collected or via provider microservices):
      POST /devices/ingest
      Body: { device: '<provider>', metrics: { steps: 12345, hr: 60 }, timestamp: '2025-10-01T08:00:00Z' }

Security and privacy notes
- Provider tokens are stored under `users/{uid}/providers/{provider}` and are only writable by that user. Admins may read provider metadata for research following your internal privacy rules.



Wearable integrations
- The code contains stubs in `routes/devices.js` for ingesting device data. Full provider integrations (Fitbit, Apple, Samsung) are intentionally left as a separate integration task. We recommend building dedicated microservices to handle OAuth exchanges, token refresh, and webhooks, and then pushing normalized metrics into `users/{uid}/deviceData`.

Next phase: corporate organizations
- Plan: add `organizations` collection and a `members` subcollection mapping userIds to roles. Provide org-scoped activity tracking and admin roles at the org level.
