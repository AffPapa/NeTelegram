# Release status and gates

NeTelegram is in development. No stable application release is available. A public source checkout or development Site does not mean an app binary is tested or ready to distribute.

A downloadable macOS release requires a reproducible Apple Silicon build from a published source commit, a valid Developer ID signature, Hardened Runtime with minimal entitlements, accepted Apple notarization, stapled ticket, Gatekeeper/quarantine installation smoke, archive hashes, a reviewed dependency inventory, and matching immutable release metadata. The Site must link to those exact verified GitHub Release assets and pass anonymous HTTPS, MIME, and checksum checks before a download is presented as ready.

Before claiming Telegram compatibility or stable distribution, resolve the applicable Telegram API Terms gates for public title, minimum functionality, and sponsored channel media. The current scope excludes video playback; do not hide sponsored media or claim compatibility until the required behavior is implemented and verified.

Real login, chat/read/send, multi-account lifecycle and resource measurements remain separate from synthetic tests. Do not claim twenty-account certification without twenty real authorized test accounts and the documented matrix. Never publish API hashes from local configuration, account data, signing materials, notarization credentials, updater keys, private receipts, or runtime logs.

See `TDLIB.lock.json`, `DEPENDENCIES.md`, `NOTICE`, and `ACCEPTANCE.json` for source pins, licensing, evidence, and open gates.
