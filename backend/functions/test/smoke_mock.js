// Mock-based smoke test: mounts payments router with fake Firestore DB and auth middleware
const express = require('express');
const http = require('http');

// Lightweight mock DB that has collection().doc().set()/update()
const mockDb = {
  collection: (name) => ({
    doc: (id) => ({
      set: async (data) => {
        console.log(`mockDb.set called for ${name}/${id}`, data && data.orderId ? '' : '');
        return Promise.resolve();
      },
      update: async (data) => {
        console.log(`mockDb.update called for ${name}/${id}`, data);
        return Promise.resolve();
      },
      get: async () => ({ exists: false, data: () => null }),
    }),
  }),
};

// Simple auth middleware that sets req.user
function fakeAuthMiddleware(req, res, next) {
  req.user = { uid: 'smoke-user' };
  next();
}

(async () => {
  // Stub Razorpay module to avoid external network calls in smoke tests
  const Module = require('module');
  const origRequire = Module.prototype.require;
  Module.prototype.require = function (id) {
    if (id === 'razorpay') {
      return function FakeRazorpay(opts) {
        return {
          orders: {
            create: async (orderOptions) => ({ id: 'order_test_123', ...orderOptions }),
          },
        };
      };
    }
    return origRequire.apply(this, arguments);
  };

  const paymentsFactory = require('../routes/payments');
  const paymentsRouter = paymentsFactory(mockDb, fakeAuthMiddleware);

  const app = express();
  app.use(express.json());
  app.use('/payments', paymentsRouter);
  app.get('/health', (req, res) => res.json({ status: 'ok' }));

  const server = http.createServer(app);
  server.listen(0, '127.0.0.1', () => {
    const port = server.address().port;
    const options = {
      hostname: '127.0.0.1',
      port: port,
      path: '/payments/create',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        console.log('Status:', res.statusCode);
        console.log('Body:', data);
        server.close();
      });
    });

    req.on('error', (e) => { console.error('Request error', e); server.close(); });
    req.write(JSON.stringify({ amount: 199 }));
    req.end();
  });
})();
