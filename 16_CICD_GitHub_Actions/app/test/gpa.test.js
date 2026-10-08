const test = require('node:test');
const assert = require('node:assert/strict');
const { gradePoint, letterGrade, sgpa, cgpaToPercent, parseCourses } = require('../src/gpa');

test('gradePoint follows the 10-point bands', () => {
  assert.equal(gradePoint(95), 10);
  assert.equal(gradePoint(90), 10);
  assert.equal(gradePoint(89.5), 9);
  assert.equal(gradePoint(72), 8);
  assert.equal(gradePoint(40), 5);
  assert.equal(gradePoint(39), 0);
});

test('letterGrade returns the matching letter', () => {
  assert.equal(letterGrade(91), 'O');
  assert.equal(letterGrade(65), 'B+');
  assert.equal(letterGrade(12), 'F');
});

test('marks outside 0-100 or non-numbers are rejected', () => {
  assert.throws(() => gradePoint(101), RangeError);
  assert.throws(() => gradePoint(-1), RangeError);
  assert.throws(() => gradePoint('80'), TypeError);
  assert.throws(() => gradePoint(NaN), TypeError);
});

test('sgpa is the credit-weighted average of grade points', () => {
  // (4*9 + 3*8 + 2*10) / 9 = 80 / 9 = 8.888...
  assert.equal(sgpa([{ credits: 4, marks: 85 }, { credits: 3, marks: 72 }, { credits: 2, marks: 91 }]), 8.89);
  assert.equal(sgpa([{ credits: 3, marks: 100 }]), 10);
});

test('sgpa rejects empty lists and bad credits', () => {
  assert.throws(() => sgpa([]), RangeError);
  assert.throws(() => sgpa([{ credits: 0, marks: 80 }]), RangeError);
});

test('cgpaToPercent uses the x9.5 rule', () => {
  assert.equal(cgpaToPercent(8.4), 79.8);
  assert.equal(cgpaToPercent(10), 95);
  assert.throws(() => cgpaToPercent(11), RangeError);
});

test('parseCourses reads "credits:marks" pairs', () => {
  assert.deepEqual(parseCourses('4:85,3:72'), [{ credits: 4, marks: 85 }, { credits: 3, marks: 72 }]);
  assert.throws(() => parseCourses(''), RangeError);
});
