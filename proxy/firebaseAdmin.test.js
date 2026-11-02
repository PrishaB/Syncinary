'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { execFile } = require('node:child_process');

// Runs in a child process: firebase-admin's app is a process-wide singleton and
// the credentials come from the environment.
const CHILD = `
let unhandled = 0;
process.on('unhandledRejection', () => { unhandled += 1; });
process.env.SERPAPI_KEY = 'test-serpapi-key';
const { app, setRecommendationDeps } = require('./server');
// Real loadRawData (firebase-admin + Firestore); only the token check is stubbed.
setRecommendationDeps({ log: () => {}, verifyIdToken: async () => ({ uid: 'u1' }) });
const server = app.listen(0, async () => {
  const res = await fetch('http://127.0.0.1:' + server.address().port + '/recommendations', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer t' },
    body: JSON.stringify({ groupId: 'g1' }),
  });
  const body = await res.json();
  // Give any stray gRPC rejections time to surface before reporting.
  setTimeout(() => {
    console.log(JSON.stringify({ status: res.status, body, unhandled }));
    server.close();
  }, 1500);
});
`;

test('missing Firestore credentials return 503 without crashing the proxy', async () => {
  const env = {
    ...process.env,
    GOOGLE_APPLICATION_CREDENTIALS: path.join(__dirname, 'does-not-exist', 'service-account.json'),
    FIREBASE_PROJECT_ID: 'demo-test',
  };
  const stdout = await new Promise((resolve, reject) => {
    execFile(process.execPath, ['-e', CHILD], { cwd: __dirname, env, timeout: 30000 }, (err, out, stderr) =>
      err ? reject(new Error(`child exited: ${err.message}\n${stderr}`)) : resolve(out)
    );
  });
  const result = JSON.parse(stdout.trim().split('\n').pop());
  assert.equal(result.status, 503);
  assert.equal(result.body.error, 'upstream_error');
  assert.equal(result.unhandled, 0);
});
