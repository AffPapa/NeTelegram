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

if "$PGREP_BIN" -x "$PROCESS_NAME" >/dev/null 2>&1; then
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
    running) exit 0 ;;
    absent) exit 2 ;;
    *) exit 2 ;;
esac
