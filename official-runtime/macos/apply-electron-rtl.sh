#!/usr/bin/env bash
# apply-electron-rtl.sh — generic Electron RTL via Chromium remote debugging (CDP).
#
# Relaunches a target Electron app with --remote-debugging-port, then injects dist/payload.js into
# every page/webview through the DevTools protocol. Nothing on disk is touched: no copy, no asar
# edit, no re-sign, no source change. The RTL is applied purely at runtime, so it works for anyone
# running the control panel — not because of any local build.
#
# Security note: unlike Claude's transient main-process debugger, the Chromium debugging port stays
# open for the app's session. We bind 127.0.0.1 only and use a RANDOM high port (not a fixed one) to
# reduce trivial discovery. Prefer Claude's bespoke route where available.
#
# Usage: apply-electron-rtl.sh <app-path> [port|auto] [adapter-id]
#   env: RTL_PAYLOAD (default <repo>/dist/payload.js), RTL_NODE (a Node 22+ binary)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP="${1:?usage: apply-electron-rtl.sh <app-path> [port|auto] [adapter-id]}"
PORT="${2:-auto}"
ADAPTER_ID="${3:-}"
PAYLOAD="${RTL_PAYLOAD:-$REPO_ROOT/dist/payload.js}"
INJECTOR="$SCRIPT_DIR/inject-electron-cdp.js"
STATE_DIR="$HOME/Library/Application Support/claude-rtl-manager"

log() { printf '[apply-electron-rtl] %s\n' "$*" >&2; }

[[ -d "$APP" ]] || { log "app not found: $APP"; exit 1; }
[[ -f "$PAYLOAD" ]] || { log "payload not found: $PAYLOAD (run 'npm run build')"; exit 1; }
[[ "$PORT" == "auto" ]] && PORT=$(( (RANDOM % 400) + 9500 ))

# Node 22+ is required for the global WebSocket used by the CDP client.
find_node() {
  local c
  if [[ -n "${RTL_NODE:-}" && -x "$RTL_NODE" ]]; then NODE="$RTL_NODE"; return 0; fi
  for c in "$HOME/.nvm/versions/node/v22.22.2/bin/node" /opt/homebrew/bin/node /usr/local/bin/node \
           "$HOME"/.nvm/versions/node/v2[2-9]*/bin/node; do
    if [[ -x "$c" ]] && "$c" -e 'process.exit(typeof WebSocket==="function"?0:1)' 2>/dev/null; then
      NODE="$c"; return 0
    fi
  done
  log "no Node 22+ with global WebSocket found; set RTL_NODE"; return 1
}
find_node

EXEC_NAME="$(defaults read "$APP/Contents/Info" CFBundleExecutable 2>/dev/null || basename "$APP" .app)"
BIN="$APP/Contents/MacOS/$EXEC_NAME"
[[ -x "$BIN" ]] || { log "executable not found: $BIN"; exit 1; }

# 1) Quit the app (matched by its exact bundle path, so we never touch a different app).
log "quitting ${EXEC_NAME}..."
pkill -f "$APP/Contents/MacOS/" 2>/dev/null || true
for _ in $(seq 1 60); do pgrep -f "$APP/Contents/MacOS/" >/dev/null 2>&1 || break; sleep 0.5; done

# 2) Relaunch with the Chromium remote-debugging endpoint (direct exec passes switches reliably).
log "relaunching with --remote-debugging-port=${PORT} (127.0.0.1)..."
nohup "$BIN" --remote-debugging-port="$PORT" --remote-allow-origins='*' >/dev/null 2>&1 &
disown 2>/dev/null || true

# 3) Wait for the debug endpoint to answer.
ready=""
for _ in $(seq 1 80); do
  if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1; then ready=1; break; fi
  sleep 0.5
done
if [[ -z "$ready" ]]; then
  log "debug endpoint never opened on 127.0.0.1:$PORT — this app strips the switch (hardened/guarded build)."
  echo "applied=fail"
  exit 4
fi

# 4) Inject the payload into every page/webview target.
log "injecting payload via CDP..."
if RTL_CDP_PORT="$PORT" RTL_PAYLOAD="$PAYLOAD" "$NODE" "$INJECTOR"; then
  NEW_PID="$(pgrep -f "$APP/Contents/MacOS/$EXEC_NAME" | head -n 1)"
  if [[ -n "$ADAPTER_ID" ]]; then
    mkdir -p "$STATE_DIR"
    {
      printf 'pid=%s\n' "$NEW_PID"
      printf 'port=%s\n' "$PORT"
      printf 'app=%s\n' "$APP"
      printf 'applied_at=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
      printf 'applied_epoch=%s\n' "$(date +%s)"
    } > "$STATE_DIR/$ADAPTER_ID.state"
  fi
  echo "applied=ok"
  echo "port=$PORT"
  echo "pid=$NEW_PID"
else
  echo "applied=fail"
  exit 5
fi
