# Release status and gates

NeTelegram is the selected public product and repository name. Its compatibility with Telegram API Terms §2.3 is unresolved; no compatibility clearance is claimed. The app is in development; no stable application release is available. A public source checkout or development Site does not mean an app binary is tested or ready to distribute.

A downloadable macOS release requires a reproducible Apple Silicon build from a published source commit, a valid Developer ID signature, Hardened Runtime with minimal entitlements, accepted Apple notarization, stapled ticket, Gatekeeper/quarantine installation smoke, archive hashes, a reviewed dependency inventory, and matching immutable release metadata. Verification has two receipts so the order is executable: first an append-only asset receipt proves GitHub's public bytes and native checks before Site packaging; then the final delivery receipt references that asset receipt and records the deployed Site version plus anonymous HTTPS, MIME, download, and updater-feed checks. The Site must link to those exact verified GitHub Release assets before presenting a download as ready. The immutable manifest is not changed after publication.

Before claiming Telegram compatibility or stable distribution, resolve the applicable Telegram API Terms gates for public title, minimum functionality, and sponsored channel media.

- The requested public app display name is `NeTelegram`. This includes “Telegram” without the required “Unofficial” prefix under §2.3; compatibility is unresolved and stable publication remains gated. Section 2.2 still requires prominent disclosure that the app uses the Telegram API and is part of the Telegram ecosystem. This naming choice is not trademark clearance. The §1.3/1.4 basic-functionality review and §3.3 sponsored-media requirements remain unresolved release gates; no compatibility claim follows from the name change.
- Terms §3.3 requires official sponsored messages when channel content is accessible. For the pinned TDLib commit in `TDLIB.lock.json`, `td_api.tl` exposes `getChatSponsoredMessages`; it also exposes `getVideoMessageAdvertisements` for video messages whose `messageProperties.can_get_video_advertisements` is true. The local candidate adds sponsored text/photo cards, fully downloads a selected sponsored photo before displaying its content, uses the bounded PhotoPipeline for previews, and implements TDLib reporting. Sponsored animation/video handling, sponsored-message view reporting (the pinned TDLib schema has no corresponding method), in-app Telegram deep-link routing, and the required fullscreen sponsored-video playback/timing remain incomplete. The user explicitly declined a sponsored-video player and instructed us to defer channel access or stable release if required. Therefore channel reading is a release-blocked feature until compliant fullscreen sponsored-video playback/timing is implemented and verified; do not expose it in a release build or claim stable compatibility. Development-source code may still contain unfinished channel paths, which are not a release claim.

Primary references: [Telegram API Terms](https://core.telegram.org/api/terms), [Sponsored messages](https://core.telegram.org/api/sponsored-messages), and the [pinned TDLib 1.8.68 API schema](https://github.com/tdlib/td/blob/c15d3f5a5de6e3ba5839822c451152e5e18bb700/td/generate/scheme/td_api.tl).

Real login, chat/read/send, multi-account lifecycle and resource measurements remain separate from synthetic tests. Do not claim twenty-account certification without twenty real authorized test accounts and the documented matrix. Never publish API hashes from local configuration, account data, signing materials, notarization credentials, updater keys, private receipts, or runtime logs.

See `TDLIB.lock.json`, `DEPENDENCIES.md`, `NOTICE`, and `ACCEPTANCE.json` for source pins, licensing, evidence, and open gates.

## Sparkle framework and release ZIP

The development build embeds Sparkle 2.10.0 from the exact package and binary
pins in `SPARKLE.lock.json`. Its framework contains nested helpers and XPC
services that arrive with upstream ad-hoc signatures. A distribution build
must replace those signatures with the product's Developer ID identity,
working from the innermost nested executable outward, preserving any required
per-helper entitlements. Sign the Sparkle framework after its nested code,
then sign the app executable and outer app. Do not use `codesign --deep` to
sign: it can apply the wrong options or entitlements to nested components.
The existing development script is not a distribution-signing script.

After inside-out signing, verify every nested signature and the outer app,
notarize and staple the app, then create the distributable ZIP from the
stapled app. Preserve framework symlinks and executable permissions, and keep
the app as the archive's sole top-level item:

```sh
ditto -c -k --norsrc --keepParent \
  "/absolute/path/NeTelegram.app" \
  "/absolute/path/NeTelegram.zip"
```

The `--norsrc` option avoids adding a top-level `__MACOSX` AppleDouble folder,
which would violate the release archive's single-app-root validation. This
archive command was checked against the current development bundle for entry
layout and Sparkle symlink preservation only; it does not establish Developer
ID signing, notarization, Gatekeeper acceptance, or release readiness. Generate
the release SBOM and hashes from these final ZIP bytes and never modify the
archive after signing or notarization.
