// Integration test: start the real HTTP server on a random free port and call it.
const test = require('node:test');
const assert = require('node:assert/strict');
const server = require('../src/server');

let base;

test.before(async () => {
  await new Promise((resolve) => server.listen(0, resolve)); // port 0 = any free port
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => new Promise((resolve) => server.close(resolve)));

test('GET /healthz returns ok', async () => {
  const res = await fetch(`${base}/healthz`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok' });
});

test('GET / identifies the app and student', async () => {
  const body = await (await fetch(`${base}/`)).json();
  assert.equal(body.app, 'pragya-cicd-demo');
  assert.match(body.student, /24BCS10032/);
});

test('GET /sgpa computes from the query string', async () => {
  const body = await (await fetch(`${base}/sgpa?courses=4:85,3:72,2:91`)).json();
  assert.equal(body.sgpa, 8.89);
});

test('bad input gives 400, unknown path gives 404', async () => {
  assert.equal((await fetch(`${base}/grade?marks=150`)).status, 400);
  assert.equal((await fetch(`${base}/nope`)).status, 404);
});
