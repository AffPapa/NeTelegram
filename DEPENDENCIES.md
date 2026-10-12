# Dependency inventory

This inventory describes the current Apple Silicon development build. It is
not a complete SBOM for a future release artifact.

| Component | Pin / provider | License | Runtime status |
|---|---|---|---|
| TDLib | `tdlib/td` commit `c15d3f5a5de6e3ba5839822c451152e5e18bb700`, 1.8.68 | BSL-1.0 | Built as `libtdjson.dylib`; app bundle integration pending |
| OpenSSL | `openssl/openssl` commit `d3c1b1169b3569ff3069e5b399f47b2b28e03d79`, 3.6.4 | Apache-2.0 | Built static for macOS 14 and linked into TDLib |
| SQLCipher contributions | TDLib-pinned SQLite amalgamation | BSD terms | Included inside TDLib; license text retained in `ThirdPartyLicenses/SQLCipher-BSD.txt` |
| SQLite core | TDLib-pinned amalgamation | Public domain | Included inside TDLib |
| zlib | macOS SDK 27.0 | zlib | System dynamic library, not bundled |
| gperf | 3.3 | GPL-3.0-or-later tool | Build-time code generation only; not shipped or linked. GNU documents generated output as not automatically GPL; generated TDLib code follows its input's license. |

TDLib schema and JSON header hashes are in `TDLIB.lock.json`. The build script
checks these files, the TDLib license, the OpenSSL commit and license hash, and
then compiles with `MACOSX_DEPLOYMENT_TARGET=14.0`. Final notarized asset
contents still require a generated SBOM and binary-level notice review.
