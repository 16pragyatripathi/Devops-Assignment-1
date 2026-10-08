// Small HTTP API on the Node standard library only (no npm dependencies).
const http = require('node:http');
const os = require('node:os');
const { gradePoint, letterGrade, sgpa, cgpaToPercent, parseCourses } = require('./gpa');

const PORT = Number(process.env.PORT) || 3000;
const VERSION = process.env.APP_VERSION || 'dev';

function send(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body) + '\n');
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const q = url.searchParams;

  try {
    switch (url.pathname) {
      case '/':
        return send(res, 200, {
          app: 'pragya-cicd-demo',
          student: 'Pragya Tripathi (24BCS10032)',
          version: VERSION,
          node: process.version,
          host: os.hostname(),
          try: ['/healthz', '/grade?marks=82', '/sgpa?courses=4:85,3:72,2:91', '/percent?cgpa=8.4'],
        });
      case '/healthz':
        return send(res, 200, { status: 'ok' });
      case '/readyz':
        return send(res, 200, { status: 'ready' });
      case '/grade': {
        const marks = Number(q.get('marks'));
        return send(res, 200, { marks, letter: letterGrade(marks), points: gradePoint(marks) });
      }
      case '/sgpa': {
        const courses = parseCourses(q.get('courses'));
        return send(res, 200, { courses, sgpa: sgpa(courses) });
      }
      case '/percent': {
        const cgpa = Number(q.get('cgpa'));
        return send(res, 200, { cgpa, percent: cgpaToPercent(cgpa) });
      }
      default:
        return send(res, 404, { error: 'not found' });
    }
  } catch (err) {
    return send(res, 400, { error: err.message });
  }
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`pragya-cicd-demo ${VERSION} listening on :${PORT}`));
  // Exit cleanly when Kubernetes / docker stop sends SIGTERM.
  process.on('SIGTERM', () => server.close(() => process.exit(0)));
}

module.exports = server;
