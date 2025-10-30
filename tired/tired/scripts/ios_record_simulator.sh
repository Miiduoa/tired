#!/usr/bin/env bash
# Record Simulator screen to a .mov file using simctl.
#
# Usage:
#   OUT=demo.mov ./scripts/ios_record_simulator.sh
#   DEVICE="iPhone 15" OUT=demo.mov ./scripts/ios_record_simulator.sh
#   # Press Ctrl-C to stop recording.

set -euo pipefail

DEVICE=${DEVICE:-booted}
OUT=${OUT:-simulator_recording.mov}
CODEC=${CODEC:-h264}

if [[ "$DEVICE" != "booted" ]]; then
  echo "[info] Booting simulator: $DEVICE"
  xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$DEVICE" -b
fi

echo "[rec] Recording $DEVICE → $OUT (codec=$CODEC). Press Ctrl-C to stop."
xcrun simctl io booted recordVideo --codec=$CODEC "$OUT"

