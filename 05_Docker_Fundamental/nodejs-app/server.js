const http = require("http");

const PORT = 3000;

http.createServer((req, res) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
  res.writeHead(200, {"Content-Type": "text/html"});
  res.end("<h1>Hello World</h1><p>Node.js app running in a Docker container (port 3000)</p>");
}).listen(PORT, "0.0.0.0", () => {
  console.log(`Node.js server listening on port ${PORT}`);
});
