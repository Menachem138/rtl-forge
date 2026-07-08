#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP="${CLAUDE_RTL_APP:-/Applications/Claude.app}"
USER_DATA="$HOME/Library/Application Support/Claude"
DEV_SETTINGS="$USER_DATA/developer_settings.json"
INJECTOR="${CLAUDE_RTL_INJECTOR:-$SCRIPT_DIR/inject-rtl.js}"
ENSURER="${CLAUDE_RTL_ENSURER:-$SCRIPT_DIR/ensure-claude-official-rtl.sh}"
LOG="$HOME/Library/Logs/Claude/official-rtl-launcher.log"
TEAM_ID="${CLAUDE_RTL_TEAM_ID:-Q6L2SF6YDW}"
NODE_BIN="${CLAUDE_RTL_NODE:-}"

mkdir -p "$USER_DATA" "$(dirname "$LOG")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" | tee -a "$LOG"
}

fail() {
  log "ERROR: $*"
  exit 1
}

accessibility_help() {
  cat <<'TEXT'

Claude official RTL could not click Claude's Developer menu.

Fix once:
  System Settings -> Privacy & Security -> Accessibility
  Enable the app that runs this launcher:
    - Terminal, if run from a shell or .command file
    - your automation runner, if run from an agent/IDE
    - bash, if run by the LaunchAgent watchdog

Then run the launcher again.
TEXT
}

open_main_process_debugger() {
  osascript <<'APPLESCRIPT'
tell application "Claude" to activate
delay 0.4
tell application "System Events"
  tell process "Claude"
    click menu item "Enable Main Process Debugger" of menu "Developer" of menu bar item "Developer" of menu bar 1
  end tell
end tell
APPLESCRIPT
}

[[ -d "$APP" ]] || fail "Claude.app not found at $APP"
[[ -f "$INJECTOR" ]] || fail "Injector not found at $INJECTOR"
[[ -f "$REPO_ROOT/dist/payload.js" ]] || fail "Payload not found. Run 'npm run build' in $REPO_ROOT"

if [[ -z "$NODE_BIN" ]]; then
  for candidate in \
    "$HOME/.nvm/versions/node/v22.22.2/bin/node" \
    "/opt/homebrew/bin/node" \
    "/usr/local/bin/node" \
    "/usr/bin/node"; do
    if [[ -x "$candidate" ]]; then
      NODE_BIN="$candidate"
      break
    fi
  done
fi

[[ -n "$NODE_BIN" && -x "$NODE_BIN" ]] || fail "Node.js not found. Set CLAUDE_RTL_NODE to a node binary."

actual_team_id="$(codesign -dv --verbose=4 "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -n1)"
[[ "$actual_team_id" == "$TEAM_ID" ]] || fail "Refusing to launch: Claude Team ID is '$actual_team_id', expected '$TEAM_ID'"

cat > "$DEV_SETTINGS" <<'JSON'
{
  "allowDevTools": true
}
JSON

log "Launching official Claude with RTL runtime injection"
osascript -e 'tell application "Claude" to quit' >/dev/null 2>&1 || true
for _ in {1..30}; do
  if ! pgrep -x Claude >/dev/null; then break; fi
  sleep 0.3
done

open -a "$APP" --args --force-ui-direction=rtl

for _ in {1..60}; do
  if pgrep -x Claude >/dev/null; then break; fi
  sleep 0.25
done
pgrep -x Claude >/dev/null || fail "Claude did not start"

sleep 2

if ! curl -fsS --max-time 1 http://127.0.0.1:9229/json/list >/dev/null 2>&1; then
  log "Opening Claude main-process debugger through the official Developer menu"
  if ! open_main_process_debugger >/dev/null; then
    accessibility_help | tee -a "$LOG" >&2
    fail "Could not open Claude main-process debugger"
  fi
fi

for _ in {1..40}; do
  if curl -fsS --max-time 1 http://127.0.0.1:9229/json/list >/dev/null 2>&1; then break; fi
  sleep 0.25
done
if ! curl -fsS --max-time 1 http://127.0.0.1:9229/json/list >/dev/null 2>&1; then
  accessibility_help | tee -a "$LOG" >&2
  fail "Claude main-process debugger did not open"
fi

log "Injecting RTL runtime into official Claude webContents"
"$NODE_BIN" "$INJECTOR" | tee -a "$LOG"

osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
tell application "System Events" to set chromeRunning to exists process "Google Chrome"
if chromeRunning then
  tell application "Google Chrome"
    repeat with chromeWindow in windows
      repeat with chromeTab in tabs of chromeWindow
        try
          if (URL of chromeTab) starts with "chrome://inspect" then close chromeTab
        end try
      end repeat
    end repeat
  end tell
end if
APPLESCRIPT

log "Claude official RTL runtime is active"
if [[ -x "$ENSURER" ]]; then
  "$ENSURER" --record-success >/dev/null 2>&1 || true
fi
