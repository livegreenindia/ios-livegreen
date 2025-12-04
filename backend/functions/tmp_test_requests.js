const fetch = require('node-fetch');

async function run() {
  const base = 'http://127.0.0.1:5001';
  // wait for server to be accepting connections
  async function waitForServer(retries = 6) {
    for (let i = 0; i < retries; i++) {
      try {
        const r = await fetch(base + '/health');
        if (r.ok) return true;
      } catch (e) {
        // ignore and retry
      }
      await new Promise((res) => setTimeout(res, 500));
    }
    return false;
  }
  const ready = await waitForServer();
  if (!ready) {
    console.error('Server not reachable at', base);
    process.exit(1);
  }
  try {
    console.log('POST /fitbit/start');
    const startResp = await fetch(base + '/fitbit/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ redirect_uri: 'livegreen://auth' }),
    });
    console.log('start status:', startResp.status);
    const startText = await startResp.text();
    console.log('start body:', startText);

    console.log('\nPOST /fitbit/exchange with dummy code');
    const exchResp = await fetch(base + '/fitbit/exchange', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code: 'DUMMY_CODE', redirect_uri: 'livegreen://auth' }),
    });
    console.log('exchange status:', exchResp.status);
    const exchText = await exchResp.text();
    console.log('exchange body:', exchText);
  } catch (err) {
    console.error('Error running tests', err);
    process.exit(1);
  }
}

run();
