// Session 17 demo API - a tiny notice board on the Node standard library.
// Security basics: input validation, body size limit, security headers,
// no stack traces in responses, runs fine as a non-root user.
const http = require('node:http');
const { createStore } = require('./notes');

const PORT = Number(process.env.PORT) || 3000;
const VERSION = process.env.APP_VERSION || 'dev';
const MAX_REQUEST_BYTES = 4096;

const SECURITY_HEADERS = {
  'Content-Type': 'application/json; charset=utf-8',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer',
  'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",
  'Cache-Control': 'no-store',
};

function createServer(store = createStore()) {
  function send(res, code, body) {
    res.writeHead(code, SECURITY_HEADERS);
    res.end(JSON.stringify(body) + '\n');
  }

  function readJson(req) {
    return new Promise((resolve, reject) => {
      let size = 0;
      const chunks = [];
      req.on('data', (c) => {
        size += c.length;
        if (size <= MAX_REQUEST_BYTES) chunks.push(c); // stop buffering past the limit
      });
      req.on('end', () => {
        if (size > MAX_REQUEST_BYTES) {
          return reject(Object.assign(new Error('request body too large'), { status: 413 }));
        }
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
        } catch {
          reject(Object.assign(new Error('body is not valid JSON'), { status: 400 }));
        }
      });
    });
  }

  return http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const match = url.pathname.match(/^\/notes\/(\d+)$/);

    try {
      if (url.pathname === '/healthz') return send(res, 200, { status: 'ok' });
      if (url.pathname === '/readyz') return send(res, 200, { status: 'ready' });
      if (url.pathname === '/') {
        return send(res, 200, {
          app: 'pragya-devsecops-demo',
          student: 'Pragya Tripathi (24BCS10032)',
          version: VERSION,
          uid: typeof process.getuid === 'function' ? process.getuid() : null,
          endpoints: ['GET /notes', 'POST /notes', 'GET /notes/:id', 'DELETE /notes/:id'],
        });
      }
      if (url.pathname === '/notes' && req.method === 'GET') return send(res, 200, store.list());
      if (url.pathname === '/notes' && req.method === 'POST') {
        return send(res, 201, store.add(await readJson(req)));
      }
      if (match && req.method === 'GET') {
        const note = store.get(Number(match[1]));
        return note ? send(res, 200, note) : send(res, 404, { error: 'note not found' });
      }
      if (match && req.method === 'DELETE') {
        return store.remove(Number(match[1])) ? send(res, 204, {}) : send(res, 404, { error: 'note not found' });
      }
      return send(res, 404, { error: 'not found' });
    } catch (err) {
      // Validation errors are safe to show; anything else becomes a generic 500.
      if (err.status) return send(res, err.status, { error: err.message });
      if (err instanceof TypeError || err instanceof RangeError) return send(res, 400, { error: err.message });
      console.error(err);
      return send(res, 500, { error: 'internal error' });
    }
  });
}

if (require.main === module) {
  const server = createServer();
  server.listen(PORT, () => console.log(`pragya-devsecops-demo ${VERSION} listening on :${PORT}`));
  process.on('SIGTERM', () => server.close(() => process.exit(0)));
}

module.exports = { createServer };
