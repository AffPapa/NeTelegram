#!/bin/bash
set -euo pipefail

# Build, sign, notarize, and package a distribution candidate without ever
# replacing the canonical Dev.app. Secrets remain in Keychain; environment
# values below are selectors/public metadata, not private key material.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
usage() {
  cat <<'EOF'
Usage: build-release-candidate.sh [--preflight-only]

Required environment:
  NETELEGRAM_RELEASE_VERSION       SemVer (for example 0.1.0)
  NETELEGRAM_RELEASE_BUILD         positive integer
  NETELEGRAM_RELEASE_CHANNEL       alpha or stable
  NETELEGRAM_DEVELOPER_IDENTITY    exact Developer ID Application identity
  NETELEGRAM_DEVELOPER_TEAM_ID     expected Apple Team ID
  NETELEGRAM_NOTARY_PROFILE        notarytool Keychain profile name
  NETELEGRAM_SPARKLE_PUBLIC_ED_KEY public EdDSA key (base64; not secret)
  NETELEGRAM_RELEASE_OUTPUT        new absolute directory outside the checkout

Sparkle's private EdDSA key is read by its tool from the login Keychain. The
notary profile is read by notarytool from Keychain. Neither value is accepted
as a command-line secret, printed, or written into the candidate directory.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then usage; exit 0; fi
PREFLIGHT_ONLY=false
if [[ "${1:-}" == "--preflight-only" ]]; then PREFLIGHT_ONLY=true
elif [[ $# -gt 0 ]]; then usage >&2; exit 2
fi

fail() { echo "release-candidate: $*" >&2; exit 1; }
require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "required environment setting is missing: $name"
}
for name in NETELEGRAM_RELEASE_VERSION NETELEGRAM_RELEASE_BUILD NETELEGRAM_RELEASE_CHANNEL \
  NETELEGRAM_DEVELOPER_IDENTITY NETELEGRAM_DEVELOPER_TEAM_ID NETELEGRAM_NOTARY_PROFILE \
  NETELEGRAM_SPARKLE_PUBLIC_ED_KEY NETELEGRAM_RELEASE_OUTPUT; do require_env "$name"; done

[[ "$NETELEGRAM_RELEASE_VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail "version must be released SemVer without a prerelease suffix"
[[ "$NETELEGRAM_RELEASE_BUILD" =~ ^[1-9][0-9]*$ ]] || fail "build must be a positive integer"
[[ "$NETELEGRAM_RELEASE_CHANNEL" == "alpha" ]] || fail "this candidate builder currently permits alpha only; stable remains gated by compatibility and 20-account evidence"
[[ "$(uname -s)" == "Darwin" ]] || fail "release distribution requires macOS"
[[ "$(uname -m)" == "arm64" ]] || fail "the first release target is Apple Silicon arm64"
[[ "$NETELEGRAM_DEVELOPER_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "Team ID must be ten uppercase letters/digits"

PUBLIC_KEY_BYTES="$(printf '%s' "$NETELEGRAM_SPARKLE_PUBLIC_ED_KEY" | /usr/bin/base64 -D 2>/dev/null | /usr/bin/wc -c | tr -d ' ')"
[[ "$PUBLIC_KEY_BYTES" == "32" ]] || fail "Sparkle public key must decode to exactly 32 bytes"

ROOT_REAL="$(cd "$ROOT_DIR" && pwd -P)"
OUTPUT_REAL="$(python3 - "$NETELEGRAM_RELEASE_OUTPUT" <<'PY'
import os, pathlib, sys
p = pathlib.Path(sys.argv[1])
if not p.is_absolute():
    raise SystemExit("NETELEGRAM_RELEASE_OUTPUT must be absolute")
print(os.path.realpath(p))
PY
)" || fail "cannot resolve release output path"
case "$OUTPUT_REAL/" in "$ROOT_REAL/"*) fail "release output must be outside the Git checkout" ;; esac
[[ ! -e "$OUTPUT_REAL" ]] || fail "release output already exists; refusing to overwrite candidate bytes"
[[ -d "$(dirname "$OUTPUT_REAL")" && -w "$(dirname "$OUTPUT_REAL")" ]] || fail "release output parent must already exist and be writable"

HEAD="$(git -C "$ROOT_DIR" rev-parse HEAD)"
[[ "$HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "cannot resolve a full source commit"
[[ "$(git -C "$ROOT_DIR" branch --show-current)" == "main" ]] || fail "release source must be on main"
[[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] || fail "release source checkout must be clean"
ORIGIN="$(git -C "$ROOT_DIR" remote get-url origin | tr '[:upper:]' '[:lower:]')"
case "$ORIGIN" in
  https://github.com/affpapa/netelegram|https://github.com/affpapa/netelegram.git|git@github.com:affpapa/netelegram|git@github.com:affpapa/netelegram.git|ssh://git@github.com/affpapa/netelegram|ssh://git@github.com/affpapa/netelegram.git) ;;
  *) fail "unexpected source remote" ;;
esac
REMOTE_HEAD="$(git -C "$ROOT_DIR" ls-remote origin refs/heads/main | awk 'NR==1 {print $1}')" || fail "cannot verify the published main commit"
[[ "$REMOTE_HEAD" == "$HEAD" ]] || fail "release source must equal the published origin/main commit"

IDENTITIES="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null)" || fail "cannot inspect code-signing identities"
printf '%s\n' "$IDENTITIES" | grep -F "$NETELEGRAM_DEVELOPER_IDENTITY" | grep -F "($NETELEGRAM_DEVELOPER_TEAM_ID)" >/dev/null \
  || fail "the selected Developer ID identity with the expected Team ID is unavailable"

command -v xcrun >/dev/null || fail "xcrun is unavailable"
command -v swift >/dev/null || fail "Swift is unavailable"
command -v ditto >/dev/null || fail "ditto is unavailable"
SPARKLE_SIGN_UPDATE="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
[[ -x "$SPARKLE_SIGN_UPDATE" ]] || fail "pinned Sparkle sign_update is unavailable; resolve the exact SwiftPM artifact first"
TDJSON="$ROOT_DIR/.build/tdlib-build/libtdjson.dylib"
[[ -f "$TDJSON" ]] || fail "pinned TDLib library is missing; build it with Scripts/build-tdlib.sh first"

# Read-only validation of the stored profile. It performs no submission and
# keeps the credential entirely inside notarytool's Keychain integration.
xcrun notarytool history --keychain-profile "$NETELEGRAM_NOTARY_PROFILE" --output-format json >/dev/null \
  || fail "notarytool could not use the configured Keychain profile"

if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  echo "Release preflight passed for source $HEAD, version $NETELEGRAM_RELEASE_VERSION build $NETELEGRAM_RELEASE_BUILD ($NETELEGRAM_RELEASE_CHANNEL)."
  echo "Preflight did not verify the Sparkle private key, build, sign, notarize, or create files."
  exit 0
fi

SCRATCH="$ROOT_DIR/.build/release-candidates/$NETELEGRAM_RELEASE_VERSION-$NETELEGRAM_RELEASE_BUILD-$HEAD"
mkdir -p "$(dirname "$SCRATCH")"
mkdir -p "$OUTPUT_REAL"
mkdir "$SCRATCH" || fail "candidate scratch already exists; refusing to overwrite"
BUILD_ROOT="$SCRATCH/swift"
CLANG_CACHE="${NETELEGRAM_SWIFT_MODULE_CACHE:-/private/tmp/netelegram-release-swift-modules}"
mkdir -p "$CLANG_CACHE"
SWIFT_BIN="$(CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT" --configuration release --disable-sandbox --show-bin-path)"
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" swift build --package-path "$ROOT_DIR" --scratch-path "$BUILD_ROOT" --configuration release --disable-sandbox
EXECUTABLE="$SWIFT_BIN/NeTelegram"
SPARKLE_FRAMEWORK="$SWIFT_BIN/Sparkle.framework"
[[ -x "$EXECUTABLE" && -d "$SPARKLE_FRAMEWORK" ]] || fail "release executable or pinned Sparkle framework is missing"

APP="$SCRATCH/NeTelegram.app"
CONTENTS="$APP/Contents"
FRAMEWORKS="$CONTENTS/Frameworks"
mkdir -p "$CONTENTS/MacOS" "$FRAMEWORKS" "$CONTENTS/Resources"
cp "$EXECUTABLE" "$CONTENTS/MacOS/NeTelegram"
cp "$TDJSON" "$FRAMEWORKS/libtdjson.dylib"
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS/Sparkle.framework"
chmod 755 "$CONTENTS/MacOS/NeTelegram"
chmod 644 "$FRAMEWORKS/libtdjson.dylib"

FEED="https://netelegram.iryadom.chatgpt.site/updates/$NETELEGRAM_RELEASE_CHANNEL.xml"
python3 - "$ROOT_DIR" "$CONTENTS/Info.plist" "$CONTENTS/Resources/BuildInfo.json" "$APP" "$HEAD" "$NETELEGRAM_RELEASE_VERSION" "$NETELEGRAM_RELEASE_BUILD" "$NETELEGRAM_RELEASE_CHANNEL" "$FEED" "$NETELEGRAM_SPARKLE_PUBLIC_ED_KEY" <<'PY'
import hashlib, json, pathlib, plistlib, subprocess, sys
root, plist_path, build_info_path, app, commit, version, build, channel, feed, public_key = sys.argv[1:]
root = pathlib.Path(root)
files = [root / "Package.swift", root / "Package.resolved", root / "TDLIB.lock.json"]
files += sorted((root / "Sources").rglob("*"))
h = hashlib.sha256()
for p in (p for p in files if p.is_file()):
    h.update(p.relative_to(root).as_posix().encode()); h.update(b"\0"); h.update(p.read_bytes())
tdlib = json.loads((root / "TDLIB.lock.json").read_text())["ref"]
with open(plist_path, "wb") as f:
    plistlib.dump({
        "CFBundleDevelopmentRegion":"ru", "CFBundleExecutable":"NeTelegram",
        "CFBundleIdentifier":"org.affpapa.netelegram", "CFBundleInfoDictionaryVersion":"6.0",
        "CFBundleName":"NeTide", "CFBundleDisplayName":"NeTide", "CFBundlePackageType":"APPL",
        "CFBundleShortVersionString":version, "CFBundleVersion":build,
        "LSMinimumSystemVersion":"14.0", "NSHighResolutionCapable":True,
        "NeTelegramDevelopmentCommit":commit, "NeTelegramDevelopmentDirty":False,
        "NeTelegramReleaseChannel":channel, "SUFeedURL":feed, "SUPublicEDKey":public_key,
        "SUVerifyUpdateBeforeExtraction":True, "SUEnableAutomaticChecks":False,
        "SUAutomaticallyUpdate":False,
    }, f, sort_keys=True)
swift = subprocess.check_output(["swift", "--version"], text=True).splitlines()
swift = next((line for line in swift if line.startswith("Apple Swift version")), swift[0] if swift else "unknown")
record = {
    "bundle_id":"org.affpapa.netelegram", "bundle_path":app,
    "app_source_commit":commit, "working_tree_dirty":False,
    "source_fingerprint_sha256":h.hexdigest(), "swift_version":swift,
    "tdlib_commit":tdlib, "architecture":"arm64", "minimum_macos":"14.0",
    "release_version":version, "release_build":int(build), "release_channel":channel,
}
pathlib.Path(build_info_path).write_text(json.dumps(record, indent=2)+"\n")
PY

# Re-sign Sparkle inside-out. Downloader keeps only its upstream entitlements;
# this app is not sandboxed, so no sandbox entitlement is introduced.
SPARKLE_VERSION="$FRAMEWORKS/Sparkle.framework/Versions/B"
sign_runtime() { /usr/bin/codesign --force --options runtime --timestamp --sign "$NETELEGRAM_DEVELOPER_IDENTITY" "$1"; }
[[ -e "$SPARKLE_VERSION/XPCServices/Installer.xpc" ]] && sign_runtime "$SPARKLE_VERSION/XPCServices/Installer.xpc"
if [[ -e "$SPARKLE_VERSION/XPCServices/Downloader.xpc" ]]; then
  /usr/bin/codesign --force --options runtime --timestamp --preserve-metadata=entitlements --sign "$NETELEGRAM_DEVELOPER_IDENTITY" "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
fi
[[ -e "$SPARKLE_VERSION/Autoupdate" ]] && sign_runtime "$SPARKLE_VERSION/Autoupdate"
[[ -e "$SPARKLE_VERSION/Updater.app" ]] && sign_runtime "$SPARKLE_VERSION/Updater.app"
sign_runtime "$FRAMEWORKS/Sparkle.framework"
sign_runtime "$FRAMEWORKS/libtdjson.dylib"
sign_runtime "$APP"
/usr/bin/codesign --verify --strict "$FRAMEWORKS/libtdjson.dylib"
/usr/bin/codesign --verify --strict "$FRAMEWORKS/Sparkle.framework"
/usr/bin/codesign --verify --strict "$APP"

INITIAL_ZIP="$SCRATCH/notary-submit.zip"
ditto -c -k --norsrc --keepParent "$APP" "$INITIAL_ZIP"
submit_notarization() {
  local artifact="$1" label="$2" response submission status
  response="$(xcrun notarytool submit "$artifact" --keychain-profile "$NETELEGRAM_NOTARY_PROFILE" --wait --output-format json)"
  printf '%s\n' "$response" > "$OUTPUT_REAL/$label-submit.json"
  status="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' <<<"$response")"
  submission="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' <<<"$response")"
  [[ "$status" == "Accepted" && -n "$submission" ]] || fail "$label notarization was not Accepted"
  xcrun notarytool log "$submission" --keychain-profile "$NETELEGRAM_NOTARY_PROFILE" --output-format json > "$OUTPUT_REAL/$label-log.json"
}
submit_notarization "$INITIAL_ZIP" app
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
/usr/sbin/spctl --assess --type execute --verbose=2 "$APP"

VERSIONED="NeTide-$NETELEGRAM_RELEASE_VERSION-arm64"
APP_ZIP="$OUTPUT_REAL/$VERSIONED.zip"
ditto -c -k --norsrc --keepParent "$APP" "$APP_ZIP"
DMG_ROOT="$SCRATCH/dmg-root"
mkdir "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/NeTelegram.app"
ln -s /Applications "$DMG_ROOT/Applications"
DMG="$OUTPUT_REAL/$VERSIONED.dmg"
hdiutil create -volname "NeTide $NETELEGRAM_RELEASE_VERSION" -srcfolder "$DMG_ROOT" -format UDZO "$DMG" >/dev/null
submit_notarization "$DMG" dmg
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
hdiutil verify "$DMG" >/dev/null

UPDATE_ZIP="$OUTPUT_REAL/$VERSIONED-update.zip"
cp "$APP_ZIP" "$UPDATE_ZIP"
SIGNATURE_OUTPUT="$("$SPARKLE_SIGN_UPDATE" "$UPDATE_ZIP")"
printf '%s\n' "$SIGNATURE_OUTPUT" > "$OUTPUT_REAL/sparkle-signature.xml"
SIGNATURE="$(python3 -c 'import re,sys; m=re.search(r"sparkle:edSignature=\"([^\"]+)\"",sys.stdin.read()); print(m.group(1) if m else "")' <<<"$SIGNATURE_OUTPUT")"
[[ -n "$SIGNATURE" ]] || fail "Sparkle did not return an EdDSA update signature"
"$SPARKLE_SIGN_UPDATE" --verify "$UPDATE_ZIP" "$SIGNATURE" >/dev/null

python3 "$ROOT_DIR/Scripts/generate_sbom.py" --version "$NETELEGRAM_RELEASE_VERSION" \
  --source-commit "$HEAD" --app-zip "$APP_ZIP" --expected-team-id "$NETELEGRAM_DEVELOPER_TEAM_ID" \
  --output "$OUTPUT_REAL/$VERSIONED-sbom.json"
python3 "$ROOT_DIR/Scripts/generate_release_notices.py" --output "$OUTPUT_REAL/NOTICE.txt"
python3 - "$OUTPUT_REAL" "$VERSIONED" "$NETELEGRAM_RELEASE_VERSION" "$NETELEGRAM_RELEASE_BUILD" "$NETELEGRAM_RELEASE_CHANNEL" "$HEAD" "$SIGNATURE" <<'PY'
import hashlib, json, pathlib, sys
out=pathlib.Path(sys.argv[1]); stem,version,build,channel,commit,signature=sys.argv[2:]
assets=[]
for kind,name in (("app_zip",f"{stem}.zip"),("dmg",f"{stem}.dmg"),("sparkle_update_zip",f"{stem}-update.zip"),("sbom",f"{stem}-sbom.json"),("notice","NOTICE.txt")):
 p=out/name; h=hashlib.sha256(p.read_bytes()).hexdigest()
 assets.append({"kind":kind,"filename":name,"bytes":p.stat().st_size,"sha256":h})
(out/"candidate-assets.json").write_text(json.dumps({"source_commit":commit,"version":version,"build":int(build),"channel":channel,"minimum_macos":"14.0","sparkle_ed_signature":signature,"assets":assets},indent=2)+"\n")
with (out/"SHA256SUMS").open("w") as f:
 for item in assets: f.write(f"{item['sha256']}  {item['filename']}\n")
PY

echo "Candidate files created under $OUTPUT_REAL"
echo "This script does not publish GitHub assets, update the Site, or claim quarantine/install acceptance."
