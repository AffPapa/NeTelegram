#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
    echo "Usage: $0 <process-name> <bundle-id>" >&2
    exit 2
fi

PROCESS_NAME="$1"
BUNDLE_ID="$2"
PGREP_BIN="${NETELEGRAM_PGREP_BIN:-/usr/bin/pgrep}"
SWIFT_BIN="${NETELEGRAM_PROCESS_SWIFT_BIN:-/usr/bin/swift}"
MODULE_CACHE="${NETELEGRAM_PROCESS_SWIFT_CACHE:-/private/tmp/netelegram-process-check-swift-modules}"

if running_pids="$("$PGREP_BIN" -x "$PROCESS_NAME" 2>/dev/null)"; then
    running_pids="${running_pids//$'\n'/,}"
    printf 'running process %s (pid %s)\n' "$PROCESS_NAME" "$running_pids"
    exit 0
else
    pgrep_status=$?
fi

# pgrep exit 1 is a definitive no-match. Other failures (macOS process-list
# privacy, sysmond unavailable, etc.) need an independent LaunchServices check.
# LaunchServices can positively detect a running bundle, but an empty result in
# a restricted process namespace is not proof that it is safe to replace it.
if [[ $pgrep_status -eq 1 ]]; then
    exit 1
fi

swift_result="$(NETELEGRAM_PROCESS_BUNDLE_ID="$BUNDLE_ID" \
    "$SWIFT_BIN" -module-cache-path "$MODULE_CACHE" -e '
import AppKit
let bundleID = ProcessInfo.processInfo.environment["NETELEGRAM_PROCESS_BUNDLE_ID"]!
let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .contains { !$0.isTerminated }
print(running ? "running" : "absent")
' 2>/dev/null)" || exit 2

case "$swift_result" in
    running)
        printf 'running app %s (%s) detected by LaunchServices\n' "$PROCESS_NAME" "$BUNDLE_ID"
        exit 0
        ;;
    absent)
        printf 'unable to prove process absence for %s (%s)\n' "$PROCESS_NAME" "$BUNDLE_ID" >&2
        exit 2
        ;;
    *) exit 2 ;;
esac
