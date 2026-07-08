#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP="${CLAUDE_RTL_APP:-/Applications/Claude.app}"
APP_BIN="$APP/Contents/MacOS/Claude"
TEAM_ID="${CLAUDE_RTL_TEAM_ID:-Q6L2SF6YDW}"
INJECTOR="${CLAUDE_RTL_INJECTOR:-$SCRIPT_DIR/inject-rtl.js}"
USER_DATA="$HOME/Library/Application Support/Claude"
DEV_SETTINGS="$USER_DATA/developer_settings.json"
STATE_DIR="$USER_DATA/official-rtl"
STATE_FILE="$STATE_DIR/watchdog.state"
LOCK_DIR="$STATE_DIR/watchdog.lock"
LOG="$HOME/Library/Logs/Claude/official-rtl-watchdog.log"
NODE_BIN="${CLAUDE_RTL_NODE:-}"
PERIODIC_SECONDS="${CLAUDE_RTL_PERIODIC_SECONDS:-86400}"
MODE="${1:-ensure}"

mkdir -p "$USER_DATA" "$STATE_DIR" "$(dirname "$LOG")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$LOG"
}

state_value() {
  [[ -f "$STATE_FILE" ]] || return 0
  awk -F= -v key="$1" '$1 == key { print substr($0, index($0, "=") + 1) }' "$STATE_FILE" | tail -n 1
}

find_node() {
  if [[ -n "$NODE_BIN" && -x "$NODE_BIN" ]]; then
    return 0
  fi

  for candidate in \
    "$HOME/.nvm/versions/node/v22.22.2/bin/node" \
    "/opt/homebrew/bin/node" \
    "/usr/local/bin/node" \
    "/usr/bin/node"; do
    if [[ -x "$candidate" ]]; then
      NODE_BIN="$candidate"
      return 0
    fi
  done

  log "ERROR: Node.js not found. Set CLAUDE_RTL_NODE to a node binary."
  return 1
}

claude_pid() {
  pgrep -x Claude 2>/dev/null | head -n 1 || true
}

process_command() {
  ps -p "$1" -o command= 2>/dev/null || true
}

process_start() {
  ps -p "$1" -o lstart= 2>/dev/null | sed 's/^ *//; s/  */ /g' || true
}

claude_version() {
  defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || printf 'unknown'
}

process_key() {
  local pid="$1"
  local start version
  start="$(process_start "$pid")"
  version="$(claude_version)"
  printf '%s|%s|%s' "$pid" "$start" "$version" | shasum -a 256 | awk '{ print $1 }'
}

write_dev_settings() {
  printf '{\n  "allowDevTools": true\n}\n' > "$DEV_SETTINGS"
}

write_state() {
  local pid="$1"
  local command="$2"
  local key version force_flag now
  key="$(process_key "$pid")"
  version="$(claude_version)"
  now="$(date +%s)"
  force_flag="false"
  if [[ "$command" == *"--force-ui-direction=rtl"* ]]; then
    force_flag="true"
  fi

  {
    printf 'process_key=%s\n' "$key"
    printf 'pid=%s\n' "$pid"
    printf 'version=%s\n' "$version"
    printf 'force_ui_direction=%s\n' "$force_flag"
    printf 'last_success_epoch=%s\n' "$now"
    printf 'last_success_at=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
    printf 'repo_root=%s\n' "$REPO_ROOT"
  } > "$STATE_FILE"
}

with_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
    return 0
  fi

  local lock_mtime lock_age
  lock_mtime="$(stat -f '%m' "$LOCK_DIR" 2>/dev/null || printf '0')"
  lock_age=$(( $(date +%s) - lock_mtime ))
  if (( lock_age > 180 )); then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
      return 0
    fi
  fi

  return 1
}

verify_official_signature() {
  local actual_team_id
  actual_team_id="$(codesign -dv --verbose=4 "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -n 1)"
  if [[ "$actual_team_id" != "$TEAM_ID" ]]; then
    log "ERROR: refusing to inject: Claude Team ID is '$actual_team_id', expected '$TEAM_ID'"
    return 1
  fi
}

inspector_is_open() {
  curl -fsS --max-time 1 http://127.0.0.1:9229/json/list >/dev/null 2>&1
}

capture_frontmost_app() {
  osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true
}

restore_frontmost_app() {
  local app_name="$1"
  [[ -n "$app_name" && "$app_name" != "Claude" ]] || return 0
  osascript - "$app_name" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set appName to item 1 of argv
  tell application "System Events"
    if exists application process appName then
      set frontmost of first application process whose name is appName to true
    end if
  end tell
end run
APPLESCRIPT
}

open_main_process_debugger() {
  osascript <<'APPLESCRIPT' >/dev/null
tell application "Claude" to activate
delay 0.4
tell application "System Events"
  tell process "Claude"
    click menu item "Enable Main Process Debugger" of menu "Developer" of menu bar item "Developer" of menu bar 1
  end tell
end tell
APPLESCRIPT
}

wait_for_inspector() {
  local _
  for _ in {1..40}; do
    if inspector_is_open; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

close_chrome_inspect_tabs() {
  local _
  for _ in {1..20}; do
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
    sleep 0.25
  done
}

current_official_claude() {
  local pid command
  pid="$(claude_pid)"
  [[ -n "$pid" ]] || return 1
  command="$(process_command "$pid")"
  [[ "$command" == "$APP_BIN"* ]] || return 1
  printf '%s\n%s\n' "$pid" "$command"
}

record_only() {
  local details pid command
  details="$(current_official_claude)" || exit 0
  pid="$(printf '%s\n' "$details" | sed -n '1p')"
  command="$(printf '%s\n' "$details" | sed -n '2p')"
  write_state "$pid" "$command"
}

ensure_rtl() {
  local details pid command key last_key last_success now age frontmost
  details="$(current_official_claude)" || exit 0
  pid="$(printf '%s\n' "$details" | sed -n '1p')"
  command="$(printf '%s\n' "$details" | sed -n '2p')"
  key="$(process_key "$pid")"
  last_key="$(state_value process_key)"
  last_success="$(state_value last_success_epoch)"
  now="$(date +%s)"

  if [[ "$MODE" != "--force" && "$key" == "$last_key" && "$last_success" =~ ^[0-9]+$ ]]; then
    age=$(( now - last_success ))
    if (( age < PERIODIC_SECONDS )); then
      exit 0
    fi
  fi

  [[ -d "$APP" && -x "$APP_BIN" ]] || { log "ERROR: Claude.app not found at $APP"; return 1; }
  [[ -f "$INJECTOR" ]] || { log "ERROR: injector not found at $INJECTOR"; return 1; }
  [[ -f "$REPO_ROOT/dist/payload.js" ]] || { log "ERROR: payload not found. Run 'npm run build' in $REPO_ROOT"; return 1; }
  find_node
  verify_official_signature
  write_dev_settings

  frontmost="$(capture_frontmost_app)"
  log "Ensuring RTL for official Claude pid=$pid version=$(claude_version)"

  if ! inspector_is_open; then
    if ! open_main_process_debugger 2>> "$LOG"; then
      log "ERROR: could not open Claude main-process debugger. Grant Accessibility to the runner."
      restore_frontmost_app "$frontmost"
      return 1
    fi
  fi

  if ! wait_for_inspector; then
    log "ERROR: Claude main-process debugger did not open"
    restore_frontmost_app "$frontmost"
    return 1
  fi

  if "$NODE_BIN" "$INJECTOR" >> "$LOG" 2>&1; then
    write_state "$pid" "$command"
    log "RTL runtime confirmed for official Claude pid=$pid"
    close_chrome_inspect_tabs
    restore_frontmost_app "$frontmost"
    return 0
  fi

  log "ERROR: RTL injector failed for official Claude pid=$pid"
  close_chrome_inspect_tabs
  restore_frontmost_app "$frontmost"
  return 1
}

with_lock || exit 0

case "$MODE" in
  ensure | --force)
    ensure_rtl
    ;;
  --record-success)
    record_only
    ;;
  *)
    log "ERROR: unknown mode '$MODE'"
    exit 2
    ;;
esac
