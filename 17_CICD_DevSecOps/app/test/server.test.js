const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');

const server = createServer();
let base;

test.before(async () => {
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
test.after(() => new Promise((resolve) => server.close(resolve)));

const post = (body) =>
  fetch(`${base}/notes`, { method: 'POST', headers: { 'content-type': 'application/json' }, body });

test('health endpoint and security headers', async () => {
  const res = await fetch(`${base}/healthz`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(res.headers.get('x-frame-options'), 'DENY');
  assert.match(res.headers.get('content-security-policy'), /default-src 'none'/);
});

test('create and read a note', async () => {
  const created = await post(JSON.stringify({ title: 'hello', body: 'world' }));
  assert.equal(created.status, 201);
  const { id } = await created.json();
  const got = await (await fetch(`${base}/notes/${id}`)).json();
  assert.equal(got.title, 'hello');
});

test('invalid JSON -> 400, invalid note -> 400', async () => {
  assert.equal((await post('{not json')).status, 400);
  assert.equal((await post(JSON.stringify({ title: '' , body: '' }))).status, 400);
});

test('oversized body is refused with 413', async () => {
  const res = await post(JSON.stringify({ title: 'big', body: 'x'.repeat(10000) }));
  assert.equal(res.status, 413);
});

test('unknown note -> 404', async () => {
  assert.equal((await fetch(`${base}/notes/999`)).status, 404);
});
