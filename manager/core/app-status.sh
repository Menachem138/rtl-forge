#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADAPTER_DIR="$ROOT/manager/adapters"

json_value() {
  local file="$1"
  local key="$2"
  /usr/bin/plutil -extract "$key" raw -o - "$file" 2>/dev/null || true
}

plist_value() {
  local app_path="$1"
  local key="$2"
  /usr/bin/defaults read "$app_path/Contents/Info" "$key" 2>/dev/null || true
}

team_id() {
  local app_path="$1"
  local output
  output="$(/usr/bin/codesign -dv --verbose=4 "$app_path" 2>&1 || true)"
  /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}' <<<"$output"
}

signature_line() {
  local app_path="$1"
  local output
  output="$(/usr/bin/codesign -dv --verbose=4 "$app_path" 2>&1 || true)"
  /usr/bin/awk -F= '/^Authority=/{print $2; exit}' <<<"$output"
}

run_with_timeout() {
  local seconds="$1"
  shift

  local tmp pid watchdog status
  tmp="$(/usr/bin/mktemp -t claude-rtl-app-status.XXXXXX)"
  "$@" >"$tmp" 2>&1 &
  pid=$!

  (
    sleep "$seconds"
    if /bin/kill -0 "$pid" >/dev/null 2>&1; then
      /bin/kill "$pid" >/dev/null 2>&1 || true
    fi
  ) &
  watchdog=$!

  wait "$pid" || status=$?
  /bin/kill "$watchdog" >/dev/null 2>&1 || true

  /bin/cat "$tmp"
  /bin/rm -f "$tmp"
  return "${status:-0}"
}

notarization_status() {
  local app_path="$1"
  local output status
  output="$(run_with_timeout 5 /usr/sbin/spctl -a -vv "$app_path")" || status=$?
  if [[ "${status:-0}" == "143" ]]; then
    echo "timeout"
    return
  fi
  if [[ -z "$output" ]]; then
    echo "unknown"
    return
  fi
  /usr/bin/sed -n '1,2p' <<<"$output" | /usr/bin/tr '\n' ' ' | /usr/bin/sed 's/[[:space:]]*$//'
}

running_status() {
  local app_path="$1"
  local exec_name
  exec_name="$(plist_value "$app_path" CFBundleExecutable)"
  if [[ -z "$exec_name" ]]; then
    echo "unknown"
  elif /usr/bin/pgrep -f "$app_path/Contents/MacOS/$exec_name" >/dev/null 2>&1; then
    echo "running"
  else
    echo "not running"
  fi
}

print_adapter() {
  local adapter="$1"
  local name bundle_id app_path status safe_route expected_team actual_bundle version actual_team authority notarized running

  name="$(json_value "$adapter" name)"
  bundle_id="$(json_value "$adapter" bundleId)"
  app_path="$(json_value "$adapter" defaultPath)"
  status="$(json_value "$adapter" status)"
  safe_route="$(json_value "$adapter" safeRoute)"
  expected_team="$(json_value "$adapter" teamId)"

  echo "== $name =="
  echo "adapter: $status ($safe_route)"
  echo "path: $app_path"

  if [[ ! -d "$app_path" ]]; then
    echo "installed: no"
    echo
    return
  fi

  actual_bundle="$(plist_value "$app_path" CFBundleIdentifier)"
  version="$(plist_value "$app_path" CFBundleShortVersionString)"
  actual_team="$(team_id "$app_path")"
  authority="$(signature_line "$app_path")"
  notarized="$(notarization_status "$app_path")"
  running="$(running_status "$app_path")"

  echo "installed: yes"
  echo "bundle id: ${actual_bundle:-unknown}"
  echo "version: ${version:-unknown}"
  echo "team id: ${actual_team:-none}"
  echo "signature: ${authority:-none}"
  echo "gatekeeper: ${notarized:-unknown}"
  echo "process: $running"

  if [[ "$actual_bundle" != "$bundle_id" ]]; then
    echo "warning: bundle id does not match adapter metadata"
  fi

  if [[ -n "$expected_team" && "$actual_team" != "$expected_team" ]]; then
    echo "warning: expected Team ID $expected_team"
  fi

  if [[ "$bundle_id" == "com.openai.codex" ]]; then
    echo "policy: read-only research; do not patch or re-sign"
  fi

  echo
}

for adapter in "$ADAPTER_DIR"/*.json; do
  print_adapter "$adapter"
done
