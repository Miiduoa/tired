#!/usr/bin/env bash
# Build the iOS app for Simulator, install and launch on a chosen device.
#
# Usage:
#   DEVICE="iPhone 15" ./scripts/ios_build_run.sh
#   # or default DEVICE if not set
#
set -euo pipefail

SCHEME=${SCHEME:-tired}
PROJECT=${PROJECT:-tired/tired.xcodeproj}
CONFIG=${CONFIG:-Debug}
DEVICE=${DEVICE:-iPhone 15}
DERIVED=${DERIVED:-.derived}
BUNDLE_ID=${BUNDLE_ID:-tw.pu.tiredteam.tired}

echo "[info] Building scheme=$SCHEME device=$DEVICE configuration=$CONFIG"
xcodebuild -scheme "$SCHEME" -project "$PROJECT" -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$DERIVED" build >/dev/null

APP_PATH=$(ls -d "$DERIVED"/Build/Products/*-iphonesimulator/tired.app | head -n 1)
if [[ ! -d "$APP_PATH" ]]; then
  echo "[error] app path not found under $DERIVED/Build/Products" >&2
  exit 2
fi

echo "[info] Booting simulator: $DEVICE"
xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b

echo "[info] Installing: $APP_PATH"
xcrun simctl install booted "$APP_PATH"

echo "[info] Launching: $BUNDLE_ID"
xcrun simctl launch booted "$BUNDLE_ID" || true
echo "[done] App launched on $DEVICE"

