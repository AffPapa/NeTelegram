#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PIN_FILE="$ROOT_DIR/TDLIB.lock.json"
SOURCE_DIR="$ROOT_DIR/.build/tdlib-src"
BUILD_DIR="$ROOT_DIR/.build/tdlib-build"
OPENSSL_SOURCE="$ROOT_DIR/.build/openssl-src"
OPENSSL_PREFIX="$ROOT_DIR/.build/openssl-install"
TDLIB_COMMIT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["ref"])' "$PIN_FILE")"
OPENSSL_COMMIT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["build_dependencies"]["openssl"]["ref"])' "$PIN_FILE")"

mkdir -p "$OPENSSL_SOURCE"
if [ ! -d "$OPENSSL_SOURCE/.git" ]; then
  git -C "$OPENSSL_SOURCE" init
  git -C "$OPENSSL_SOURCE" remote add origin https://github.com/openssl/openssl.git
fi
git -C "$OPENSSL_SOURCE" fetch --depth=1 origin "$OPENSSL_COMMIT"
git -C "$OPENSSL_SOURCE" checkout --force --detach FETCH_HEAD
test "$(git -C "$OPENSSL_SOURCE" rev-parse HEAD)" = "$OPENSSL_COMMIT"
python3 - "$PIN_FILE" "$OPENSSL_SOURCE" <<'PY'
import hashlib, json, pathlib, sys
pin = json.loads(pathlib.Path(sys.argv[1]).read_text())["build_dependencies"]["openssl"]
actual = hashlib.sha256((pathlib.Path(sys.argv[2]) / pin["license_path"]).read_bytes()).hexdigest()
if actual != pin["license_sha256"]:
    raise SystemExit("Pinned OpenSSL license hash mismatch")
print("OpenSSL source revision and Apache-2.0 license hash verified")
PY
if [ ! -f "$OPENSSL_PREFIX/lib/libssl.a" ] || [ ! -f "$OPENSSL_PREFIX/lib/libcrypto.a" ]; then
  (
    cd "$OPENSSL_SOURCE"
    MACOSX_DEPLOYMENT_TARGET=14.0 ./Configure darwin64-arm64-cc \
      --prefix="$OPENSSL_PREFIX" --openssldir="$OPENSSL_PREFIX/ssl" no-shared no-tests
    MACOSX_DEPLOYMENT_TARGET=14.0 make -j2
    make install_sw
  )
fi

mkdir -p "$SOURCE_DIR"
if [ ! -d "$SOURCE_DIR/.git" ]; then
  git -C "$SOURCE_DIR" init
  git -C "$SOURCE_DIR" remote add origin https://github.com/tdlib/td.git
fi
git -C "$SOURCE_DIR" fetch --depth=1 origin "$TDLIB_COMMIT"
git -C "$SOURCE_DIR" checkout --force --detach FETCH_HEAD
test "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$TDLIB_COMMIT"

python3 - "$PIN_FILE" "$SOURCE_DIR" <<'PY'
import hashlib, json, pathlib, sys
pin = json.loads(pathlib.Path(sys.argv[1]).read_text())
root = pathlib.Path(sys.argv[2])
for key in ("schema", "json_header", "license"):
    item = pin[key]
    actual = hashlib.sha256((root / item["path"]).read_bytes()).hexdigest()
    if actual != item["sha256"]:
        raise SystemExit(f"Pinned TDLib {key} hash mismatch")
print("TDLib commit, schema, JSON header, and license hashes verified")
PY

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DOPENSSL_ROOT_DIR="$OPENSSL_PREFIX" \
  -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DOPENSSL_SSL_LIBRARY="$OPENSSL_PREFIX/lib/libssl.a" \
  -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_PREFIX/lib/libcrypto.a" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
cmake --build "$BUILD_DIR" --target tdjson --parallel 2
clang -I"$ROOT_DIR/Sources/TDLibCBridge/include" \
  "$ROOT_DIR/Scripts/tdlib-smoke.c" "$ROOT_DIR/Sources/TDLibCBridge/TDLibCBridge.c" \
  -o "$ROOT_DIR/.build/tdlib-smoke"
"$ROOT_DIR/.build/tdlib-smoke" "$BUILD_DIR/libtdjson.dylib"
