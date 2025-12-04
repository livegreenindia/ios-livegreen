// Seed Firestore emulator using the REST API (no Google credentials required)
const activities = [
  'Birding', 'Visiting Park', 'Cold Water Shower', 'Gardening', 'Composting', 'Sky Watch', 'Sun Ray Exposure'
];

const projectId = process.env.GOOGLE_CLOUD_PROJECT || 'livegreen-bf838';
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const base = `http://${host}/v1/projects/${projectId}/databases/(default)/documents`;

(async function seed() {
  for (const name of activities) {
    const url = `${base}/activities`;
    console.log('Adding', name);
    const body = {
      fields: {
        name: { stringValue: name },
        weight: { integerValue: 1 }
      }
    };
    const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (!resp.ok) {
      const text = await resp.text();
      console.error('Failed to add', name, resp.status, text);
      process.exit(1);
    }
  }
  console.log('Done');
  process.exit(0);
})();
