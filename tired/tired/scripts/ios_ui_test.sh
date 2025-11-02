#!/usr/bin/env bash
# Run iOS UI tests with auto-detected simulator and autologin flag.
set -euo pipefail

SCHEME=${SCHEME:-tired}
PROJECT=${PROJECT:-tired/tired.xcodeproj}
CONFIG=${CONFIG:-Debug}
DEVICE=${DEVICE:-iPhone 17 Pro}

# pick device (same logic as ios_build_run.sh, simplified)
pick=$(python3 - <<'PY' || true
import json, subprocess, os, re
def load():
    try:
        j = subprocess.check_output(['xcrun','simctl','list','devices','available','-j'])
        return json.loads(j.decode())['devices']
    except Exception:
        return {}
target=os.environ.get('DEVICE','').strip()
pref=['iPhone 17 Pro','iPhone 17','iPhone 16 Pro','iPhone 16','iPhone 15 Pro','iPhone 15']
def vtuple(v):
    try: return tuple(int(x) for x in v.split('.'))
    except: return (0,)
best=None
for runtime,devs in load().items():
    m=re.match(r'iOS\s+(\d+\.(?:\d+)?)', runtime)
    ver=m.group(1) if m else ''
    for d in devs:
        if not d.get('isAvailable'): continue
        name=d.get('name','')
        if 'iPhone' not in name: continue
        if target and target not in name: continue
        score=(name in pref, vtuple(ver))
        if best is None or score>best[0]:
            best=(score,(name,ver,d.get('udid','')))
if best:
    name,ver,udid=best[1]
    print('%s|%s|%s'%(name,ver,udid))
PY
)

if [[ -n "$pick" ]]; then
  IFS='|' read -r PICK_NAME PICK_OS PICK_UDID <<<"$pick"
  DEST="platform=iOS Simulator,id=$PICK_UDID"
  echo "[info] Booting simulator: $PICK_NAME ($PICK_UDID)"
  xcrun simctl boot "$PICK_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$PICK_UDID" -b
else
  DEST="platform=iOS Simulator,name=$DEVICE"
fi

echo "[info] Running UI tests on $DEST"
set -x
xcodebuild test -scheme "$SCHEME" -project "$PROJECT" -configuration "$CONFIG" \
  -destination "$DEST" \
  -only-testing:tiredUITests
set +x
echo "[done] UI tests finished"
