#!/usr/bin/env bash
# adapter-control.sh — the single command surface the menu-bar manager wraps.
#
# Design: the SwiftUI app reads the static adapter metadata from manager/adapters/*.json
# directly, and asks THIS script only for live, machine-readable state as `key=value` lines
# (trivial to emit in bash, trivial to parse in Swift — no JSON-in-bash pain).
#
# Read-only by default. The only mutating verbs are `reapply` and `watch on|off`, and both
# only touch the Claude adapter, whose runtime path never modifies /Applications/Claude.app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADAPTER_DIR="$ROOT/manager/adapters"
OFFICIAL="$ROOT/official-runtime/macos"

APP="${CLAUDE_RTL_APP:-/Applications/Claude.app}"
STATE_FILE="$HOME/Library/Application Support/Claude/official-rtl/watchdog.state"
LOG_FILE="$HOME/Library/Logs/Claude/official-rtl-watchdog.log"
WATCH_LABEL="${CLAUDE_RTL_LAUNCHD_LABEL:-com.claude-desktop-official-rtl.watchdog}"
WATCH_PLIST="$HOME/Library/LaunchAgents/$WATCH_LABEL.plist"
MGR_STATE="$HOME/Library/Application Support/claude-rtl-manager"

adapter_file()   { printf '%s/%s.json' "$ADAPTER_DIR" "$1"; }
apply_route()    { jv "$(adapter_file "$1")" apply; }
jv()             { /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null || true; }
plist_value()    { /usr/bin/defaults read "$1/Contents/Info" "$2" 2>/dev/null || true; }
team_id()        { /usr/bin/codesign -dv --verbose=4 "$1" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}'; }

# --- state key, computed exactly like ensure-claude-official-rtl.sh (pid|lstart|version) ------
process_start()  { /bin/ps -p "$1" -o lstart= 2>/dev/null | /usr/bin/sed 's/^ *//; s/  */ /g' || true; }
claude_version() { /usr/bin/defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || printf 'unknown'; }
process_key()    { printf '%s|%s|%s' "$1" "$(process_start "$1")" "$(claude_version)" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'; }
claude_pid()     { /usr/bin/pgrep -x Claude 2>/dev/null | /usr/bin/head -n 1 || true; }
state_value()    { [[ -f "$STATE_FILE" ]] || return 0; /usr/bin/awk -F= -v k="$1" '$1==k{print substr($0,index($0,"=")+1)}' "$STATE_FILE" | /usr/bin/tail -n 1; }

require_adapter() {
  local f; f="$(adapter_file "$1")"
  [[ -f "$f" ]] || { printf 'error=unknown-adapter\n'; exit 3; }
}

# --- verbs ------------------------------------------------------------------------------------
cmd_status() {
  local id="$1"; require_adapter "$id"
  local f app_path bundle_id expected_team version actual_team
  f="$(adapter_file "$id")"
  app_path="$(jv "$f" defaultPath)"
  bundle_id="$(jv "$f" bundleId)"
  expected_team="$(jv "$f" teamId)"

  if [[ ! -d "$app_path" ]]; then
    printf 'installed=no\n'
    return 0
  fi
  version="$(plist_value "$app_path" CFBundleShortVersionString)"
  actual_team="$(team_id "$app_path")"

  printf 'installed=yes\n'
  printf 'path=%s\n' "$app_path"
  printf 'bundleId=%s\n' "$(plist_value "$app_path" CFBundleIdentifier)"
  printf 'version=%s\n' "${version:-unknown}"
  printf 'teamId=%s\n' "${actual_team:-none}"
  if [[ -n "$expected_team" ]]; then
    printf 'teamOk=%s\n' "$([[ "$actual_team" == "$expected_team" ]] && echo yes || echo no)"
  fi
  local exec_name; exec_name="$(plist_value "$app_path" CFBundleExecutable)"
  if [[ -n "$exec_name" ]] && /usr/bin/pgrep -f "$app_path/Contents/MacOS/$exec_name" >/dev/null 2>&1; then
    printf 'running=yes\n'
  else
    printf 'running=no\n'
  fi
}

# verify: is the RTL payload live in the currently running Claude? Honest states only.
#   active     — Claude is running and it is the exact process instance we injected into
#   stale      — Claude is running but restarted/updated since; a reapply is needed
#   inactive   — Claude is running, never injected in this session
#   notRunning — Claude is not running
#   unsupported — non-Claude adapter (Hermes/Codex have no runtime injection route)
# Dispatch verify by the adapter's apply route: Claude uses its process-key state; generic
# Electron adapters use the manager state file written by apply-electron-rtl.sh.
cmd_verify() {
  local id="$1"; require_adapter "$id"
  case "$(apply_route "$id")" in
    official-debugger) verify_claude "$id" ;;
    electron-cdp|electron-cdp-experimental) verify_generic "$id" ;;
    *) printf 'rtl=unsupported\n' ;;
  esac
}

verify_generic() {
  local id="$1" st="$MGR_STATE/$id.state" app exec_name running_pid spid port
  app="$(jv "$(adapter_file "$id")" defaultPath)"
  exec_name="$(plist_value "$app" CFBundleExecutable)"
  running_pid="$(/usr/bin/pgrep -f "$app/Contents/MacOS/$exec_name" 2>/dev/null | /usr/bin/head -n 1)"
  if [[ -z "$running_pid" ]]; then printf 'rtl=notRunning\n'; return 0; fi
  if [[ -f "$st" ]]; then
    spid="$(/usr/bin/awk -F= '$1=="pid"{print $2}' "$st" | /usr/bin/tail -n 1)"
    port="$(/usr/bin/awk -F= '$1=="port"{print $2}' "$st" | /usr/bin/tail -n 1)"
    if [[ "$spid" == "$running_pid" ]] && curl -fsS --max-time 1 "http://127.0.0.1:$port/json/version" >/dev/null 2>&1; then
      printf 'rtl=active\n'
      printf 'lastSuccessAt=%s\n' "$(/usr/bin/awk -F= '$1=="applied_at"{print $2}' "$st" | /usr/bin/tail -n 1)"
    else
      printf 'rtl=stale\n'
    fi
  else
    printf 'rtl=inactive\n'
  fi
}

verify_claude() {
  local id="$1"
  local pid; pid="$(claude_pid)"
  if [[ -z "$pid" ]]; then
    printf 'rtl=notRunning\n'
    return 0
  fi
  local key last_key last_success
  key="$(process_key "$pid")"
  last_key="$(state_value process_key)"
  last_success="$(state_value last_success_epoch)"
  if [[ -n "$last_key" && "$key" == "$last_key" && "$last_success" =~ ^[0-9]+$ ]]; then
    printf 'rtl=active\n'
    printf 'lastSuccessAt=%s\n' "$(state_value last_success_at)"
  elif [[ -n "$last_key" ]]; then
    printf 'rtl=stale\n'
    printf 'lastSuccessAt=%s\n' "$(state_value last_success_at)"
  else
    printf 'rtl=inactive\n'
  fi
  printf 'claudeVersion=%s\n' "$(claude_version)"
}

cmd_watch_status() {
  local id="$1"; require_adapter "$id"
  if [[ "$id" != "claude-official-macos" ]]; then
    printf 'watch=unsupported\n'
    return 0
  fi
  if [[ -f "$WATCH_PLIST" ]] && /bin/launchctl print "gui/$(/usr/bin/id -u)/$WATCH_LABEL" >/dev/null 2>&1; then
    printf 'watch=on\n'
  elif [[ -f "$WATCH_PLIST" ]]; then
    printf 'watch=installed\n'
  else
    printf 'watch=off\n'
  fi
}

cmd_logs_path() {
  local id="$1"; require_adapter "$id"
  printf 'logs=%s\n' "$LOG_FILE"
}

# --- mutating verbs (Claude adapter only) -----------------------------------------------------
# Dispatch apply by route: Claude through its own main-process debugger; every other Electron
# adapter through the generic CDP relauncher. Both preserve the app on disk (no copy/patch/re-sign).
cmd_reapply() {
  local id="$1"; require_adapter "$id"
  local app; app="$(jv "$(adapter_file "$id")" defaultPath)"
  case "$(apply_route "$id")" in
    official-debugger)
      if CLAUDE_RTL_PAYLOAD="${CLAUDE_RTL_PAYLOAD:-$ROOT/dist/payload.js}" \
         CLAUDE_RTL_INJECTOR="${CLAUDE_RTL_INJECTOR:-$OFFICIAL/inject-rtl.js}" \
         /bin/bash "$OFFICIAL/ensure-claude-official-rtl.sh" --force; then
        printf 'reapply=ok\n'
      else
        printf 'reapply=fail\n'; exit 1
      fi
      ;;
    electron-cdp|electron-cdp-experimental)
      if RTL_PAYLOAD="${RTL_PAYLOAD:-$ROOT/dist/payload.js}" \
         /bin/bash "$OFFICIAL/apply-electron-rtl.sh" "$app" auto "$id"; then
        printf 'reapply=ok\n'
      else
        printf 'reapply=fail\n'; exit 1
      fi
      ;;
    *)
      printf 'error=no-apply-route\n'; exit 4 ;;
  esac
}

cmd_watch() {
  local id="$1" mode="${2:-}"; require_adapter "$id"
  if [[ "$id" != "claude-official-macos" ]]; then
    printf 'error=unsupported-adapter\n'
    exit 4
  fi
  case "$mode" in
    on)  /bin/bash "$OFFICIAL/install-watchdog.sh"   >/dev/null && printf 'watch=on\n' ;;
    off) /bin/bash "$OFFICIAL/uninstall-watchdog.sh" >/dev/null && printf 'watch=off\n' ;;
    *)   printf 'error=usage: watch <id> on|off\n'; exit 2 ;;
  esac
}

usage() {
  cat <<'TXT'
usage: adapter-control.sh <verb> <adapter-id> [args]
  status <id>            live install/version/team/running state
  verify <id>            is the RTL payload live right now (Claude only)
  watch-status <id>      watchdog LaunchAgent state (Claude only)
  logs-path <id>         path to the runtime log
  reapply <id>           force-reapply RTL now (Claude only; mutating)
  watch <id> on|off      install/remove the auto-reapply watchdog (Claude only; mutating)
TXT
}

verb="${1:-}"; shift || true
case "$verb" in
  status)       cmd_status "${1:?adapter id}" ;;
  verify)       cmd_verify "${1:?adapter id}" ;;
  watch-status) cmd_watch_status "${1:?adapter id}" ;;
  logs-path)    cmd_logs_path "${1:?adapter id}" ;;
  reapply)      cmd_reapply "${1:?adapter id}" ;;
  watch)        cmd_watch "${1:?adapter id}" "${2:-}" ;;
  ""|-h|--help) usage ;;
  *)            printf 'error=unknown-verb: %s\n' "$verb"; usage; exit 2 ;;
esac
