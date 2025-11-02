#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <chat|attendance> <id>" >&2
  exit 1
fi

kind="$1"
id="$2"

case "$kind" in
  chat)
    url="tired://chat?cid=$id"
    ;;
  attendance)
    url="tired://attendance?sessId=$id"
    ;;
  *)
    echo "Unknown kind: $kind (expected chat|attendance)" >&2
    exit 1
    ;;
esac

echo "Opening deep link: $url"
xcrun simctl openurl booted "$url"

