from http.server import HTTPServer, BaseHTTPRequestHandler

PAGE = b"<h1>Hello World</h1><p>Python app running in a Docker container (port 8000)</p>"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(PAGE)

print("Python server listening on port 8000", flush=True)
HTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
