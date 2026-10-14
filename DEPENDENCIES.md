# Dependency inventory

This inventory describes the current Apple Silicon development build. Generate
the machine-readable CycloneDX source dependency inventory from the committed
pins with:

```sh
python3 Scripts/generate_sbom.py \
  --version 0.0.0-dev \
  --source-commit "$(git rev-parse HEAD)" \
  --output /tmp/netelegram-sbom.json
```

The generated inventory is explicitly marked as pin-derived and incomplete
until reconciled with the final signed application bundle. Release candidates
must pass the binary audit and bind its executable and `libtdjson.dylib`
SHA-256 values to the final app ZIP:

```sh
python3 Scripts/generate_sbom.py \
  --version 1.2.3 \
  --source-commit "$(git rev-parse HEAD)" \
  --app-bundle /absolute/path/NeTelegram.app \
  --output /absolute/path/release-assets/NeTelegram.cdx.json
```

`--app-bundle` requires matching version/source metadata, an arm64 executable
and TDLib library, Developer ID signature verification, a stapled notarization
ticket, and an accepted Gatekeeper assessment. The release validator then
rechecks the two binary hashes against the final ZIP and requires a separate
third-party notice asset. It does not replace the post-download install/reopen
smoke or final manual NOTICE review.
`Package.swift` currently declares no third-party Swift package dependencies.

Generate the release `THIRD-PARTY-NOTICES.txt` from the project NOTICE and the
license texts pinned by the dependency locks:

```sh
python3 Scripts/generate_release_notices.py \
  --output /absolute/path/release-assets/THIRD-PARTY-NOTICES.txt
```

The command verifies the TDLib, OpenSSL, and libphonenumber license hashes
before writing. The metadata CI runs this generator on every relevant change.

| Component | Pin / provider | License | Runtime status |
|---|---|---|---|
| TDLib | `tdlib/td` commit `c15d3f5a5de6e3ba5839822c451152e5e18bb700`, 1.8.68 | BSL-1.0 | Bundled as `Contents/Frameworks/libtdjson.dylib` in the Dev.app; tested dynamic dependencies are zlib, libc++, and macOS system libraries |
| OpenSSL | `openssl/openssl` commit `d3c1b1169b3569ff3069e5b399f47b2b28e03d79`, 3.6.4 | Apache-2.0 | Built static for macOS 14 and linked into TDLib; its code is included in the TDLib binary |
| Country calling-code list | `google/libphonenumber` v9.0.41 commit `b68df884d42d5e9860fc1956a99ce6afae361100`; source file hash in `COUNTRY-DATA.lock.json` | Apache-2.0 | Generated region/calling-code pairs for first-run sign-in only; localized names come from macOS Locale; TDLib server list replaces it after account runtime starts |
| SQLCipher contributions | TDLib-pinned SQLite amalgamation | BSD terms | Included inside TDLib; license text retained in `ThirdPartyLicenses/SQLCipher-BSD.txt` |
| SQLite core | TDLib-pinned amalgamation | Public domain | Included inside TDLib |
| zlib | macOS SDK | zlib | System dynamic library; `otool -L libtdjson.dylib` reports `/usr/lib/libz.1.dylib`, not a bundled copy |
| gperf | Selected Xcode toolchain, version 3.0.3 | GPL-3.0-or-later tool | Build-only generator required by pinned TDLib; version checked against `TDLIB.lock.json`, not shipped or linked. GNU documents that gperf does not make generated output GPL; generated code follows its input's terms. |
| Apple frameworks / Swift runtime | macOS 14+ platform | Apple platform terms | Dynamically provided system frameworks/runtime; not copied as third-party source dependencies |

TDLib schema and JSON header hashes are in `TDLIB.lock.json`. The build script
checks these files, the TDLib license, the OpenSSL commit and license hash, and
then compiles with `MACOSX_DEPLOYMENT_TARGET=14.0` and fails if the selected
Xcode gperf version does not match the lock. The Dev.app is ad-hoc signed for
development only. Final notarized asset contents still require a generated
SBOM and binary-level notice review.
