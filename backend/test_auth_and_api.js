const http = require('http');
const https = require('https');
const fetch = require('node-fetch');

const AUTH_BASE = 'http://127.0.0.1:9099';
const API_BASE = 'http://127.0.0.1:5001/livegreen-bf838/us-central1/api';

async function signUp(email, password) {
  const url = `${AUTH_BASE}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test`;
  const res = await fetch(url, { method: 'POST', body: JSON.stringify({ email, password, returnSecureToken: true }), headers: { 'Content-Type': 'application/json' } });
  const data = await res.json();
  console.log('signUp', res.status, data);
  return data;
}

async function signIn(email, password) {
  const url = `${AUTH_BASE}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test`;
  const res = await fetch(url, { method: 'POST', body: JSON.stringify({ email, password, returnSecureToken: true }), headers: { 'Content-Type': 'application/json' } });
  const data = await res.json();
  console.log('signIn', res.status, data);
  return data;
}

async function callApi(path, method='GET', token=null, body=null) {
  const url = `${API_BASE}${path}`;
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (body) headers['Content-Type'] = 'application/json';
  const res = await fetch(url, { method, body: body ? JSON.stringify(body) : undefined, headers });
  const text = await res.text();
  console.log(`${method} ${path} -> ${res.status}`);
  try { console.log(JSON.parse(text)); } catch (e) { console.log(text); }
  return { status: res.status, body: text };
}

(async () => {
  const email = 'dev@local.test';
  const password = 'DevPass123!';
  await signUp(email, password);
  const signin = await signIn(email, password);
  const idToken = signin.idToken;
  if (!idToken) {
    console.error('No idToken from signIn; aborting');
    process.exit(1);
  }

  await callApi('/profile', 'GET', idToken);
  await callApi('/forum', 'POST', idToken, { text: 'hello from test' });
  await callApi('/happiness', 'POST', idToken, { score: 7 });
})();
