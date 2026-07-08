#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="${CLAUDE_RTL_LAUNCHD_LABEL:-com.claude-desktop-official-rtl.watchdog}"
DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"
ENSURER="$SCRIPT_DIR/ensure-claude-official-rtl.sh"
NODE_PATH_PARTS="$HOME/.nvm/versions/node/v22.22.2/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

[[ -x "$ENSURER" ]] || chmod +x "$ENSURER"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/Claude"

cat > "$DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$ENSURER</string>
  </array>

  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>$HOME</string>
    <key>PATH</key>
    <string>$NODE_PATH_PARTS</string>
  </dict>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>60</integer>

  <key>LimitLoadToSessionType</key>
  <array>
    <string>Aqua</string>
  </array>

  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/Claude/official-rtl-watchdog.launchd.out.log</string>

  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/Claude/official-rtl-watchdog.launchd.err.log</string>
</dict>
</plist>
PLIST

plutil -lint "$DEST" >/dev/null

launchctl bootout "$DOMAIN" "$DEST" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$DEST"
launchctl enable "$DOMAIN/$LABEL"
launchctl kickstart -k "$DOMAIN/$LABEL"

cat <<TEXT
Installed $DEST

If automatic repair cannot click Claude's Developer menu, grant Accessibility once:
  System Settings -> Privacy & Security -> Accessibility -> enable bash
TEXT
