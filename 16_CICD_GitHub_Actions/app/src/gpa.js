// Grade-point helpers used by the demo API.
// Pure functions with no dependencies, so CI can test them with Node's
// built-in test runner (no npm install needed).

// 10-point scale used in many Indian universities.
const BANDS = [
  { min: 90, points: 10, letter: 'O' },
  { min: 80, points: 9, letter: 'A+' },
  { min: 70, points: 8, letter: 'A' },
  { min: 60, points: 7, letter: 'B+' },
  { min: 50, points: 6, letter: 'B' },
  { min: 40, points: 5, letter: 'C' },
  { min: 0, points: 0, letter: 'F' },
];

function checkMarks(marks) {
  if (typeof marks !== 'number' || Number.isNaN(marks)) {
    throw new TypeError('marks must be a number');
  }
  if (marks < 0 || marks > 100) {
    throw new RangeError('marks must be between 0 and 100');
  }
}

function band(marks) {
  checkMarks(marks);
  return BANDS.find((b) => marks >= b.min);
}

function gradePoint(marks) {
  return band(marks).points;
}

function letterGrade(marks) {
  return band(marks).letter;
}

// courses: [{ credits: 4, marks: 85 }, ...]
function sgpa(courses) {
  if (!Array.isArray(courses) || courses.length === 0) {
    throw new RangeError('at least one course is needed');
  }
  let totalCredits = 0;
  let weighted = 0;
  for (const c of courses) {
    if (typeof c.credits !== 'number' || c.credits <= 0) {
      throw new RangeError('credits must be a positive number');
    }
    totalCredits += c.credits;
    weighted += c.credits * gradePoint(c.marks);
  }
  return Math.round((weighted / totalCredits) * 100) / 100;
}

// Common "CGPA x 9.5" conversion.
function cgpaToPercent(cgpa) {
  if (typeof cgpa !== 'number' || cgpa < 0 || cgpa > 10) {
    throw new RangeError('cgpa must be between 0 and 10');
  }
  return Math.round(cgpa * 9.5 * 100) / 100;
}

// "4:85,3:72" -> [{credits:4, marks:85}, {credits:3, marks:72}]
function parseCourses(text) {
  if (!text) throw new RangeError('courses query parameter is required');
  return text.split(',').map((pair) => {
    const [credits, marks] = pair.split(':').map(Number);
    return { credits, marks };
  });
}

module.exports = { gradePoint, letterGrade, sgpa, cgpaToPercent, parseCourses };
