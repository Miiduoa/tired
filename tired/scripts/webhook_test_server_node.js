#!/usr/bin/env node
/**
 * Minimal webhook test server (Node, no deps)
 * - Verifies X-Tired-Signature (HMAC-SHA256 over raw body)
 * - Prints event id/type and payload
 *
 * Usage:
 *   TIRED_WEBHOOK_SECRET=your_secret PORT=3000 node scripts/webhook_test_server_node.js
 *   Endpoint: http://localhost:3000/webhooks/tired
 */
const http = require('http');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '3000', 10);
const SECRET = process.env.TIRED_WEBHOOK_SECRET || '';

function timingSafeEqualHex(a, b) {
  try {
    const ab = Buffer.from(a, 'utf8');
    const bb = Buffer.from(b, 'utf8');
    if (ab.length !== bb.length) return false;
    return crypto.timingSafeEqual(ab, bb);
  } catch {
    return false;
  }
}

const server = http.createServer((req, res) => {
  if (req.method !== 'POST' || !req.url.startsWith('/webhooks/tired')) {
    res.statusCode = 404;
    return res.end('Not found');
  }

  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    const raw = Buffer.concat(chunks);
    const eventType = req.headers['x-tired-event'] || '';
    const signature = req.headers['x-tired-signature'] || '';
    const idem = req.headers['idempotency-key'] || '';

    if (!SECRET) {
      console.error('[warn] TIRED_WEBHOOK_SECRET missing; skipping signature verification');
    }

    if (SECRET) {
      const expected = crypto.createHmac('sha256', SECRET).update(raw).digest('hex');
      if (!timingSafeEqualHex(String(signature), expected)) {
        console.error('[err] invalid signature');
        res.statusCode = 401;
        return res.end('invalid signature');
      }
    }

    let payload;
    try {
      payload = JSON.parse(raw.toString('utf8'));
    } catch (e) {
      res.statusCode = 400;
      return res.end('invalid json');
    }

    const id = payload.id || '(no-id)';
    console.log(`\n[ok] event ${id} ${eventType}`);
    if (idem) console.log(`idempotency-key: ${idem}`);
    console.log(JSON.stringify(payload, null, 2));

    res.statusCode = 200;
    res.end('ok');
  });
});

server.listen(PORT, () => {
  console.log(`[listening] http://localhost:${PORT}/webhooks/tired`);
});

