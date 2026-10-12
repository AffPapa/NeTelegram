# NeTelegram

A native macOS messaging client built with Swift, AppKit, and pinned TDLib. This repository is public source for a project in active development; there is no stable app download.

## Status

The source includes a TDLib-backed authorization flow, account-scoped runtime and storage code, chat and message presentation, text and photo paths, drafts, notifications, and an AppKit development app. These are implementation notes, not a claim that every feature has passed real-account testing.

The current local and hosted verification record is in [`ACCEPTANCE.json`](ACCEPTANCE.json). It covers core contract/unit tests and a source build only. No Telegram account has completed login. Sending, photo delivery, accessibility across the full app, sleep/wake recovery, and twenty concurrently authorized accounts remain unverified. This is not a production messenger or signed release.

The project targets macOS 14+ and Apple Silicon. TDLib 1.8.68 and its source schema are pinned in `TDLIB.lock.json`. See `DEV-WORKFLOW.md` for the local build/test cadence, `RELEASE.txt` for release gates, `PRODUCT-ARCHITECTURE.txt` for intended behavior, and `website/README.md` for how the static Site copy is synchronized without changing this repository remote.

## Local development setup

Build the pinned TDLib first with `Scripts/build-tdlib.sh`. Store the API hash corresponding to the project's configured API ID in macOS Keychain using `swift Scripts/store-telegram-api-hash.swift`; the prompt hides input and the value is not written to source or logs. Then run `swift test` and `Scripts/dev-app.sh --launch`. Never copy a Telegram account session from another client.

No app downloads are available until a build has passed real-device, signing, notarization, installation, and release checks.

See also: [Russian overview](README.ru.md), [contributing](CONTRIBUTING.md), [security policy](SECURITY.md), [license](LICENSE), and [third-party notices](NOTICE). The current development site is https://netelegram.iryadom.chatgpt.site.
