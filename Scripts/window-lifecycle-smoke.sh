#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 APP_PATH SUPPORT_ROOT LIFECYCLE_JSON SCREENSHOT_PATH" >&2
  exit 2
fi

APP_PATH="$1"
SUPPORT_ROOT="$2"
LIFECYCLE_JSON="$3"
SCREENSHOT_PATH="$4"
APP_ID="org.affpapa.netelegram.dev"
PGREP_BIN="/usr/bin/pgrep"

quit_app() {
  if "$PGREP_BIN" -x NeTelegram >/dev/null 2>&1; then
    /usr/bin/osascript -e "tell application id \"$APP_ID\" to quit" >/dev/null 2>&1 || true
  fi
}
trap quit_app EXIT

rm -f "$LIFECYCLE_JSON" "$SCREENSHOT_PATH"
open -n "$APP_PATH" --args \
  --app-support-root "$SUPPORT_ROOT" \
  --ci-lifecycle-smoke-file "$LIFECYCLE_JSON"

for attempt in {1..30}; do
  if "$PGREP_BIN" -x NeTelegram >/dev/null; then break; fi
  sleep 1
done
"$PGREP_BIN" -x NeTelegram >/dev/null
APP_PID="$("$PGREP_BIN" -x NeTelegram)"
if [[ "$APP_PID" == *$'\n'* ]]; then
  echo "Expected exactly one NeTelegram process after clean launch." >&2
  exit 1
fi

for attempt in {1..15}; do
  if [[ -s "$SCREENSHOT_PATH" ]]; then break; fi
  /usr/sbin/screencapture -x "$SCREENSHOT_PATH" || true
  sleep 0.2
done
test -s "$SCREENSHOT_PATH"

wait_for_phase() {
  local expected_phase="$1"
  local expected_count="$2"
  for attempt in {1..30}; do
    if /usr/bin/python3 - "$LIFECYCLE_JSON" "$expected_phase" "$APP_PID" "$expected_count" <<'PY'
import json, pathlib, sys
path, phase, pid, count = sys.argv[1:]
try:
    events = json.loads(pathlib.Path(path).read_text())
except (OSError, ValueError):
    raise SystemExit(1)
for event in events:
    if event.get('phase') == phase:
        raise SystemExit(0 if str(event.get('pid')) == pid and event.get('visibleWindowCount') == int(count) else 2)
raise SystemExit(1)
PY
    then
      return 0
    else
      result=$?
    fi
    if [[ $result -eq 2 ]]; then
      echo "Unexpected process or visible-window count for lifecycle phase: $expected_phase" >&2
      return 1
    fi
    sleep 1
  done
  echo "Timed out waiting for lifecycle phase: $expected_phase" >&2
  return 1
}

wait_for_phase launched 1
wait_for_phase closed 0
if [[ "$("$PGREP_BIN" -x NeTelegram)" != "$APP_PID" ]]; then
  echo "The app process did not survive closing its last window." >&2
  exit 1
fi

# LaunchServices activation is the same path used when a closed-window app is
# reopened from the Dock. The smoke hook records the AppKit reopen callback.
open -a "$APP_PATH"
wait_for_phase reopened 1
if [[ "$("$PGREP_BIN" -x NeTelegram)" != "$APP_PID" ]]; then
  echo "Reopening created a different process instead of restoring the app." >&2
  exit 1
fi

/usr/bin/osascript -e "tell application id \"$APP_ID\" to quit"
for attempt in {1..20}; do
  if ! "$PGREP_BIN" -x NeTelegram >/dev/null; then break; fi
  sleep 1
done
if "$PGREP_BIN" -x NeTelegram >/dev/null; then
  echo "NeTelegram did not quit after its normal quit command." >&2
  exit 1
fi
trap - EXIT
echo "Dev.app last-window close, LaunchServices reopen, same-PID, one-window, and quit smoke passed."
