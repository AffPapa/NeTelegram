#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/.build/canonical-dev-build"
SWIFT_MODULE_CACHE="${NETELEGRAM_SWIFT_MODULE_CACHE:-/private/tmp/netelegram-dev-swift-modules}"
APP_PATH="/private/tmp/NeTelegram-Dev.app"
SUPPORT_ROOT="${NETELEGRAM_SUPPORT_ROOT:-/private/tmp/netelegram-dev-support-clean}"
BUILD_RECORD="$BUILD_ROOT/NeTelegram-Dev.build.json"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/NeTelegram"
FRAMEWORKS="$APP_PATH/Contents/Frameworks"
DEV_COMMIT="$(git -C "$ROOT_DIR" log -1 --format=%H -- Package.swift Sources TDLIB.lock.json)"
ORIGIN_URL="$(git -C "$ROOT_DIR" remote get-url origin)"
ORIGIN_URL_LOWER="$(printf '%s' "$ORIGIN_URL" | tr '[:upper:]' '[:lower:]')"
case "$ORIGIN_URL_LOWER" in
    https://github.com/affpapa/netelegram|https://github.com/affpapa/netelegram.git|git@github.com:affpapa/netelegram|git@github.com:affpapa/netelegram.git|ssh://git@github.com/affpapa/netelegram|ssh://git@github.com/affpapa/netelegram.git) ;;
    *)
        echo "Refusing to replace the canonical Dev.app from unexpected origin: $ORIGIN_URL" >&2
        exit 1
        ;;
esac
if [[ "${GITHUB_ACTIONS:-false}" != "true" && "$ROOT_DIR" != "${NETELEGRAM_CANONICAL_CHECKOUT:-/private/tmp/netelegram-cli-work}" ]]; then
    echo "Refusing to replace the canonical Dev.app from non-canonical checkout: $ROOT_DIR" >&2
    echo "Set NETELEGRAM_CANONICAL_CHECKOUT only when intentionally relocating the canonical checkout." >&2
    exit 1
fi
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain -- Package.swift Sources TDLIB.lock.json)" ]]; then
    APP_SOURCE_DIRTY=true
else
    APP_SOURCE_DIRTY=false
fi
DEV_DIRTY="$APP_SOURCE_DIRTY"
MODE="build"
LAUNCH_ARGS=(--app-support-root "$SUPPORT_ROOT")

if [[ "${1:-}" == "--launch" ]]; then
    MODE="launch"
elif [[ "${1:-}" == "--launch-chat-shell-preview" ]]; then
    MODE="launch"
    LAUNCH_ARGS+=(--ci-chat-shell-preview)
elif [[ "${1:-}" == "--launch-chat-shell-preview-compact" ]]; then
    MODE="launch"
    LAUNCH_ARGS+=(--ci-chat-shell-preview --ci-chat-shell-preview-compact)
elif [[ "${1:-}" == "--launch-auth-layout-preview" ]]; then
    MODE="launch"
    LAUNCH_ARGS+=(--ci-auth-layout-preview)
elif [[ "${1:-}" == "--launch-auth-layout-preview-compact" ]]; then
    MODE="launch"
    LAUNCH_ARGS+=(--ci-auth-layout-preview --ci-auth-layout-preview-compact)
elif [[ "${1:-}" == "--launch-auth-layout-preview-dark" ]]; then
    MODE="launch"
    LAUNCH_ARGS+=(--ci-auth-layout-preview --ci-appearance-dark)
elif [[ "${1:-}" == "--launch-auth-layout-preview-compact-dark" ]]; then
    MODE="launch"
    LAUNCH_ARGS+=(--ci-auth-layout-preview --ci-auth-layout-preview-compact --ci-appearance-dark)
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--launch|--launch-chat-shell-preview[-compact]|--launch-auth-layout-preview[-compact][-dark]]" >&2
    exit 2
fi

TDJSON="$ROOT_DIR/.build/tdlib-build/libtdjson.dylib"
# Reuse only a byte-for-byte verified bundle for this exact clean source
# commit, source fingerprint, toolchain, pinned TDLib, support root and build.
# This check is deliberately before the process guard: an already-running
# matching app can be focused with --launch, while any mismatch still refuses
# replacement until the existing process exits.
if [[ "$APP_SOURCE_DIRTY" == "false" && -f "$APP_PATH/Contents/Resources/BuildInfo.json" && -f "$BUILD_RECORD" ]]; then
    if python3 - "$ROOT_DIR" "$APP_PATH" "$BUILD_RECORD" "$SUPPORT_ROOT" "$DEV_COMMIT" <<'PY'
import hashlib, json, pathlib, plistlib, subprocess, sys
root, app, build_record = map(pathlib.Path, sys.argv[1:4])
support, expected_head = sys.argv[4:6]
try:
    files = [root / "Package.swift", root / "TDLIB.lock.json"]
    files += sorted((root / "Sources").rglob("*"))
    h = hashlib.sha256()
    for path in (path for path in files if path.is_file()):
        h.update(path.relative_to(root).as_posix().encode())
        h.update(b"\0")
        h.update(path.read_bytes())
    source_fingerprint = h.hexdigest()
    swift_lines = subprocess.check_output(["swift", "--version"], text=True).splitlines()
    swift_version = next((line for line in swift_lines if line.startswith("Apple Swift version")), swift_lines[0])
    tdlib_commit = json.loads((root / "TDLIB.lock.json").read_text())["ref"]
    build = json.loads(build_record.read_text())
    embedded = json.loads((app / "Contents/Resources/BuildInfo.json").read_text())
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    executable_hash = hashlib.sha256((app / "Contents/MacOS/NeTelegram").read_bytes()).hexdigest()
    tdjson_hash = hashlib.sha256((app / "Contents/Frameworks/libtdjson.dylib").read_bytes()).hexdigest()
    expected = {
        "bundle_id": "org.affpapa.netelegram.dev",
        "bundle_path": str(app),
        "support_root": support,
        "working_tree_dirty": False,
        "source_fingerprint_sha256": source_fingerprint,
        "swift_version": swift_version,
        "tdlib_commit": tdlib_commit,
        "architecture": "arm64",
        "minimum_macos": "14.0",
    }
    build_source_commit = build.get("app_source_commit", build.get("git_head"))
    embedded_source_commit = embedded.get("app_source_commit", embedded.get("git_head"))
    metadata_matches = (build_source_commit == expected_head and embedded_source_commit == expected_head
                        and all(build.get(k) == v and embedded.get(k) == v for k, v in expected.items()))
    bytes_match = (build.get("app_executable_sha256") == executable_hash
                   and build.get("tdjson_sha256") == tdjson_hash
                   and build.get("signature") == "ad-hoc; codesign --verify --deep --strict passed")
    plist_matches = (info.get("CFBundleIdentifier") == expected["bundle_id"]
                     and info.get("CFBundleExecutable") == "NeTelegram"
                     and info.get("CFBundleShortVersionString") == "0.0.0-dev"
                     and info.get("CFBundleVersion") == "0"
                     and info.get("LSMinimumSystemVersion") == "14.0"
                     and info.get("NeTelegramDevelopmentCommit") == expected_head
                     and info.get("NeTelegramDevelopmentDirty") is False)
    signature_ok = subprocess.run(
        ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    ).returncode == 0
    if metadata_matches and bytes_match and plist_matches and signature_ok:
        print("verified")
        sys.exit(0)
except Exception:
    pass
sys.exit(1)
PY
    then
        echo "Reusing verified canonical bundle for exact clean source $DEV_COMMIT."
        echo "Build record: $BUILD_RECORD"
        if [[ "$MODE" == "launch" ]]; then
            open "$APP_PATH" --args "${LAUNCH_ARGS[@]}"
        fi
        exit 0
    fi
fi
if process_check_output="$("$ROOT_DIR/Scripts/check-app-process.sh" NeTelegram org.affpapa.netelegram.dev)"; then
    echo "$process_check_output" >&2
    echo "NeTelegram is already running. Quit the canonical development app before rebuilding it." >&2
    exit 1
else
    process_check_status=$?
    if [[ $process_check_status -ne 1 ]]; then
        echo "Unable to confirm whether NeTelegram is running (process check exit $process_check_status); refusing to replace the canonical app." >&2
        exit 1
    fi
fi

mkdir -p "$SWIFT_MODULE_CACHE"
SWIFT_BIN_PATH="$(CLANG_MODULE_CACHE_PATH="$SWIFT_MODULE_CACHE" swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT/swift" --disable-sandbox --show-bin-path)"
CLANG_MODULE_CACHE_PATH="$SWIFT_MODULE_CACHE" swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT/swift" --disable-sandbox
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

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>ru</string>
<key>CFBundleExecutable</key><string>NeTelegram</string>
<key>CFBundleIdentifier</key><string>org.affpapa.netelegram.dev</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>AffPapa Chat Dev</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.0.0-dev</string>
<key>CFBundleVersion</key><string>0</string>
<key>NeTelegramDevelopmentCommit</key><string>$DEV_COMMIT</string>
<key>NeTelegramDevelopmentDirty</key><$([ "$DEV_DIRTY" == "true" ] && echo true || echo false)/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

/usr/libexec/PlistBuddy -c 'Print :NeTelegramDevelopmentCommit' "$APP_PATH/Contents/Info.plist" | grep -Fx "$DEV_COMMIT"
/usr/libexec/PlistBuddy -c 'Print :NeTelegramDevelopmentDirty' "$APP_PATH/Contents/Info.plist" | grep -Fx "$DEV_DIRTY"

python3 - "$ROOT_DIR" "$APP_PATH/Contents/Resources/BuildInfo.json" "$SUPPORT_ROOT" "$APP_PATH" "$DEV_DIRTY" <<'PY'
import hashlib, json, pathlib, subprocess, sys
root, output, support, app = map(pathlib.Path, sys.argv[1:5])
working_tree_dirty = sys.argv[5] == "true"
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
swift_lines = command("swift", "--version").splitlines()
swift_version = next((line for line in swift_lines if line.startswith("Apple Swift version")), swift_lines[0] if swift_lines else "unavailable")
info = {
    "bundle_id": "org.affpapa.netelegram.dev",
    "bundle_path": str(app),
    "support_root": str(support),
    "app_source_commit": command("git", "-C", str(root), "log", "-1", "--format=%H", "--", "Package.swift", "Sources", "TDLIB.lock.json"),
    "working_tree_dirty": working_tree_dirty,
    "source_fingerprint_sha256": h.hexdigest(),
    "swift_version": swift_version,
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
    open "$APP_PATH" --args "${LAUNCH_ARGS[@]}"
fi
