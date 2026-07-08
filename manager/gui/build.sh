#!/usr/bin/env bash
# manager/gui/build.sh — build the self-contained "RTL Manager.app": the SwiftUI menu-bar app
# PLUS the runtime it drives (manager/ + official-runtime/ + dist/payload.js) copied into
# Resources, so the shipped .app resolves everything relatively and needs no checked-out repo.
# Ad-hoc signed — no Apple Developer Program needed. (The build machine needs Node once, to
# produce dist/payload.js.)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR"

echo "manager: building payload (one-time, needs Node)…"
( cd "$REPO" && node build/build-payload.js >/dev/null )

echo "manager: compiling the Swift app…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/RTLManager"
[ -f "$BIN" ] || { echo "manager: binary not found at $BIN" >&2; exit 1; }

APP="$SCRIPT_DIR/dist/RTL Manager.app"
RES="$APP/Contents/Resources"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RES"
cp "$BIN" "$APP/Contents/MacOS/RTLManager"

echo "manager: bundling the runtime into Resources (self-contained)…"
# Preserve the repo layout so manager/core/adapter-control.sh resolves ROOT -> Resources and
# finds official-runtime/ + dist/payload.js exactly where it expects them.
mkdir -p "$RES/manager" "$RES/official-runtime" "$RES/dist"
cp -R "$REPO/manager/adapters" "$RES/manager/adapters"
cp -R "$REPO/manager/core"     "$RES/manager/core"
cp -R "$REPO/official-runtime/macos" "$RES/official-runtime/macos"
cp    "$REPO/dist/payload.js"  "$RES/dist/payload.js"
chmod +x "$RES/manager/core/"*.sh "$RES/official-runtime/macos/"*.sh 2>/dev/null || true

VERSION="$(tr -d ' \t\n' < "$REPO/VERSION" 2>/dev/null || echo 0.0.0)"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>RTL Manager</string>
  <key>CFBundleDisplayName</key><string>Claude RTL Manager</string>
  <key>CFBundleIdentifier</key><string>com.claude-rtl.manager.adapters</string>
  <key>CFBundleExecutable</key><string>RTLManager</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHumanReadableCopyright</key><string>MIT — open source</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "manager: built $APP ($(du -sh "$APP" | cut -f1))"
echo "manager: launch with  open \"$APP\""
