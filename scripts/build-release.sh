#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building XM6Hub (${CONFIGURATION})"
xcodebuild \
  -project XM6Hub.xcodeproj \
  -scheme XM6Hub \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  build

APP="$DERIVED_DATA/Build/Products/${CONFIGURATION}/XM6Hub.app"
if [[ ! -d "$APP" ]]; then
  echo "Build failed: app not found at $APP" >&2
  exit 1
fi

mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/XM6Hub.app"
ditto "$APP" "$ROOT/dist/XM6Hub.app"

echo "==> Built $ROOT/dist/XM6Hub.app"
