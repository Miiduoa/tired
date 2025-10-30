import express from 'express'
import morgan from 'morgan'
import cors from 'cors'
import helmet from 'helmet'
import { v4 as uuidv4 } from 'uuid'

const app = express()
app.use(helmet())
app.use(cors())
app.use(express.json())
app.use(morgan('dev'))

// In-memory stores (demo only)
const broadcasts = new Map() // id -> broadcast
const acks = new Map() // id -> Set(uid)
const clockRecords = [] // array of { id, uid, siteId, ts, gps }
const attendanceChecks = [] // array of { id, sessId, uid, ts }
const idempotency = new Map() // key -> { id, uid }
const esgRecords = [] // [{ id, userId, orgId, dataType, amount, unit, location, notes, carbonEmission, ts }]
const attendanceSessions = new Map() // sessId -> { id, courseId, policyId, open_at, close_at, qr_seed, status }
const uploads = new Map() // id -> { mime, buf }

// Helpers
const nowIso = () => new Date().toISOString()

// POST /v1/broadcasts
app.post('/v1/broadcasts', (req, res) => {
  const { groupId, title, body, cta } = req.body || {}
  if (!groupId || !title) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'groupId and title required' })
  }
  const id = 'bc_' + uuidv4().replace(/-/g, '').slice(0, 10)
  broadcasts.set(id, { id, groupId, title, body, cta, publishAt: nowIso() })
  return res.status(201).json({ broadcastId: id, scheduledNudges: [] })
})

// POST /v1/broadcasts/:id/ack
app.post('/v1/broadcasts/:id/ack', (req, res) => {
  const { id } = req.params
  const { uid, idempotencyKey } = req.body || {}
  if (!uid || !idempotencyKey) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'uid and idempotencyKey required' })
  }
  // Idempotency check
  const existed = idempotency.get(idempotencyKey)
  if (existed) {
    const same = existed.id === id && existed.uid === uid
    return same
      ? res.json({ status: 'ok' })
      : res.status(409).json({ code: 'E-IDEMP-409', message: 'idempotency key conflict' })
  }
  idempotency.set(idempotencyKey, { id, uid })
  if (!broadcasts.has(id)) {
    // Still consider ACK OK for demo (accept late/unknown) or return 404 in strict mode
    // return res.status(404).json({ code: 'E-SRV-404', message: 'broadcast not found' })
  }
  if (!acks.has(id)) acks.set(id, new Set())
  acks.get(id).add(uid)
  return res.json({ status: 'ok' })
})

// POST /v1/clock/records
app.post('/v1/clock/records', (req, res) => {
  const { uid, siteId, ts, gps } = req.body || {}
  if (!uid || !siteId || !ts) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'uid, siteId, ts required' })
  }
  const idem = req.get('Idempotency-Key') || ''
  if (idem) {
    const existed = idempotency.get(idem)
    if (existed) return res.json(existed)
  }
  const rec = { id: 'cr_' + uuidv4().replace(/-/g, '').slice(0, 10), uid, siteId, ts, gps: gps || null, status: 'ok' }
  clockRecords.unshift(rec)
  if (idem) idempotency.set(idem, rec)
  return res.status(201).json(rec)
})

// POST /v1/attendance/check
app.post('/v1/attendance/check', (req, res) => {
  const { sessId, uid, ts } = req.body || {}
  if (!sessId || !uid || !ts) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'sessId, uid, ts required' })
  }
  const idem = req.get('Idempotency-Key') || ''
  if (idem) {
    const existed = idempotency.get(idem)
    if (existed) return res.json(existed)
  }
  const rec = { id: 'ac_' + uuidv4().replace(/-/g, '').slice(0, 10), sessId, uid, ts, status: 'ok' }
  attendanceChecks.unshift(rec)
  if (idem) idempotency.set(idem, rec)
  return res.status(201).json(rec)
})

// POST /v1/upload (demo image upload)
app.post('/v1/upload', (req, res) => {
  const { fileBase64, mime } = req.body || {}
  if (!fileBase64) return res.status(400).json({ code: 'E-VAL-422', message: 'fileBase64 required' })
  const id = 'up_' + uuidv4().replace(/-/g, '').slice(0, 10)
  const buf = Buffer.from(fileBase64, 'base64')
  uploads.set(id, { mime: mime || 'image/jpeg', buf })
  const url = `${req.protocol}://${req.get('host')}/uploads/${id}`
  return res.json({ url, id })
})

// Serve uploaded content
app.get('/uploads/:id', (req, res) => {
  const it = uploads.get(req.params.id)
  if (!it) return res.status(404).end()
  res.setHeader('Content-Type', it.mime)
  res.send(it.buf)
})

// --- ESG endpoints (demo) ---
// POST /v1/esg/bill:ocr
app.post('/v1/esg/bill:ocr', (req, res) => {
  const { orgId, fileBase64 } = req.body || {}
  if (!fileBase64) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'fileBase64 required' })
  }
  // Demo parsing: pretend it's an electricity bill for 100 kWh in Taipei
  return res.json({
    orgId: orgId || 'demo-org',
    ocrJson: { ok: true },
    parsed: { dataType: 'electricity', amount: 100.0, unit: 'kWh', location: '台北市' },
    factorVersion: 'v2023.tw.local'
  })
})

// POST /v1/esg/report:generate
app.post('/v1/esg/report:generate', (req, res) => {
  const { orgId, parsed_fields, factorVersion } = req.body || {}
  if (!orgId || !parsed_fields) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'orgId and parsed_fields required' })
  }
  return res.json({
    orgId,
    month: new Date().toISOString().slice(0, 7),
    pdfRef: 'gs://tired-demo/esg/report-demo.pdf',
    assumptions: { factorVersion: factorVersion || 'v2023.tw.local' },
    evidenceRefs: []
  })
})

// GET /v1/esg/records?userId=&orgId=
app.get('/v1/esg/records', (req, res) => {
  const { userId, orgId } = req.query
  let out = esgRecords
  if (userId) out = out.filter(r => r.userId === userId)
  if (orgId) out = out.filter(r => r.orgId === orgId)
  res.json({ items: out })
})

// POST /v1/esg/records
app.post('/v1/esg/records', (req, res) => {
  const { userId, orgId, dataType, amount, unit, location, notes } = req.body || {}
  if (!userId || !dataType || typeof amount !== 'number' || !unit) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'userId, dataType, amount, unit required' })
  }
  // Simple factor map (demo)
  const factors = { electricity: { unit: 'kWh', v: 0.509 }, water: { unit: 'L', v: 0.0003 }, gas: { unit: 'm3', v: 2.162 }, transportation: { unit: 'km', v: 0.192 } }
  const f = factors[dataType] || { v: 1.0 }
  const carbonEmission = amount * f.v
  const rec = {
    id: 'rec_' + uuidv4().replace(/-/g, '').slice(0, 10),
    userId,
    orgId: orgId || null,
    dataType,
    amount,
    unit,
    location: location || null,
    notes: notes || null,
    carbonEmission,
    ts: nowIso()
  }
  esgRecords.unshift(rec)
  res.status(201).json(rec)
})

// POST /v1/attendance/sessions
app.post('/v1/attendance/sessions', (req, res) => {
  const { courseId, policyId, open_at, close_at } = req.body || {}
  if (!courseId || !policyId || !open_at || !close_at) {
    return res.status(400).json({ code: 'E-VAL-422', message: 'courseId, policyId, open_at, close_at required' })
  }
  const id = 'sess_' + uuidv4().replace(/-/g, '').slice(0, 10)
  const qr_seed = id // simple: use id as seed
  const sess = { id, courseId, policyId, open_at, close_at, qr_seed, status: 'open' }
  attendanceSessions.set(id, sess)
  return res.status(201).json(sess)
})

// POST /v1/attendance/sessions/:id/close
app.post('/v1/attendance/sessions/:id/close', (req, res) => {
  const { id } = req.params
  const sess = attendanceSessions.get(id)
  if (!sess) return res.status(404).json({ code: 'E-SRV-404', message: 'session not found' })
  sess.status = 'closed'
  return res.json(sess)
})

// Health
app.get('/healthz', (_req, res) => res.json({ ok: true, ts: nowIso() }))

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`tired-backend listening on http://localhost:${port}`)
})
