Firebase backend for LiveGreen Flutter app

This repository contains a Firebase Cloud Functions-based backend and Firestore data model for the LiveGreen mobile app (Flutter frontend). It implements:

- Authentication integration points (Gmail/Facebook via Firebase Auth handled on client)
- Admin-only APIs to manage activities and view users
- Activities and completion tracking
- Daily happiness score collection
- Chart aggregation endpoints (daily/week/month/year)
- Forum (posts, comments, likes)
- Wearable device data ingestion stub endpoints
- Seed script to populate default activities
- Firestore security rules and recommended indexes

High-level notes
- The frontend (Flutter) should use Firebase Authentication (Google/Facebook providers) to sign in users. The client obtains an ID token and sends it in the Authorization header: "Bearer <idToken>" to backend endpoints.
- Admin users must have a custom claim `admin: true`. You can set that via Firebase Admin SDK or the Firebase console.
- Deploy using the Firebase CLI: run `firebase deploy --only functions,firestore:rules` from a project configured with your credentials.

Files added
- `functions/` - Cloud Functions source (Express app)
- `functions/seedActivities.js` - one-off script to seed default activities
- `firestore.rules` - security rules
- `firestore.indexes.json` - recommended composite indexes

See `functions/README.md` for functions-specific setup.

Quick API usage (examples)

- List activities (public):
	GET https://<YOUR_REGION>-<PROJECT>.cloudfunctions.net/api/activities

- Mark activity complete (authenticated):
	POST /activities/:activityId/complete
	Headers: Authorization: Bearer <idToken>
	Body: { "date": "2025-10-01" } // optional

- Record happiness (authenticated):
	POST /happiness
	Body: { "score": 8, "date": "2025-10-01" }

- Get combined series for charting (authenticated):
	GET /summary/series?range=month

- Forum: POST /forum (body: { text, imageUrl }), POST /forum/:postId/comments

- Fitbit connect (opens Fitbit OAuth): GET /devices/connect/fitbit (must be called while authenticated in browser)

Fitbit environment variables
- Set the following environment variables for OAuth to work:
	- FITBIT_CLIENT_ID
	- FITBIT_CLIENT_SECRET
	- FITBIT_REDIRECT_URI (e.g., https://us-central1-<project>.cloudfunctions.net/api/oauth/fitbit/callback)

Corporate / organizations
- The backend includes `organizations` routes to create organizations, add members, and list members. To extend for org-scoped activity tracking, we recommend:
	- Add an `orgId` field to activity assignments and per-user organization-specific completions.
	- Provide org-admin roles in `organizations/{orgId}/members` with `admin` or `owner` roles.

