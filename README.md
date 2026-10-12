# NeTelegram

A native macOS Telegram client project in active development. Public source: [AffPapa/NeTelegram](https://github.com/AffPapa/NeTelegram).

## Current status

This checkout contains a Swift/AppKit development app, a pinned TDLib 1.8.68 C/JSON adapter, an account catalogue, and a shared receive/update pipeline. The native authorization source implements a desktop flow for country selection, phone number, Telegram code, optional 2FA password, email address/code, first-time registration with explicit Terms consent, and QR authentication. After authorization, the source loads the selected account's chat list and history, with account-scoped caches, a text composer, and guarded text-send dispatch. The UI lock is wired to macOS LocalAuthentication. Catalogue UUIDs stay internal and the account selector lists only verified server identities.

Current evidence is a successful arm64 development build plus 35 local Swift Testing cases. `Scripts/dev-app.sh` builds one canonical development bundle with a separate support directory; see [`DEV-WORKFLOW.md`](DEV-WORKFLOW.md). A no-account phone-entry screen was visually checked and Cmd+Q exited the process. A previous smoke created one local UUID-only catalog entry, which was removed; no phone, Telegram user ID, session, or installed Telegram app data was used. Current source uses local UUIDs only as storage namespaces, displays verified account names, and suppresses UUID-shaped labels. No account has completed login; real chat/read/send, photo download/send/album rendering, latest email/code/2FA/registration UI states, LocalAuthentication UI, multi-account concurrency, and app-level draft persistence remain unverified. Source includes separate per-account AES-GCM draft storage, explicit incoming-photo previews and on-demand largest-variant viewing with bounded ImageIO decoding, adjacent TDLib photo-album grouping, a privacy-bound single-photo send action with caption, and account-scoped native notification reconciliation. Synthetic tests cover encryption, photo variant selection/downsampling and private photo staging, album grouping, and notification routing. Accessibility labels cover the new-login controls and core chat actions; the fresh phone-entry keyboard path was smoke-checked, while full VoiceOver/chat navigation and real-account behavior remain unverified. Do not use this development build as a production messenger.

The product name remains a codename pending review of Telegram API Terms §2.3. The project also has open compatibility work for basic functionality and channel sponsored messages. See [`RELEASE.md`](RELEASE.md), [`CONTRIBUTING.md`](CONTRIBUTING.md), and [`SECURITY.md`](SECURITY.md). The current development site is [netelegram.iryadom.chatgpt.site](https://netelegram.iryadom.chatgpt.site).

## Build locally

Requires Xcode and Swift 6.4 or compatible. The deployment baseline is macOS 14; first release target is Apple Silicon. The local suite has 35 synthetic/core tests; these do not establish real-account or 20-account coverage.

```sh
swift test
Scripts/dev-app.sh
# Only when a native login/lifecycle/UI smoke is needed:
Scripts/dev-app.sh --launch
```

This is a development app, not a Developer ID signed or notarized release. Build TDLib first so the app can load the pinned local `libtdjson.dylib`. The script always rebuilds the same repository-local canonical bundle and uses a stable app-owned support root. For isolated smoke checks, set `NETELEGRAM_SUPPORT_ROOT` before `Scripts/dev-app.sh --launch`; do not use a real account unless you intend to create persistent development data.

The C/JSON dependency is pinned in `TDLIB.lock.json`. On Apple Silicon, install
CMake, gperf, OpenSSL 3, and Xcode command line tools, then run
`Scripts/build-tdlib.sh`. The script checks out the exact upstream commit and
verifies the TD API schema, JSON header, and Boost Software License hashes
before building. Transitive runtime integration and the complete dependency
license inventory remain under review. Multiple-profile restore is implemented
in source but has not yet passed native UI or real-account validation; no
20-account coverage or performance measurements are available. Background
runtimes do not load every chat history: only the selected account's chat list is
loaded, and message-history projections are bounded. Text sends are blocked
unless TDLib confirms text permission, a non-channel chat, and the current
account as default sender; paid-message Stars are explicitly zero. No real send
has been exercised. The public GPL macOS client source was used to study the
login flow; no GPL application code or visual assets were copied.

## Scope

The accepted product brief and architecture are in [`PRODUCT-ARCHITECTURE.txt`](PRODUCT-ARCHITECTURE.txt). Release and Sites workflows are in [`RELEASE.txt`](RELEASE.txt) and [`WEBSITE.txt`](WEBSITE.txt). All acceptance cases remain open unless separately recorded as verified.
