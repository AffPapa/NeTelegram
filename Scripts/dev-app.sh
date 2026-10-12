#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/.build/canonical-dev-build"
APP_PATH="/private/tmp/NeTelegram-Dev.app"
PGREP_BIN="${NETELEGRAM_PGREP_BIN:-/usr/bin/pgrep}"
SUPPORT_ROOT="${NETELEGRAM_SUPPORT_ROOT:-/private/tmp/netelegram-dev-support}"
BUILD_RECORD="$BUILD_ROOT/NeTelegram-Dev.build.json"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/NeTelegram"
FRAMEWORKS="$APP_PATH/Contents/Frameworks"
MODE="build"

if [[ "${1:-}" == "--launch" ]]; then
    MODE="launch"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--launch]" >&2
    exit 2
fi

TDJSON="$ROOT_DIR/.build/tdlib-build/libtdjson.dylib"
if "$PGREP_BIN" -x NeTelegram >/dev/null 2>&1; then
    echo "NeTelegram is already running. Quit the canonical development app before rebuilding it." >&2
    exit 1
else
    pgrep_status=$?
    if [[ $pgrep_status -ne 1 ]]; then
        echo "Unable to confirm whether NeTelegram is running (pgrep exit $pgrep_status); refusing to replace the canonical app." >&2
        exit 1
    fi
fi

SWIFT_BIN_PATH="$(swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT/swift" --show-bin-path)"
swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT/swift"
BUILT_EXECUTABLE="$SWIFT_BIN_PATH/NeTelegram"
if [[ ! -x "$BUILT_EXECUTABLE" ]]; then
    # SwiftPM has changed the executable output layout across toolchain
    # releases. Prefer `--show-bin-path`, then search this exact scratch path.
    BUILT_EXECUTABLE="$(python3 - "$BUILD_ROOT/swift" <<'PY'
import os, pathlib, sys
root = pathlib.Path(sys.argv[1])
candidates = [p for p in root.rglob("NeTelegram") if p.is_file() and os.access(p, os.X_OK)]
if candidates:
    print(max(candidates, key=lambda p: p.stat().st_mtime_ns))
PY
)"
fi
if [[ ! -f "$TDJSON" ]]; then
    echo "Pinned TDLib is missing: $TDJSON (run Scripts/build-tdlib.sh first)" >&2
    exit 1
fi
if [[ -z "$BUILT_EXECUTABLE" || ! -x "$BUILT_EXECUTABLE" ]]; then
    echo "NeTelegram executable is missing after build" >&2
    exit 1
fi

# The development bundle uses an app-owned support root and never discovers or
# opens another Telegram app. Override NETELEGRAM_SUPPORT_ROOT for isolated QA.
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$FRAMEWORKS" "$APP_PATH/Contents/Resources" "$SUPPORT_ROOT"
cp "$BUILT_EXECUTABLE" "$APP_EXECUTABLE"
cp "$TDJSON" "$FRAMEWORKS/libtdjson.dylib"
chmod 755 "$APP_EXECUTABLE"
chmod 644 "$FRAMEWORKS/libtdjson.dylib"

cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>ru</string>
<key>CFBundleExecutable</key><string>NeTelegram</string>
<key>CFBundleIdentifier</key><string>org.affpapa.netelegram.dev</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>NeTelegram Dev</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.0.0-dev</string>
<key>CFBundleVersion</key><string>0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

python3 - "$ROOT_DIR" "$APP_PATH/Contents/Resources/BuildInfo.json" "$SUPPORT_ROOT" "$APP_PATH" <<'PY'
import hashlib, json, pathlib, subprocess, sys
root, output, support, app = map(pathlib.Path, sys.argv[1:])
files = [root / "Package.swift", root / "TDLIB.lock.json"]
files += sorted((root / "Sources").rglob("*"))
files = [p for p in files if p.is_file()]
h = hashlib.sha256()
for p in files:
    h.update(p.relative_to(root).as_posix().encode())
    h.update(b"\0")
    h.update(p.read_bytes())
def command(*args):
    try: return subprocess.check_output(args, text=True).strip()
    except Exception: return "unavailable"
info = {
    "bundle_id": "org.affpapa.netelegram.dev",
    "bundle_path": str(app),
    "support_root": str(support),
    "git_head": command("git", "-C", str(root), "rev-parse", "HEAD"),
    "source_fingerprint_sha256": h.hexdigest(),
    "swift_version": command("swift", "--version").splitlines()[0],
    "tdlib_commit": json.loads((root / "TDLIB.lock.json").read_text()).get("ref"),
    "architecture": "arm64",
    "minimum_macos": "14.0",
    "signing": "ad-hoc development only",
}
pathlib.Path(output).write_text(json.dumps(info, indent=2) + "\n")
PY

# Sign nested code before the containing app. This is local smoke signing only.
/usr/bin/codesign --force --sign - "$FRAMEWORKS/libtdjson.dylib"
/usr/bin/codesign --force --sign - "$APP_PATH"
/usr/bin/codesign --verify --deep --strict "$APP_PATH"
python3 - "$APP_PATH" "$APP_PATH/Contents/Resources/BuildInfo.json" "$BUILD_RECORD" <<'PY'
import hashlib, json, pathlib, sys
app, embedded, build_record = map(pathlib.Path, sys.argv[1:])
record = json.loads(embedded.read_text())
record["app_executable_sha256"] = hashlib.sha256((app / "Contents/MacOS/NeTelegram").read_bytes()).hexdigest()
record["tdjson_sha256"] = hashlib.sha256((app / "Contents/Frameworks/libtdjson.dylib").read_bytes()).hexdigest()
record["signature"] = "ad-hoc; codesign --verify --deep --strict passed"
build_record.parent.mkdir(parents=True, exist_ok=True)
build_record.write_text(json.dumps(record, indent=2) + "\n")
PY

echo "Canonical bundle: $APP_PATH"
echo "Bundle ID: org.affpapa.netelegram.dev"
echo "Support root: $SUPPORT_ROOT"
echo "Build record: $APP_PATH/Contents/Resources/BuildInfo.json"
echo "Signed bytes record: $BUILD_RECORD"
if [[ "$MODE" == "launch" ]]; then
    open "$APP_PATH" --args --app-support-root "$SUPPORT_ROOT"
fi
