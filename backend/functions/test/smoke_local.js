// Start the app on an ephemeral port (0) and POST to /payments/create with DISABLE_AUTH=true
process.env.DISABLE_AUTH = 'true';
process.env.DEV_UID = 'dev-user';

const app = require('../index');
const http = require('http');

const server = http.createServer(app);
server.listen(0, '127.0.0.1', () => {
  const addr = server.address();
  const port = addr.port;
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
      console.log('Headers:', res.headers);
      console.log('Body:', data);
      server.close();
    });
  });

  req.on('error', (e) => { console.error('Request error', e); server.close(); });
  req.write(JSON.stringify({ amount: 199 }));
  req.end();
});
