#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodegen generate
xcodebuild -project XM6Hub.xcodeproj -scheme XM6Hub -configuration Debug build

APP=$(find ~/Library/Developer/Xcode/DerivedData/XM6Hub-*/Build/Products/Debug/XM6Hub.app -maxdepth 0 -newer "$ROOT/project.yml" 2>/dev/null | head -1)
if [[ -z "$APP" ]]; then
  APP=$(find ~/Library/Developer/Xcode/DerivedData/XM6Hub-*/Build/Products/Debug/XM6Hub.app -maxdepth 0 2>/dev/null | sort | tail -1)
fi

echo "Launching $APP"
open "$APP"
