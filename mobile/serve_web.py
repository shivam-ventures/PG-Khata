"""Minimal static file server that never calls os.getcwd() — the sandboxed
preview process this runs under denies that syscall outright, which breaks
http.server's own CLI and SimpleHTTPRequestHandler (both call it internally).
"""

import mimetypes
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOT = "/Users/shivam/Downloads/PGKhata/mobile/build/web"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/":
            path = "/index.html"
        full_path = ROOT + path
        try:
            with open(full_path, "rb") as f:
                body = f.read()
        except OSError:
            self.send_response(404)
            self.end_headers()
            return
        content_type = mimetypes.guess_type(full_path)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


HTTPServer(("", 5050), Handler).serve_forever()
