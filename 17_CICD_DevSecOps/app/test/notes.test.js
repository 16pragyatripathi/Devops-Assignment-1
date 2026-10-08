const test = require('node:test');
const assert = require('node:assert/strict');
const { createStore, MAX_TITLE } = require('../src/notes');

test('add + list + get + remove', () => {
  const s = createStore();
  const n = s.add({ title: '  Lab 17  ', body: 'scan everything' });
  assert.equal(n.id, 1);
  assert.equal(n.title, 'Lab 17'); // trimmed
  assert.equal(s.list().length, 1);
  assert.equal(s.get(1).body, 'scan everything');
  assert.equal(s.remove(1), true);
  assert.equal(s.remove(1), false);
  assert.equal(s.get(1), null);
});

test('rejects missing or wrong-type fields', () => {
  const s = createStore();
  assert.throws(() => s.add(null), TypeError);
  assert.throws(() => s.add({ body: 'x' }), TypeError);
  assert.throws(() => s.add({ title: 'x', body: 42 }), TypeError);
});

test('rejects over-long input', () => {
  const s = createStore();
  assert.throws(() => s.add({ title: 'a'.repeat(MAX_TITLE + 1), body: '' }), RangeError);
});

test('list returns copies, not the internal objects', () => {
  const s = createStore();
  s.add({ title: 't', body: 'b' });
  s.list()[0].title = 'changed';
  assert.equal(s.get(1).title, 't');
});
