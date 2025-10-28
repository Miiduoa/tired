## Engineering Backlog (Derived from PRD v1)

Legend: [P0|P1|P2] priority; each item has short acceptance criteria (AC).

### Epics (P0)

- Groups + Capability Packs
  - Create group with type → auto-attach pack (AC: POST /v1/groups creates group, computed default pack; verify stored fields match PRD model)
  - Add-ons attach/detach (AC: PATCH group add-ons updates and logged)
  - Verification levels L0–L3 policy gates (AC: feature-flag gates enforce access)

- Unified Inbox + Messaging
  - Channels: off/broadcast/normal/alias (AC: channel mode enforcement, alias hides RealID)
  - Broadcast with ack/form/vote CTA (AC: delivery + ack status tracked; resend nudges at D-1/H-2/H-0)
  - DM policy: off/members/open(request) (AC: request flow + block/report + slow mode)
  - Attachments: image/file/form/poll (AC: metadata persisted; upload tokens scoped)
  - Moderation hooks (AC: keyword blocklist, report → audit log)

- Attendance (10-sec, time-configurable)
  - Policy create/apply/override per session (AC: window open/close; dwell; late threshold)
  - Anti-cheat signals: QR seed rotate, GPS/BLE, device hash (AC: recorded in attendance_checks)
  - Close and score via isolation forest (AC: risk flagging above threshold)

- Clock In/Out
  - Site geofence + whitelist (AC: within geofence to record)
  - Amend + review (AC: pending → reviewed status; audit noted)

- Activities/Votes
  - Event creation, ticket QR, scan (AC: admit once; log entry)
  - Poll with single/multi choice (AC: vote tally, deadline)

### Epics (P1)

- SSO/SCIM (AC: IdP config, user provisioning; org-bound roles)
- Anonymous Q&A (AC: alias questions; admin can reveal via dual-sign)
- ESG OCR → Report (AC: OCR JSON → factor apply → draft PDF)
- Dashboards (class/department) (AC: simple tiles: attendance, acks, hotspots)
- Dual-sign Unmask + Audit export (AC: two approvers + reason code + delayed notify option
  ; export CSV of audits window)

### Epics (P2)

- Paystub view (encrypted blob) (AC: publish → client decrypt in-memory → auto-evict cache)
- LMS/HRIS bidirectional (AC: webhook + CSV sync; conflict policy)
- On-device AI (AC: local summarization/emotion; fallback cloud)
- HSM/Tenant keys (AC: org keys referenced; server uses KMS/HSM envelope)
- Smart meter/email bill ingest (AC: auto-fetch, parse schedule)

---

## Work Items with Acceptance Criteria

### 1) API and Data Models (P0)

- Define OpenAPI for v1 endpoints (AC: api/openapi.yaml exists; CI validates; schemas match PRD fields subset)
- Implement auth envelope (AC: bearer auth; orgId/groupId claims present or resolvable)
- Firestore schemas and indexes (AC: rules + indexes file; query perf acceptable for listed indexes)

### 2) Messaging (P0)

- Create Channel (AC: channel modes enforced on post; requires_ack persisted when broadcast)
- Broadcast flow (AC: write message + CTA; recipients see CTA; ack stored; resend schedule created)
- DM request and block/report (AC: unknown sender → requests inbox; block prevents future; report writes audit)

### 3) Attendance (P0)

- Policy entity + validation (AC: start/end offsets OR absolute times; GPS/BLE flags validated)
- Session open/close (AC: open emits rotating QR seed; close tallies and emits event)
- Check endpoint (AC: verifies QR + GPS/BLE + device hash; writes attendance_checks)

### 4) Clock (P0)

- Record endpoint (AC: inside site geofence; record created with status normal/exception)
- Amend + review (AC: amend requests flagged; reviewer resolves; audit written)

### 5) Activities/Votes (P0)

- Event create + ticket issuance (AC: ticket QR valid once; gate scan marks used)
- Poll create + vote (AC: single/multi select; deadline enforcement)

### 6) Moderation + Audit (P0)

- Keyword block + rate limit (AC: blocked messages rejected with reason; per-user/channel limits)
- Report + mute/close alias (AC: admin action writes audit; alias mode toggle)

### 7) Profiles (P0 subset + P1)

- Per-field visibility settings (AC: GET profile filters fields by viewer context and group)
- Scoped profile per group (AC: avatar/alias override by groupId)
- Temporary share token (P1) (AC: token grants subset fields to scoped audience until expiry; revocable)

### 8) ESG (P1)

- OCR endpoint (AC: returns key fields with confidences; stores ocrJson)
- Report draft (AC: includes factorVersion, assumptions, sources list)

### 9) Unmask (P1)

- Request/approve (AC: two approvers; reasonCode; audit; optional delayed notify)

---

## Non-Functional & Guardrails

- E2EE policy (AC: DM is E2EE; group chat per verification policy)
- Retention policy enforcement (AC: keep_days, legal_hold; delete upon TTL)
- Audit trail completeness (AC: all admin actions + policy changes logged)
- Abuse prevention (AC: rate limits + risk scores recorded)

---

## Suggested Milestones

- M1 (Weeks 1–2): Groups, Channels, Broadcast+Ack, basic inbox
- M2 (Weeks 3–4): Attendance (policy/session/check), Clock basic
- M3 (Weeks 5–6): Activities/Votes, Moderation, Profiles (visibility)
- M4 (Weeks 7–8): Hardening, dashboards skeleton, P1 kick-off

