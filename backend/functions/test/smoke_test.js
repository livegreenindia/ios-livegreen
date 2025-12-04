const https = require('https');
const http = require('http');

const apiBase = process.env.API_BASE_URL || 'https://us-central1-livegreen-bf838.cloudfunctions.net/api';
const amount = process.env.AMOUNT || '199';
const idToken = process.env.ID_TOKEN || process.env.RAZORPAY_SMOKE_ID_TOKEN || null;

const url = new URL(apiBase + '/payments/create');

const payload = JSON.stringify({ amount: Number(amount) });

const options = {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  },
};
if (idToken) options.headers['Authorization'] = `Bearer ${idToken}`;

const client = url.protocol === 'https:' ? https : http;

const req = client.request(url, options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log('Status:', res.statusCode);
    console.log('Headers:', res.headers);
    console.log('Body:', data);
  });
});

req.on('error', (e) => {
  console.error('Request error', e);
});

req.write(payload);
req.end();
