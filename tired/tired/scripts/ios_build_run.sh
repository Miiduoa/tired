#!/usr/bin/env bash
# Build the iOS app for Simulator, install and launch on a chosen device.
#
# Usage:
#   DEVICE="iPhone 17 Pro" ./scripts/ios_build_run.sh
#   # or rely on autodetect if not set
#
set -euo pipefail

SCHEME=${SCHEME:-tired}
PROJECT=${PROJECT:-tired/tired.xcodeproj}
CONFIG=${CONFIG:-Debug}
DEVICE=${DEVICE:-iPhone 17 Pro}
DERIVED=${DERIVED:-.derived}
BUNDLE_ID=${BUNDLE_ID:-tw.pu.tiredteam.tired}

# Pick a best-fit available simulator (name|os|udid)
pick=$(python3 - <<'PY' || true
import json, subprocess, os, re, sys
def load():
    try:
        j = subprocess.check_output(['xcrun','simctl','list','devices','available','-j'])
        return json.loads(j.decode())['devices']
    except Exception:
        return {}
target = os.environ.get('DEVICE','').strip()
devices = load()
cands = []
for runtime, devs in devices.items():
    m = re.match(r'iOS\s+(\d+\.(?:\d+)?)', runtime)
    ver = m.group(1) if m else ''
    for d in devs:
        if not d.get('isAvailable'): continue
        name = d.get('name','')
        if 'iPhone' not in name: continue
        if target and name != target: continue
        cands.append((name, ver, d.get('udid','')))
if not cands and target:
    # fallback: fuzzy contains
    for runtime, devs in devices.items():
        m = re.match(r'iOS\s+(\d+\.(?:\d+)?)', runtime)
        ver = m.group(1) if m else ''
        for d in devs:
            if not d.get('isAvailable'): continue
            name = d.get('name','')
            if 'iPhone' in name and target in name:
                cands.append((name, ver, d.get('udid','')))
if not cands:
    # any iPhone
    for runtime, devs in devices.items():
        m = re.match(r'iOS\s+(\d+\.(?:\d+)?)', runtime)
        ver = m.group(1) if m else ''
        for d in devs:
            if d.get('isAvailable') and 'iPhone' in d.get('name',''):
                cands.append((d['name'], ver, d.get('udid','')))
if not cands:
    sys.exit(0)
pref = ['iPhone 17 Pro','iPhone 17 Pro Max','iPhone 17','iPhone 16 Pro','iPhone 16','iPhone 15 Pro','iPhone 15']
def vtuple(v):
    try:
        return tuple(int(x) for x in v.split('.'))
    except Exception:
        return (0,)
cands.sort(key=lambda t: (t[0] in pref, vtuple(t[1])), reverse=True)
name, ver, udid = cands[0]
print(f"{name}|{ver}|{udid}")
PY
)

if [[ -n "$pick" ]]; then
  IFS='|' read -r PICK_NAME PICK_OS PICK_UDID <<<"$pick"
  DEVICE="$PICK_NAME"
  DEST="platform=iOS Simulator,name=$PICK_NAME"
  if [[ -n "${PICK_OS:-}" ]]; then DEST+="\,OS=$PICK_OS"; fi
else
  DEST="platform=iOS Simulator,name=$DEVICE"
fi

echo "[info] Building scheme=$SCHEME device=$DEVICE configuration=$CONFIG"
xcodebuild -scheme "$SCHEME" -project "$PROJECT" -configuration "$CONFIG" \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" build >/dev/null

APP_PATH=$(ls -d "$DERIVED"/Build/Products/*-iphonesimulator/tired.app | head -n 1)
if [[ ! -d "$APP_PATH" ]]; then
  echo "[error] app path not found under $DERIVED/Build/Products" >&2
  exit 2
fi

if [[ -n "${PICK_UDID:-}" ]]; then
  echo "[info] Booting simulator (udid): $DEVICE ($PICK_UDID)"
  xcrun simctl boot "$PICK_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$PICK_UDID" -b
else
  echo "[info] Booting simulator: $DEVICE"
  xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$DEVICE" -b
fi

echo "[info] Installing: $APP_PATH"
xcrun simctl install booted "$APP_PATH"

echo "[info] Launching: $BUNDLE_ID"
xcrun simctl launch booted "$BUNDLE_ID" || true
echo "[done] App launched on $DEVICE"
