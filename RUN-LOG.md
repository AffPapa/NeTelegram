# Run log — Neridian

# Run log — Neridian

## 2026-10-13 — VoiceOver authorization-step announcements

- App source commit: `4478f967654b270cd78f71a5afe69f625491d38d`.
- Change: AppKit posts short, static announcements for phone, code, 2FA, email, registration, and QR steps. Copy is selected from typed TDLib state only; it does not include entered values. Repeats are suppressed per account, runtime generation, and step.
- Local verification: `swift test` passed 130/130 on Xcode 27.0 / Swift 6.4 / macOS 27 SDK, using a temporary SwiftPM module cache.
- Exact-SHA CI: Swift tests run `38387314803` passed; pinned TDLib/Dev.app build `38387315058` passed. CI assembled and verified Dev.app but did not launch it or run VoiceOver.
- Site: public v113 at `https://netelegram.iryadom.chatgpt.site`; anonymous `/devlog/` and `/downloads/` returned 200 `text/html`. Downloads continues to show no app release.
- Limits: no native VoiceOver walkthrough, real login, QR interaction, keyboard-only journey, RTL/IME, or signed release.


## 2026-10-13 — Active notification snapshot reconciliation

- App source commit: `dd11b9f38978870bf80509c239070d2570c7d8d4`.
- Change: `updateActiveNotifications` now re-enqueues routeable active snapshot entries after state reconciliation. Reconciliation is silent and uses existing privacy and stale-route checks.
- Local verification: Swift tests passed 130/130 on Xcode 27.0 / Swift 6.4 / macOS 27 SDK.
- Exact-SHA CI: macOS run `38388246897` and pinned TDLib/Dev.app run `38388246709` succeeded.
- Correction: public Site v113 and the Site source devlog actually ended at `e89265c`; the prior checkpoint’s claim that `4478f96` was visible publicly was wrong. Updated source now includes `4478f96` and `dd11b9f`; publishing and anonymous verification are in progress.
- Limits: no real Notification Center permission/account/tap/reconcile race, native VoiceOver, or signed release. Process inspection was blocked by macOS sandbox; the old candidate is from `ff3da44`, not `dd11b9f`.
