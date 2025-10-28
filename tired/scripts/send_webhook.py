#!/usr/bin/env python3
"""
Send a signed webhook to a target URL.

Usage:
  python3 scripts/send_webhook.py \
    --url http://localhost:3000/webhooks/tired \
    --secret your_secret \
    --event message.ack \
    --file docs/api/examples/message.ack.json

Or pipe JSON via stdin:
  cat docs/api/examples/message.ack.json | python3 scripts/send_webhook.py \
    --url http://localhost:3000/webhooks/tired --secret your_secret --event message.ack

No third-party deps (uses urllib).
"""
import argparse
import hashlib
import hmac
import json
import sys
from urllib import request


def load_payload(path: str | None) -> bytes:
    if path:
        with open(path, 'rb') as f:
            return f.read()
    data = sys.stdin.buffer.read()
    if not data:
        raise SystemExit('[error] no input payload; use --file or pipe JSON to stdin')
    return data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--url', required=True)
    ap.add_argument('--secret', required=True)
    ap.add_argument('--event', required=True,
                    choices=['message.ack', 'attendance.closed', 'clock.recorded', 'esg.report.ready', 'policy.violation', 'unmask.approved'])
    ap.add_argument('--file')
    ap.add_argument('--idempotency-key')
    args = ap.parse_args()

    body = load_payload(args.file)
    try:
        # validate JSON
        json.loads(body.decode('utf-8'))
    except Exception as e:
        raise SystemExit(f'[error] invalid JSON: {e}')

    sig = hmac.new(args.secret.encode('utf-8'), body, hashlib.sha256).hexdigest()
    req = request.Request(args.url, data=body, method='POST')
    req.add_header('Content-Type', 'application/json')
    req.add_header('X-Tired-Event', args.event)
    req.add_header('X-Tired-Signature', sig)
    if args.idempotency_key:
        req.add_header('Idempotency-Key', args.idempotency_key)

    try:
        with request.urlopen(req) as resp:
            out = resp.read().decode('utf-8', errors='ignore')
            print(f'[ok] {resp.status} {resp.reason}')
            if out:
                print(out)
    except Exception as e:
        raise SystemExit(f'[error] request failed: {e}')


if __name__ == '__main__':
    main()

