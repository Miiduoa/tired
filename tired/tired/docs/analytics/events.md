## Analytics Events and A/B Instrumentation (Draft)

### Core Events (server-sourced unless noted)

- message.ack
  - props: { messageId, channelId, uid, ts }
- attendance.closed
  - props: { sessId, courseId, policyId, total, flagged, ts }
- clock.recorded
  - props: { recordId, uid, siteId, status, ts }
- esg.report.ready
  - props: { orgId, month, factorVersion, ts }
- policy.violation
  - props: { policy, actor, target, reason, ts }
- unmask.approved
  - props: { requestId, approvers:[uid], delay_notified:bool, ts }

### Client UX Events (iOS)

- inbox.opened { section }
- broadcast.opened { messageId }
- broadcast.cta { messageId, type:ack|form|vote }
- dm.requested { toUid }
- profile.preview_mode { mode: stranger|friend|group|admin|custom }
- profile.field_visibility_changed { key, mode }

### A/B Experiments (from PRD)

- experiment: broadcast_nudges
  - variant: D-1/H-2/H-0 vs D-1/H-1
  - KPI: ack/read within 24h
- experiment: cbt_card_template
  - variant: A vs B
  - KPI: on-time delivery +7d
- experiment: attendance_anticheat
  - variant: thresholds/QR rotate/geofence
  - KPI: false positive rate <1%, intercept >80%
- experiment: esg_ocr_model
  - variant: model A vs B
  - KPI: F1 ≥ 0.97

### Event Contract Conventions

- All events include: { ts, uid? (when applicable), orgId?, groupId? }.
- PII is never logged; alias preferred where applicable.
- Version fields on model-based events (e.g., factorVersion).

