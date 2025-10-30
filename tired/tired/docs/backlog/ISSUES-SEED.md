# GitHub Issues Seed（對應 ENG-BACKLOG-P0-P2）

建議以粗粒度 Issue 對應工作包，並用 Milestones 對應 M1–M4。
若使用 GitHub CLI，可執行 scripts/seed_github_issues.sh 自動建立。

## Milestones

- M1（W1–W2）：Groups/Channels、Broadcast+Ack、Basic Inbox
- M2（W3–W4）：Attendance（policy/session/check）、Clock basic
- M3（W5–W6）：Activities/Votes、Moderation、Profiles（visibility）
- M4（W7–W8）：Hardening、Dashboards skeleton、P1 kick-off

## Issues（建議標籤：backend + 專屬領域）

1) API and Data Models (P0)
- AC：OpenAPI v1、Auth bearer/claims、Firestore schemas/indexes

2) Messaging (P0): Channels/Broadcast/DM
- AC：Channel modes、Broadcast+CTA+Resend、DM request+block/report

3) Attendance (P0)
- AC：Policy validate（window/dwell/QR/GPS/BLE）、Session open/close、Check endpoint

4) Clock In/Out (P0)
- AC：Geofence、Record（ok/exception）、Amend/Review/Audit

5) Activities & Votes (P0)
- AC：Event+QR ticket+scan once、Poll single/multi+deadline

6) Moderation + Audit (P0)
- AC：Keyword block+rate、Report+mute/alias、Admin actions audit

7) Profiles (P0 subset + P1)
- AC：Per-field visibility、Scoped profile（avatar/alias per group）、Temp share token

8) ESG OCR → Report (P1)
- AC：OCR key fields+confidence、Report draft（factorVersion+assumptions+sources）

9) Unmask dual-sign + export (P1)
- AC：Two approvers+reason、Delayed notify、Audit export（CSV）

> 參考：docs/ENG-BACKLOG-P0-P2.md:1 與 docs/PRD-v1.md:1

