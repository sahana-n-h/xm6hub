#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build-release.sh"

APP="$ROOT/dist/XM6Hub.app"
TARGET="/Applications/XM6 Hub.app"

echo "==> Installing to $TARGET"
rm -rf "$TARGET"
ditto "$APP" "$TARGET"
xattr -cr "$TARGET"

echo "==> Done. Launching XM6 Hub"
open "$TARGET"
