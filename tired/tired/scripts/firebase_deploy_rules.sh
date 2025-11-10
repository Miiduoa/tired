#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."

RULES="$ROOT/firebase/firestore.rules"

if ! command -v firebase >/dev/null 2>&1; then
  echo "[!] Firebase CLI not found. Install via: npm i -g firebase-tools"
  exit 1
fi

echo "Deploying Firestore rules from: $RULES"
firebase deploy --only firestore:rules --project "$(jq -r '.projectId // empty' < /dev/null 2>/dev/null || echo '')" --force || firebase deploy --only firestore:rules

echo "Done."

