#!/usr/bin/env bash
set -euo pipefail

LABEL="${CLAUDE_RTL_LAUNCHD_LABEL:-com.claude-desktop-official-rtl.watchdog}"
DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN" "$DEST" >/dev/null 2>&1 || true
rm -f "$DEST"

printf 'Removed %s\n' "$DEST"
