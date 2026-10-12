# NeTelegram

A native macOS messaging client built with Swift, AppKit, and pinned TDLib. This repository is public source for a project in active development; there is no stable app download.

## Status

The source includes a TDLib-backed authorization flow, account-scoped runtime and storage code, chat and message presentation, text and photo paths, drafts, notifications, and an AppKit development app. These are implementation notes, not a claim that every feature has passed real-account testing.

Verified locally: Apple Silicon development build, first-run phone and QR screen without entering account data, and 35 synthetic/core tests on Swift 6.4 and Xcode 27.0. No Telegram account has completed login. Sending, photo delivery, accessibility across the full app, sleep/wake recovery, and twenty concurrently authorized accounts remain unverified. This is not a production messenger or signed release.

The project targets macOS 14+ and Apple Silicon. TDLib 1.8.68 and its source schema are pinned in `TDLIB.lock.json`. See `DEV-WORKFLOW.md` for the local build/test cadence, `RELEASE.md` for release gates, `PRODUCT-ARCHITECTURE.txt` for intended behavior, and `website/README.md` for how the static Site copy is synchronized without changing this repository remote.

No app downloads are available until a build has passed real-device, signing, notarization, installation, and release checks.

See also: [Russian overview](README.ru.md), [contributing](CONTRIBUTING.md), [security policy](SECURITY.md), [license](LICENSE), and [third-party notices](NOTICE). The current development site is https://netelegram.iryadom.chatgpt.site.
