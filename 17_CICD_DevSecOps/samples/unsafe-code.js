// =====================================================================
//  INTENTIONALLY INSECURE SAMPLE - DO NOT USE, DO NOT IMPORT
//  Pragya Tripathi (24BCS10032) - Session 17 DevSecOps lab
//
//  This file exists only so the SAST and secret-scanning stages have
//  something real to detect. It lives outside app/, is never required by
//  the server, and is never copied into any container image.
//  The "secret" below is random junk made up for this lab, not a real key.
// =====================================================================
const { exec } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const http = require('http');

// BUG 1 - hard-coded credential in source code
const PAYMENT_API_TOKEN = 'q8ZtR2vLx9WmK4pN7bYc3HsJ6dFg1Ae5'; // gitleaks:allow (fake, lab only)

// BUG 2 - command injection: user input is pasted into a shell command
function pingHost(host, cb) {
  exec('ping -c 1 ' + host, cb);
}

// BUG 3 - code injection: eval() on user input
function calculate(expression) {
  return eval(expression);
}

// BUG 4 - weak password hashing (MD5, no salt)
function hashPassword(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

// BUG 5 - SQL injection: query built by string concatenation
function findStudent(db, name) {
  return db.query("SELECT * FROM students WHERE name = '" + name + "'");
}

// BUG 6 - path traversal + reflected input, all straight from the request
http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/file') {
    fs.readFile('/srv/files/' + url.searchParams.get('name'), (err, data) => res.end(err ? 'error' : data));
  } else {
    res.end('<h1>Hello ' + url.searchParams.get('user') + '</h1>');
  }
});

// BUG 7 - predictable "random" session token
function newSessionToken() {
  return Math.random().toString(36).slice(2);
}

module.exports = { PAYMENT_API_TOKEN, pingHost, calculate, hashPassword, findStudent, newSessionToken };
