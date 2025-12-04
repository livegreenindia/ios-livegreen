// Simple dev server that imports the app and starts listening. This avoids the require.main logic
const app = require('./index');
const port = process.env.PORT || 5001;
app.listen(port, () => {
  console.log(`Dev server listening on http://127.0.0.1:${port}`);
});
// Keep process alive
process.stdin.resume();
