const express = require('express');
const Razorpay = require('razorpay');
const functions = require('firebase-functions');
const crypto = require('crypto');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');

module.exports = (db, authMiddleware, requireAuth) => {
  const router = express.Router();
  // If the caller didn't provide a requireAuth helper (tests/mocks may omit it),
  // provide a default implementation that enforces a signed-in user.
  if (typeof requireAuth !== 'function') {
    requireAuth = (req, res, next) => {
      if (req.user && req.user.uid) return next();
      return res.status(401).json({ error: 'Unauthorized' });
    };
  }

  // Debug: announce router load
  console.log('Loading payments router');

  // Simple ping route for checking route registration without auth/body
  router.get('/ping', (req, res) => res.json({ ok: true, name: 'payments' }));

  // Initialize Razorpay - prefer environment variables, then functions.config(),
  // fallback to the previous hardcoded test keys (not recommended for prod).
  const razorpayKeyId = process.env.RAZORPAY_KEY_ID
    || (functions.config && functions.config().razorpay && functions.config().razorpay.key_id)
    || 'rzp_test_RSAQYbNr7GVxEK';

  const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET
    || (functions.config && functions.config().razorpay && functions.config().razorpay.key_secret)
    || 'yArot6XeNXNfquN58hfhETFz';

  // In production we must not use fallback test keys. Fail fast so deployment
  // alerts if real keys aren't configured.
  if (process.env.NODE_ENV === 'production') {
    if (!process.env.RAZORPAY_KEY_ID && !(functions.config && functions.config().razorpay && functions.config().razorpay.key_id)) {
      throw new Error('RAZORPAY_KEY_ID must be set in production');
    }
    if (!process.env.RAZORPAY_KEY_SECRET && !(functions.config && functions.config().razorpay && functions.config().razorpay.key_secret)) {
      throw new Error('RAZORPAY_KEY_SECRET must be set in production');
    }
  }

  // Webhook secret for verifying Razorpay webhook payloads. Replace placeholder with
  // your webhook secret in production via env var or functions.config().
  const razorpayWebhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET
    || (functions.config && functions.config().razorpay && functions.config().razorpay.webhook_secret)
    || 'rzp_webhook_secret_placeholder';

  const razorpay = new Razorpay({
    key_id: razorpayKeyId,
    key_secret: razorpayKeySecret,
  });

  // Create a subscription payment order (requires authenticated user)
  router.post('/create', authMiddleware, requireAuth, async (req, res) => {
    try {
      const { amount, currency = 'INR', receipt } = req.body;
      if (!amount) return res.status(400).json({ error: 'Amount is required' });

      // Create Razorpay order
      const orderOptions = {
        amount: Math.round(amount * 100), // amount in paise
        currency,
        receipt: receipt || `receipt_${Date.now()}`,
        payment_capture: 1 // auto capture
      };

      const order = await razorpay.orders.create(orderOptions);

      // Save order in Firestore
      const paymentDoc = {
        uid: req.user.uid,
        orderId: order.id,
        amount: amount,
        currency: currency,
        status: 'created',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await db.collection('payments').doc(order.id).set(paymentDoc);

      res.json({
        orderId: order.id,
        amount: amount,
        currency: currency,
        key: razorpay.key_id
      });
    } catch (err) {
      console.error('Error creating Razorpay order', err);
      res.status(500).json({ error: 'Failed to create order' });
    }
  });

  // Verify payment signature (call from client after payment success). Requires auth.
  router.post('/verify', authMiddleware, requireAuth, async (req, res) => {
    try {
      const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

      // Use the same secret used to initialize the Razorpay instance for signature
      // verification. Prefer env var, then functions.config(), then fallback.
      const hmacSecret = process.env.RAZORPAY_KEY_SECRET
        || (functions.config && functions.config().razorpay && functions.config().razorpay.key_secret)
        || razorpayKeySecret;

      const hmac = crypto.createHmac('sha256', hmacSecret);
      hmac.update(razorpay_order_id + '|' + razorpay_payment_id);
      const generatedSignature = hmac.digest('hex');

      if (generatedSignature === razorpay_signature) {
        // Update payment status in Firestore
        await db.collection('payments').doc(razorpay_order_id).update({
          status: 'paid',
          paymentId: razorpay_payment_id,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        // Also mark user as Premium in users collection so frontend can show unlocked features
        try {
          const uid = req.user && req.user.uid;
          if (uid) {
            await db.collection('users').doc(uid).set({
              plan: 'Premium',
              premiumSince: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
          }
        } catch (e) {
          console.error('Failed to update user plan to Premium', e);
        }
        return res.json({ success: true });
      } else {
        await db.collection('payments').doc(razorpay_order_id).update({
          status: 'failed'
        });
        return res.status(400).json({ error: 'Payment could not be verified. Please contact support.' });
      }
    } catch (err) {
      console.error('Payment verification failed', err);
      res.status(500).json({ error: 'Something went wrong during verification. Please contact support.' });
    }
  });

  // Razorpay webhook endpoint (server-to-server). Use this for authoritative
  // payment notifications coming from Razorpay. This route expects the raw
  // request body so we use bodyParser.raw for application/json.
  router.post('/webhook', bodyParser.raw({ type: 'application/json' }), async (req, res) => {
    try {
      const signature = req.headers['x-razorpay-signature'];
      const payload = req.body; // Buffer

      if (!signature) {
        return res.status(400).json({ error: 'Missing signature header' });
      }

      const expected = crypto.createHmac('sha256', razorpayWebhookSecret).update(payload).digest('hex');
      if (expected !== signature) {
        console.error('Invalid Razorpay webhook signature', { expected, signature });
        return res.status(400).json({ error: 'Invalid signature' });
      }

      const event = JSON.parse(payload.toString('utf8'));
      // Handle relevant events
      const eventName = event.event;
      // Example: payment.captured, payment.authorized, order.paid
      if (eventName === 'payment.captured' || eventName === 'payment.authorized' || eventName === 'order.paid') {
        const paymentEntity = event.payload && event.payload.payment && event.payload.payment.entity;
        const orderId = paymentEntity && paymentEntity.order_id;
        const paymentId = paymentEntity && paymentEntity.id;

        if (orderId) {
          // Update payment doc and user plan (if uid present on the payment doc)
          try {
            await db.collection('payments').doc(orderId).update({
              status: 'paid',
              paymentId: paymentId,
              verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            const snap = await db.collection('payments').doc(orderId).get();
            if (snap.exists) {
              const data = snap.data() || {};
              const uid = data.uid;
              if (uid) {
                await db.collection('users').doc(uid).set({
                  plan: 'Premium',
                  premiumSince: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
              }
            }
          } catch (e) {
            console.error('Failed to update payment/user from webhook', e);
          }
        }
      }

      // Respond quickly to Razorpay
      res.json({ ok: true });
    } catch (err) {
      console.error('Webhook processing failed', err);
      res.status(500).json({ error: 'Webhook processing failed' });
    }
  });

  return router;
};
