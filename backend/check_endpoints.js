// Simple endpoint checker for production Firebase functions
// Usage: node check_endpoints.js
const base = 'https://us-central1-livegreen-bf838.cloudfunctions.net/api';

async function check(path) {
  const url = `${base}${path}`;
  try {
    const res = await fetch(url);
    const text = await res.text();
    let body = text;
    try { body = JSON.parse(text); } catch (e) { /* not JSON */ }
    console.log(`\n[OK] ${url} -> ${res.status} ${res.statusText}`);
    console.log('Body:', body);
  } catch (err) {
    console.error(`\n[ERR] ${url} ->`, err.message || err);
  }
}

(async () => {
  console.log('Checking production endpoints...');
  await check('/health');
  await check('/activities');
  await check('/forum');
  console.log('\nDone.');
})();
