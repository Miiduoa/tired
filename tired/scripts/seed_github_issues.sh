#!/usr/bin/env bash
# Seed GitHub milestones and issues from ENG backlog.
# Requirements: GitHub CLI (gh), authenticated (`gh auth login`).
# Usage:
#   repo must be the current directory's remote (git remote -v) or set GH_REPO.

set -euo pipefail

function ensure_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "[error] gh CLI not found. Install: https://cli.github.com/" >&2
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "[error] gh not authenticated. Run: gh auth login" >&2
    exit 1
  fi
}

function ensure_milestone() {
  local title="$1"; shift
  local desc="$1"; shift
  if ! gh milestone list --limit 100 | awk '{print $1}' | grep -Fxq "$title"; then
    gh milestone create "$title" --description "$desc" --due-date "$(date -v+30d +%Y-%m-%d 2>/dev/null || date -d "+30 days" +%Y-%m-%d)" >/dev/null
    echo "[ok] milestone created: $title"
  else
    echo "[=] milestone exists: $title"
  fi
}

function create_issue() {
  local title="$1"; shift
  local body="$1"; shift
  local milestone="$1"; shift
  local labels="$1"; shift
  gh issue create --title "$title" --body "$body" --milestone "$milestone" --label "$labels" >/dev/null
  echo "[ok] issue: $title ($milestone)"
}

ensure_gh

# Milestones (from docs/ENG-BACKLOG-P0-P2.md)
ensure_milestone "M1" "Weeks 1–2: Groups, Channels, Broadcast+Ack, basic inbox"
ensure_milestone "M2" "Weeks 3–4: Attendance (policy/session/check), Clock basic"
ensure_milestone "M3" "Weeks 5–6: Activities/Votes, Moderation, Profiles (visibility)"
ensure_milestone "M4" "Weeks 7–8: Hardening, dashboards skeleton, P1 kick-off"

# Issues (coarse-grained, each includes AC summary)
create_issue "API and Data Models (P0)" \
"- Define OpenAPI for v1 endpoints\n- Auth envelope (bearer, orgId/groupId claims)\n- Firestore schemas/indexes per PRD" \
"M1" "P0,backend,api"

create_issue "Messaging (P0): Channels/Broadcast/DM" \
"- Channel modes enforced; alias hides RealID\n- Broadcast + CTA ack + resend schedule\n- DM request + block/report" \
"M1" "P0,backend,messaging"

create_issue "Attendance (P0)" \
"- Policy create/validate (window, dwell, QR rotate, GPS/BLE)\n- Session open/close (rotate seed)\n- Check endpoint writes attendance_checks" \
"M2" "P0,backend,attendance"

create_issue "Clock In/Out (P0)" \
"- Site geofence + whitelist\n- Record endpoint (ok/exception)\n- Amend + review + audit" \
"M2" "P0,backend,clock"

create_issue "Activities & Votes (P0)" \
"- Event create + ticket QR + scan once\n- Poll single/multi, deadline enforcement" \
"M3" "P0,backend,activities"

create_issue "Moderation + Audit (P0)" \
"- Keyword block + rate limit\n- Report + mute/close alias\n- All admin actions audited" \
"M3" "P0,backend,moderation,audit"

create_issue "Profiles (P0 subset + P1)" \
"- Per-field visibility, viewer/group-scoped view\n- Scoped profile (avatar/alias per group)\n- Temporary share token + revoke" \
"M3" "P0,P1,backend,profiles"

create_issue "ESG OCR → Report (P1)" \
"- OCR returns key fields with confidences\n- Report draft includes factorVersion, assumptions, sources" \
"M4" "P1,backend,esg"

create_issue "Unmask dual-sign + export (P1)" \
"- Request + approve with two approvers + reason code\n- Optional delayed notify\n- Audit export (CSV window)" \
"M4" "P1,backend,compliance"

echo "\n[done] Seeded milestones and issues. Review on GitHub."

