const express = require('express');
const functions = require('firebase-functions');
const fetch = require('node-fetch');

module.exports = (db, authMiddleware, requireAuth) => {
  const router = express.Router();

  // Ensure requireAuth is present
  if (typeof requireAuth !== 'function') {
    requireAuth = (req, res, next) => {
      if (req.user && req.user.uid) return next();
      return res.status(401).json({ error: 'Unauthorized' });
    };
  }

  console.log('Loading fitbit router');

  // Helper: obtain client credentials from env or functions config
  function getClientConfig() {
    const clientId = process.env.FITBIT_CLIENT_ID || (functions.config && functions.config().fitbit && functions.config().fitbit.client_id) || null;
    const clientSecret = process.env.FITBIT_CLIENT_SECRET || (functions.config && functions.config().fitbit && functions.config().fitbit.client_secret) || null;
    return { clientId, clientSecret };
  }

  // Simple request id generator for structured logs
  function genReqId() {
    return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2,10)}`;
  }

  // Firestore-backed per-user rate limiter (sliding window). Allows up to RATE_LIMIT_MAX requests per RATE_LIMIT_WINDOW_MS
  const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute
  const RATE_LIMIT_MAX = 20; // allow 20 requests per window per user
  async function checkRateLimit(uid, route, dbRef) {
    try {
      if (!uid) return true; // unauthenticated flows handled upstream
      const docRef = db.collection('rate_limits').doc(`${route}:${uid}`);
      const snap = await docRef.get();
      const now = Date.now();
      if (!snap.exists) {
        await docRef.set({ count: 1, window_start: now }, { merge: true });
        return true;
      }
      const data = snap.data() || {};
      const windowStart = data.window_start || 0;
      let count = data.count || 0;
      if (now - windowStart > RATE_LIMIT_WINDOW_MS) {
        // reset window
        await docRef.set({ count: 1, window_start: now }, { merge: true });
        return true;
      }
      if (count >= RATE_LIMIT_MAX) return false;
      await docRef.update({ count: (count + 1) });
      return true;
    } catch (e) {
      // on any error, allow through (fail-open) but log
      console.warn('Rate limit check failed, allowing request', e);
      return true;
    }
  }

  // Exchange authorization code for tokens (server-side). Requires auth.
  router.post('/exchange', authMiddleware, requireAuth, async (req, res) => {
    const reqId = genReqId();
    try {
      const { code, redirect_uri, code_verifier } = req.body || {};
      if (!code || !redirect_uri) return res.status(400).json({ error: 'code and redirect_uri required' });

      const uid = req.user && req.user.uid;
      // rate limit per user+route
      const allowed = await checkRateLimit(uid, 'fitbit:exchange', db);
      if (!allowed) return res.status(429).json({ error: 'rate_limited', message: 'Too many requests, try later' });

      const cfg = getClientConfig();
      if (!cfg.clientId || !cfg.clientSecret) return res.status(500).json({ error: 'server_misconfigured' });

      // If no code_verifier provided by client, read server-stored verifier and validate redirect_uri and TTL
      let verifierToUse = code_verifier;
      if ((!verifierToUse || verifierToUse === '') && uid) {
        try {
          const docSnap = await db.collection('fitbit_pkce').doc(uid).get();
          if (docSnap.exists) {
            const data = docSnap.data() || {};
            if (data.code_verifier) verifierToUse = data.code_verifier;
            // Validate redirect_uri if stored
            if (data.redirect_uri && data.redirect_uri !== redirect_uri) {
              console.warn({ reqId, uid, msg: 'redirect_uri_mismatch', expected: data.redirect_uri, got: redirect_uri });
              return res.status(400).json({ error: 'redirect_uri_mismatch' });
            }
            // Enforce TTL (default 15 minutes)
            if (data.created_at) {
              const created = new Date(data.created_at).getTime();
              if (Date.now() - created > (15 * 60 * 1000)) {
                // cleanup stale doc and reject
                try { await db.collection('fitbit_pkce').doc(uid).delete(); } catch(_){}
                return res.status(400).json({ error: 'pkce_verifier_expired' });
              }
            }
          }
        } catch (err) {
          console.warn('Unable to read stored PKCE verifier', err);
        }
      }

      const tokenUrl = 'https://api.fitbit.com/oauth2/token';

      const bodyParams = new URLSearchParams();
      bodyParams.append('code', code);
      bodyParams.append('grant_type', 'authorization_code');
      bodyParams.append('redirect_uri', redirect_uri);
      if (verifierToUse) bodyParams.append('code_verifier', verifierToUse);

      const authHeader = 'Basic ' + Buffer.from(`${cfg.clientId}:${cfg.clientSecret}`).toString('base64');

      const resp = await fetch(tokenUrl, {
        method: 'POST',
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: bodyParams.toString()
      });

      const json = await resp.json();
      if (!resp.ok) {
        console.warn({ reqId, uid, msg: 'token_exchange_failed', status: resp.status, details: json });
        return res.status(resp.status).json({ error: 'token_exchange_failed' });
      }

      // Persist tokens for user (server-authoritative) and return sanitized token info
      if (uid) {
        const now = new Date();
        const expiresIn = json.expires_in || 0;
        const expiresAt = new Date(now.getTime() + (expiresIn * 1000));
        await db.collection('fitbit_tokens').doc(uid).set({
          access_token: json.access_token,
          refresh_token: json.refresh_token,
          scope: json.scope,
          token_type: json.token_type,
          expires_in: expiresIn,
          expires_at: expiresAt,
          issued_at: now,
          updated_at: now
        }, { merge: true });
        // Clean up the stored PKCE verifier once used
        try {
          await db.collection('fitbit_pkce').doc(uid).delete();
        } catch (err) {
          // non-fatal
          console.warn('Failed to delete PKCE verifier doc', err);
        }
      }

      // Return sanitized token metadata (do not leak client secrets)
      return res.json({ ok: true, token: {
        access_token: json.access_token,
        refresh_token: json.refresh_token,
        expires_in: json.expires_in,
        token_type: json.token_type,
        scope: json.scope
      }});
    } catch (err) {
      console.error('Fitbit exchange failed', err);
      return res.status(500).json({ error: 'server_error' });
    }
  });

  // Start authorization: return an authorize URL constructed server-side.
  // This lets the mobile client avoid shipping client_id. The server will
  // optionally persist a PKCE code_verifier per-user to validate later.
  router.post('/start', authMiddleware, requireAuth, async (req, res) => {
    const reqId = genReqId();
    try {
      const { redirect_uri } = req.body || {};
      if (!redirect_uri) return res.status(400).json({ error: 'redirect_uri_required' });

      const uid = req.user && req.user.uid;
      const allowed = await checkRateLimit(uid, 'fitbit:start', db);
      if (!allowed) return res.status(429).json({ error: 'rate_limited' });

      const cfg = getClientConfig();
      console.log('Fitbit /start config check:', { 
        hasClientId: !!cfg.clientId, 
        clientId: cfg.clientId ? `${cfg.clientId.substring(0, 3)}...` : null,
        hasClientSecret: !!cfg.clientSecret,
        reqId, 
        uid 
      });
      
      if (!cfg.clientId) return res.status(500).json({ error: 'server_misconfigured' });

      // Generate a PKCE code_verifier and code_challenge server-side.
      const crypto = require('crypto');
      const verifier = crypto.randomBytes(64).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
      const challenge = crypto.createHash('sha256').update(verifier).digest('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

      const params = new URLSearchParams();
      params.append('response_type', 'code');
      params.append('client_id', cfg.clientId);
      params.append('redirect_uri', redirect_uri);
      params.append('scope', 'activity heartrate sleep profile');
      params.append('code_challenge', challenge);
      params.append('code_challenge_method', 'S256');

      const authorizeUrl = `https://www.fitbit.com/oauth2/authorize?${params.toString()}`;
      
      console.log('Generated authorize URL:', { 
        url: authorizeUrl.substring(0, 100) + '...', 
        hasClientIdParam: authorizeUrl.includes('client_id='),
        reqId 
      });

      // Persist the verifier in Firestore associated with the user so exchange can validate.
      if (uid) {
        await db.collection('fitbit_pkce').doc(uid).set({
          code_verifier: verifier,
          redirect_uri: redirect_uri,
          created_at: new Date()
        }, { merge: true });
      }

      return res.json({ ok: true, authorize_url: authorizeUrl });
    } catch (err) {
      console.error({ reqId, msg: 'Fitbit start failed', err });
      return res.status(500).json({ error: 'server_error' });
    }
  });

  // Refresh tokens server-side
  router.post('/refresh', authMiddleware, requireAuth, async (req, res) => {
    const reqId = genReqId();
    try {
      const uid = req.user && req.user.uid;
      const allowed = await checkRateLimit(uid, 'fitbit:refresh', db);
      if (!allowed) return res.status(429).json({ error: 'rate_limited' });

      const cfg = getClientConfig();
      if (!cfg.clientId || !cfg.clientSecret) return res.status(500).json({ error: 'server_misconfigured' });

      // Prefer server-stored refresh token for authenticated user
      let refreshTokenToUse = null;
      if (uid) {
        const tdoc = await db.collection('fitbit_tokens').doc(uid).get();
        if (tdoc.exists && tdoc.data() && tdoc.data().refresh_token) {
          refreshTokenToUse = tdoc.data().refresh_token;
        }
      }
      // As a fallback, accept a refresh token provided in body only if no stored token exists
      if (!refreshTokenToUse && req.body && req.body.refresh_token) {
        refreshTokenToUse = req.body.refresh_token;
      }
      if (!refreshTokenToUse) return res.status(400).json({ error: 'refresh_token_unavailable' });

      const tokenUrl = 'https://api.fitbit.com/oauth2/token';
      const bodyParams = new URLSearchParams();
      bodyParams.append('grant_type', 'refresh_token');
      bodyParams.append('refresh_token', refreshTokenToUse);

      const authHeader = 'Basic ' + Buffer.from(`${cfg.clientId}:${cfg.clientSecret}`).toString('base64');

      const resp = await fetch(tokenUrl, {
        method: 'POST',
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: bodyParams.toString()
      });

      const json = await resp.json();
      if (!resp.ok) {
        console.warn({ reqId, uid, msg: 'refresh_failed', status: resp.status, details: json });
        return res.status(resp.status).json({ error: 'refresh_failed' });
      }

      if (uid) {
        const now = new Date();
        const expiresIn = json.expires_in || 0;
        const expiresAt = new Date(now.getTime() + (expiresIn * 1000));
        await db.collection('fitbit_tokens').doc(uid).set({
          access_token: json.access_token,
          refresh_token: json.refresh_token,
          scope: json.scope,
          token_type: json.token_type,
          expires_in: expiresIn,
          expires_at: expiresAt,
          issued_at: now,
          updated_at: now
        }, { merge: true });
      }

      return res.json({ ok: true, token: { access_token: json.access_token, refresh_token: json.refresh_token, expires_in: json.expires_in, token_type: json.token_type, scope: json.scope } });
    } catch (err) {
      console.error({ reqId, msg: 'Fitbit refresh failed', err });
      return res.status(500).json({ error: 'server_error' });
    }
  });

  return router;
};
