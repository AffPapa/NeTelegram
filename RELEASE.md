# Release status and gates

NeTelegram is in development. No stable application release is available. A public source checkout or development Site does not mean an app binary is tested or ready to distribute.

A downloadable macOS release requires a reproducible Apple Silicon build from a published source commit, a valid Developer ID signature, Hardened Runtime with minimal entitlements, accepted Apple notarization, stapled ticket, Gatekeeper/quarantine installation smoke, archive hashes, a reviewed dependency inventory, and matching immutable release metadata. The Site must link to those exact verified GitHub Release assets and pass anonymous HTTPS, MIME, and checksum checks before a download is presented as ready.

Before claiming Telegram compatibility or stable distribution, resolve the applicable Telegram API Terms gates for public title, minimum functionality, and sponsored channel media.

- Terms §2.3 says the app title must not include “Telegram” unless that word is preceded by “Unofficial”. The requested title `NeTelegram` does not meet that wording. Keep the repo/codename as requested, but do not choose a different public app title without the user's decision.
- Terms §3.3 requires official sponsored messages when channel content is accessible. For the pinned TDLib commit in `TDLIB.lock.json`, `td_api.tl` exposes `getChatSponsoredMessages`; it also exposes `getVideoMessageAdvertisements` for video messages whose `messageProperties.can_get_video_advertisements` is true. The official sponsored-message specification requires a fullscreen video playback path for channel video ads. The current product scope excludes a general video player, so the minimum compliant channel behavior remains unresolved. Do not hide sponsored media or claim compatibility until the user resolves the scope and the required behavior is implemented and verified.

Primary references: [Telegram API Terms](https://core.telegram.org/api/terms), [Sponsored messages](https://core.telegram.org/api/sponsored-messages), and the [pinned TDLib 1.8.68 API schema](https://github.com/tdlib/td/blob/c15d3f5a5de6e3ba5839822c451152e5e18bb700/td/generate/scheme/td_api.tl).

Real login, chat/read/send, multi-account lifecycle and resource measurements remain separate from synthetic tests. Do not claim twenty-account certification without twenty real authorized test accounts and the documented matrix. Never publish API hashes from local configuration, account data, signing materials, notarization credentials, updater keys, private receipts, or runtime logs.

See `TDLIB.lock.json`, `DEPENDENCIES.md`, `NOTICE`, and `ACCEPTANCE.json` for source pins, licensing, evidence, and open gates.
