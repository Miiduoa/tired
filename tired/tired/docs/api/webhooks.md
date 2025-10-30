# Webhooks（事件通知）

對應 PRD §8，伺服器端在關鍵事件發生時以 HTTP POST 發送到租戶設定的 webhook endpoint。

## 事件清單

- message.ack
- attendance.closed
- clock.recorded
- esg.report.ready
- policy.violation
- unmask.approved

## 共通欄位

- id: 事件ID（Snowflake/UUID）
- type: 事件類型（如 `message.ack`）
- ts: ISO8601 時間戳
- orgId: 組織ID（可選）
- groupId: 群組ID（可選）
- version: schema 版本

## 負載樣板

```json
{
  "id": "evt_123",
  "type": "message.ack",
  "ts": "2025-10-24T01:23:45Z",
  "orgId": "ORG_1",
  "groupId": "G_1",
  "version": "v1",
  "data": {
    "messageId": "MSG_1",
    "channelId": "CH_1",
    "uid": "U_1"
  }
}
```

## 安全與重試

- 簽章：`X-Tired-Signature`（HMAC-SHA256）
- 重試：指數退避，最多 24h；去重 `idempotency-key`
- 隱私：PII 不入 payload；必要時提供 aliasId

## 事件負載範例（完整）

message.ack

```json
{
  "id": "evt_01H…",
  "type": "message.ack",
  "ts": "2025-10-24T01:23:45Z",
  "orgId": "ORG_1",
  "groupId": "G_1",
  "version": "v1",
  "data": { "messageId": "MSG_1", "channelId": "CH_1", "uid": "U_1" }
}
```

attendance.closed

```json
{
  "id": "evt_01H…",
  "type": "attendance.closed",
  "ts": "2025-10-24T02:00:00Z",
  "orgId": "ORG_1",
  "groupId": "G_CLASS",
  "version": "v1",
  "data": { "sessId": "S_1", "courseId": "C_1", "policyId": "P_1", "total": 52, "flagged": 3 }
}
```

clock.recorded

```json
{
  "id": "evt_01H…",
  "type": "clock.recorded",
  "ts": "2025-10-24T02:10:00Z",
  "orgId": "ORG_2",
  "version": "v1",
  "data": { "recordId": "CR_1", "uid": "U_9", "siteId": "SITE_A", "status": "ok" }
}
```

esg.report.ready

```json
{
  "id": "evt_01H…",
  "type": "esg.report.ready",
  "ts": "2025-10-24T03:00:00Z",
  "orgId": "ORG_3",
  "version": "v1",
  "data": { "month": "2025-09", "factorVersion": "CN-DEFRA-2025.09" }
}
```

policy.violation

```json
{
  "id": "evt_01H…",
  "type": "policy.violation",
  "ts": "2025-10-24T03:10:00Z",
  "orgId": "ORG_1",
  "groupId": "G_1",
  "version": "v1",
  "data": { "policy": "keyword_block", "actor": "U_2", "target": "MSG_9", "reason": "blocked_term" }
}
```

unmask.approved

```json
{
  "id": "evt_01H…",
  "type": "unmask.approved",
  "ts": "2025-10-24T03:20:00Z",
  "orgId": "ORG_SEC",
  "version": "v1",
  "data": { "requestId": "UM_1", "approvers": ["U_HR","U_DPO"], "delay_notified": true }
}
```

## 簽章驗證（驗簽）

簽章計算方式：`hex(hmac_sha256(secret, raw_body))`，伺服器以租戶的 webhook secret 計算後放入 `X-Tired-Signature`。

注意：務必取得「原始請求本文 raw body」再做 HMAC，避免被 JSON re-encode 破壞。並採常數時間比較，防止時序旁路。

Node.js（Express）

```js
import crypto from 'crypto'
import express from 'express'

const app = express()
app.use('/webhooks/tired', express.raw({ type: 'application/json' }))

const SECRET = process.env.TIRED_WEBHOOK_SECRET

function safeEqual(a, b) {
  const ab = Buffer.from(a, 'utf8')
  const bb = Buffer.from(b, 'utf8')
  if (ab.length !== bb.length) return false
  return crypto.timingSafeEqual(ab, bb)
}

app.post('/webhooks/tired', (req, res) => {
  const signature = req.header('X-Tired-Signature') || ''
  const event = req.header('X-Tired-Event') || ''
  const idem = req.header('Idempotency-Key') || ''

  const raw = req.body // Buffer from express.raw
  const expected = crypto.createHmac('sha256', SECRET).update(raw).digest('hex')
  if (!safeEqual(signature, expected)) return res.status(401).send('invalid signature')

  // TODO: de-duplicate by idempotency key or event.id
  const payload = JSON.parse(raw.toString('utf8'))
  // handle by payload.type
  res.sendStatus(200)
})

app.listen(3000)
```

Python（Flask）

```py
import hmac, hashlib
from flask import Flask, request, abort

app = Flask(__name__)
SECRET = b'your_shared_secret'

def verify(body: bytes, signature: str) -> bool:
    digest = hmac.new(SECRET, body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(digest, signature or '')

@app.post('/webhooks/tired')
def tired_webhook():
    sig = request.headers.get('X-Tired-Signature', '')
    if not verify(request.get_data(), sig):
        abort(401)
    # idempotency: use header `Idempotency-Key` or payload['id']
    payload = request.get_json()
    return ('', 200)

if __name__ == '__main__':
    app.run(port=3000)
```

## 本地測試（最小伺服器）

- Node（無相依）：`scripts/webhook_test_server_node.js:1`
  - `TIRED_WEBHOOK_SECRET=your_secret PORT=3000 node scripts/webhook_test_server_node.js`
- Python（無相依）：`scripts/webhook_test_server_py.py:1`
  - `TIRED_WEBHOOK_SECRET=your_secret PORT=3000 python3 scripts/webhook_test_server_py.py`

## 發送測試（curl 與腳本）

curl（以 message.ack 範例為例）：

```bash
SECRET=your_secret
URL=http://localhost:3000/webhooks/tired
PAYLOAD=tired/docs/api/examples/message.ack.json

SIG=$(openssl dgst -sha256 -hmac "$SECRET" -hex "$PAYLOAD" | awk '{print $2}')
curl -sS -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "X-Tired-Event: message.ack" \
  -H "X-Tired-Signature: $SIG" \
  --data @"$PAYLOAD"
```

Python 腳本：

```bash
python3 scripts/send_webhook.py \
  --url http://localhost:3000/webhooks/tired \
  --secret your_secret \
  --event message.ack \
  --file tired/docs/api/examples/message.ack.json
```

## 公網實測（可選）

使用 ngrok 或 Cloudflare Tunnel 將本地端點暴露到公網並接受平台回呼：

- ngrok：`ngrok http 3000` → 取得公開 URL，例如 `https://abc123.ngrok.io/webhooks/tired`
- Cloudflare Tunnel：`cloudflared tunnel --url http://localhost:3000`

在租戶管理端或透過 API `POST /v1/webhooks/register` 設定 `callbackUrl` 為上述公開 URL。

## 去重（Idempotency）

- 優先使用 `Idempotency-Key`（若提供）與事件 `id` 做去重 Key。
- 建議保存處理結果 24 小時（或直到下一次成功同步），避免重放。

## 安全建議

- 驗簽必做，並建議白名單來源 IP（如能提供）。
- 僅信任列舉的 `X-Tired-Event` 類型；忽略未知事件。
- Payload 不含 PII；如需識別對象，優先使用 alias 或資源 ID。
