#!/usr/bin/env python3
"""
Minimal webhook test server (Python, stdlib only)
- Verifies X-Tired-Signature (HMAC-SHA256 over raw body)
- Prints event id/type and payload

Usage:
  TIRED_WEBHOOK_SECRET=your_secret PORT=3000 python3 scripts/webhook_test_server_py.py
  Endpoint: http://localhost:3000/webhooks/tired
"""
import os
import hmac
import hashlib
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = int(os.getenv('PORT', '3000'))
SECRET = os.getenv('TIRED_WEBHOOK_SECRET', '')


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if not self.path.startswith('/webhooks/tired'):
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not found')
            return

        length = int(self.headers.get('Content-Length', '0'))
        body = self.rfile.read(length)
        event = self.headers.get('X-Tired-Event', '')
        signature = self.headers.get('X-Tired-Signature', '')
        idem = self.headers.get('Idempotency-Key', '')

        if SECRET:
            expected = hmac.new(SECRET.encode('utf-8'), body, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(expected, signature or ''):
                self.send_response(401)
                self.end_headers()
                self.wfile.write(b'invalid signature')
                return
        else:
            print('[warn] TIRED_WEBHOOK_SECRET missing; skipping signature verification')

        try:
            payload = json.loads(body.decode('utf-8'))
        except Exception:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'invalid json')
            return

        evt_id = payload.get('id', '(no-id)')
        print(f"\n[ok] event {evt_id} {event}")
        if idem:
            print(f"idempotency-key: {idem}")
        print(json.dumps(payload, ensure_ascii=False, indent=2))

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'ok')


def main():
    httpd = HTTPServer(('0.0.0.0', PORT), Handler)
    print(f"[listening] http://localhost:{PORT}/webhooks/tired")
    httpd.serve_forever()


if __name__ == '__main__':
    main()

