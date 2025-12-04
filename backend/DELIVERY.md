Delivery checklist

Contents to hand over
- All source code in this repo (functions/ and top-level READMEs)
- `firestore.rules` and `firestore.indexes.json`
- Seed script: `functions/seedActivities.js`

Pre-deployment checklist
1. Create a Firebase project and enable Firestore and Cloud Functions.
2. Create a service account for local admin tasks (if needed) and set `GOOGLE_APPLICATION_CREDENTIALS` when running scripts locally.
3. Configure Fitbit (or other provider) credentials in environment or functions config.

Deployment steps
1. From repo root:
   cd functions
   npm install
2. Deploy rules and functions:
   firebase deploy --only functions,firestore:rules

Post-deploy
- Run `node seedActivities.js` (or use emulator data) to add default activities.
- Set admin users using Admin SDK:
  const admin = require('firebase-admin');
  admin.auth().setCustomUserClaims(uid, { admin: true });

Notes about credentials
- We cannot include service account keys in the repository. Provide your own service account JSON for server-side operations if not using emulators.
- For Fitbit integration, set env vars or function config for `fitbit.client_id`, `fitbit.client_secret`, `fitbit.redirect_uri`.

Support and next-phase
- To add corporate analytics and organization-wide dashboards, we recommend adding organization-scoped activity assignments and scheduled aggregation functions per organization.
