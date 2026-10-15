## 2026-10-14 — Deterministic third-party release notices

- Added `Scripts/generate_release_notices.py`, which assembles the project MIT license, NOTICE, TDLib BSL, OpenSSL Apache, libphonenumber Apache, and SQLCipher BSD notices. It checks the TDLib, OpenSSL, and country-data license hashes against their source locks before writing. Metadata CI now runs the generator and requires a nonempty result.
- Generated `/private/tmp/NeTelegram-THIRD-PARTY-NOTICES.txt`: 27,015 bytes, SHA-256 `7f4fe911172ea38c2f5c1c12f4b3af016e510538c4a7c3c05362de7e2c856325`. Release manifest validation requires this notice asset together with the notarized app ZIP/DMG and binary-reconciled SBOM.
- Local verification: release metadata suite 35/35; checkpoint validation, manifest JSON parse, notice generation, and `git diff --check` passed. The site source already has a shared renderer and stylesheet for all routes; no duplicate page redesign or deployment was needed in this tooling slice.
- Repo remains `AffPapa/NeTelegram:main`, base and origin SHA `4459cd817ffd4499cfc6e429e78ad6fa64bf55c1`; no app source or Dev.app changes. GitHub auth is unchanged and local modifications remain unpushed, so hosted CI and the existing Site devlog are pending.

## 2026-10-14 — Release artifact manifest and SBOM reconciliation guards

- Expanded the release validator to require `app_zip`, `dmg`, `sbom`, and `notice`. Signing/notarization/Gatekeeper fields apply only to application/update binaries. SBOM metadata must match release version and source commit, state that the release binary audit passed, and carry SHA-256 hashes matching the exact app executable and bundled `libtdjson.dylib` read from the app ZIP. URLs must match the repository, tag, and asset filename. Duplicate and parent-traversal ZIP paths fail closed.
- Extended `Scripts/generate_sbom.py` with an optional `.app` release audit. It verifies embedded version/source, a non-development bundle ID, Developer ID signature and strict codesign verification, stapled ticket, Gatekeeper assessment, and arm64 slices; it records the main executable and TDLib hashes. Without an actual app bundle, the output remains clearly marked incomplete and the release validator rejects it. Added these requirements to the manifest template and dependency instructions.
- Local verification: release metadata suite 33/33; checkpoint validation, checked-in JSON parsing, and `git diff --check` passed. The bundle-verifier unit test mocks macOS tools to exercise the decision path; this is not evidence that a real signed/notarized bundle passed. No app source changed and the canonical Dev.app was not rebuilt or replaced.
- Exact repo state: `AffPapa/NeTelegram`, `main`, base/origin SHA `4459cd817ffd4499cfc6e429e78ad6fa64bf55c1`; changes are local in the release tooling/checkpoint files. `gh auth status` still reports both configured tokens invalid. Prior GitHub connector create-blob and Contents API writes returned 403; no hosted CI or public Site update for this milestone. The public Site remains v175.
- Next action: restore authorized write access, push one checkpoint commit, verify metadata CI, and then batch a factual devlog update on the existing Site. Product release is still blocked by real-user test coverage, Developer ID/notarization, Telegram compatibility gates, and final install/update smoke.

## 2026-10-14 — Current-source authentication screen visual check

- Inspected the already-open canonical `/private/tmp/NeTelegram-Dev.app` through CUA; title matches app source `7fd003088e2593fc2b808f7903e8f8b96c6a1c9b`. The default-size light-appearance screen is centered and shows country search/picker, phone input, status, Continue and QR controls. AX also exposes names/help for country and phone inputs. No UI controls were activated, no login data was entered, and the app was not rebuilt or replaced.
- This evidence narrows the earlier “crooked” report: the current candidate is centered at its default size. AUTH03 stays partial because minimum-size, dark/contrast, code/2FA/QR/registration states, VoiceOver, and real login are unverified. The screenshot is a native observation, not a synthetic fixture.

## 2026-10-14 — Release SBOM tooling slice

- Added `Scripts/generate_sbom.py`: CycloneDX 1.6 JSON from TDLib/OpenSSL and country-data locks, including bundled/static/system/build-only scope distinctions. Output explicitly states it is a source-pin inventory and needs reconciliation with the final signed bundle; it does not imply binary completeness.
- Added two focused generator regressions and wired generation/JSON parsing into the five-minute metadata workflow. Updated `DEPENDENCIES.md` with the command and completeness boundary. No Swift sources changed; no Swift suite or Dev.app build was repeated.
- Local evidence: focused tests 2/2; CLI generation and Python JSON parsing passed; `git diff --check` passed. Official CycloneDX documentation identifies JSON Schema as the reference implementation and lists CycloneDX 1.6 schemas.
- Publication checkpoint: app repo `AffPapa/NeTelegram`, branch `main`, base `4459cd817ffd4499cfc6e429e78ad6fa64bf55c1`, initially clean. `gh auth status` reports both configured accounts' tokens invalid. The authenticated connector reads repository metadata and reports push permission, but its Git Data API `create-blob` call returned HTTP 403 `Resource not accessible by integration`; no remote file was written. A follow-up actual generator-file create also returned the same 403 via Contents API, confirming the integration cannot write. No token was exposed, and no new login/token flow was started. Public Site remains v175; no Site update was made.
- Remaining: authenticate the already intended GitHub route, then commit/push this slice and confirm metadata CI; update the existing Site devlog only after the source commit and CI result exist.

## 2026-10-14 — APP07 transient push notification and v171 devlog

- App source is exact commit `aab6a4a2df950ae61de4d69b5f67a2b251e6d8a2` on `AffPapa/NeTelegram:main`. `notificationTypeNewPushMessage` is now treated as a temporary state: live updates preserve the existing notification/route; active-snapshot reconciliation retains its prior account/chat/topic route until TDLib supplies the full `NewMessage`. No main-topic route is inferred.
- Focused local regression passed 1/1. Full serial Swift suite passed 164/164 in 0.459 s on arm64e / Xcode 27 / Swift 6.4. `Scripts/dev-app.sh` built the sole canonical `/private/tmp/NeTelegram-Dev.app` from exact source in 5.24 s; BuildInfo, source fingerprint and build record agree, executable SHA-256 is `d218bf00ca886ee9fc32b4621221d6fea963dbb0c4bd7576756565deceaf6360`, pinned TDJSON SHA-256 is `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`, and ad-hoc `codesign --verify --deep --strict` passed. CUA showed title `NeTelegram · dev aab6a4a` and the clean login screen; no credentials or accounts were used.
- Exact-source hosted run [38505482508](https://github.com/AffPapa/NeTelegram/actions/runs/38505482508) passed the filtered runner probe and compiled the test bundle on macOS 15 / Xcode 16.4 / Swift 6.1.2, but after `Build complete! (0.39s)` the full test process emitted no `Test run started` through 4m24. It was cancelled; no hosted full-suite PASS. The prior run 38505192226 was cancelled when the implementation was expanded to cover active-snapshot reconciliation, so its result is not acceptance evidence. Diagnose the Xcode 16.4 / Swift 6.1.2 runner startup before any unchanged retry; local Xcode 27 PASS does not substitute for hosted coverage.
- Public Site v171 retained its existing project and public URL. Site-source commit `07256341ff02f240fddf21d758a3a2d1b9250dc0`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_62ec1356376c8191a0bb3ffac596b98c`; deployment `appgdep_6acef6eb8bb88191b69865e8e9dc1e2b` succeeded. Archive SHA-256 `fe85119b2c702de70ee8788ace4ca662f5c43e3b5c44fa2ec6feccd61a1917d5`; Sites saved content hash `sha256:efd2f98d46090cacde5b75379765a63e0c8279c11c5bd6c9a46c8fa190e225f5` (440,320 bytes, 14 files). Anonymous in-app browser confirmed the bilingual `/devlog/` entry and `/downloads/` still has no build or download link. Both archived feeds parse as RSS; direct public XML navigation was blocked by the browser client and shell DNS lookup failed, so this turn does not claim fresh public feed MIME validation.
- Release/downloads were not changed. No actual notification center delivery, Telegram account, 20-runtime operation, Developer ID/notarization, Gatekeeper or user release was verified.
- Efficiency note: the first notification patch handled the live update but missed the snapshot path. It was detected in review, and the intermediate CI was cancelled before using it as evidence; the final source commit includes both paths. Check every producer/reconciliation path before dispatching exact-source CI.

## 2026-10-14 — AUTH05 development milestone published to Site v170

- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf` advanced from v169 to v170. Site source commit `272e257fbe70e6d7de3fb19faff69f78c9cfcdca`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_9497e7c9a8b481918d05937c8ee77735`; public deployment `appgdep_6acee10806988191b7212e17add857a3`.
- Local archive: `/private/tmp/netelegram-site-20261014-fa80d5a.tar.gz`, SHA-256 `b72952526f130f624d4bd45504efb6545b72bbf598d22c02d3a198b3e40107c4`; Sites saved content hash `sha256:fa75c32cdb9949dc2988d74dbb9865f5f9d45a6edc8ba5e8336ff0cc8226cc58` (440320 bytes, 14 files).
- `get_site` confirmed active/public v170 and successful deployment. Anonymous cache-busted HTTPS `/devlog/?verify=fa80d5a` and the accessibility tree showed the bilingual AUTH05 entry and its exact CI/native links. The first browser reload showed cached v169; a query-string refresh resolved it. Site downloads were not altered; no app binary is advertised.
- App checkpoint before this deployment receipt: `dde726e` (app source `fa80d5a`). Site push used only the existing official Sites helper and temporary credential via hidden stdin; no credential was stored in the repository.

## 2026-10-14 — AUTH05 country search verified in the canonical Dev.app

- App source commit: `fa80d5a5f77b1fecf583754f3fe5cf69209be75b`. Search now matches localized and English names, region codes, and calling codes; the currently selected country remains visible as a separate marked option while filtering. Selecting a result retains its exact region, including for shared `+1` calling codes.
- Focused regression passed 1/1. Exact-source local serial Swift suite passed 163/163 in 0.426s on arm64e / Xcode 27.0 / Swift 6.4. Hosted macOS CI [38497467214](https://github.com/AffPapa/NeTelegram/actions/runs/38497467214) passed its runner probe, then was cancelled at the five-minute job limit during the full suite; no hosted suite result is claimed.
- Pinned TDLib arm64 Dev.app workflow [38497467210](https://github.com/AffPapa/NeTelegram/actions/runs/38497467210) passed. The sole canonical local bundle `/private/tmp/NeTelegram-Dev.app` was rebuilt from this source in 0.18s; ad-hoc code signature verification passed. CUA confirmed search `Canada` returns `🇨🇦 Канада +1` and selecting it updates the control. No phone number or code was entered.
- Site v169 remains live until one batched AUTH05 development update is deployed. No app release, real Telegram login, real-account coverage, or 20-runtime certification occurred.
- Speed guard: one source commit, one canonical bundle, focused test plus one exact-source local full suite after hosted cancellation, one native workflow; no unchanged CI retry or duplicate app launch.

# NeTelegram run log

## 2026-10-13 — Native smoke checkpoint wording corrected

- Re-read `.github/workflows/native-app.yml` and `Scripts/window-lifecycle-smoke.sh`, then checked the exact-source workflow artifact metadata. Workflow `38407466662` for app-source `816bbb4ab2a61817cc3da0780f47219b1f8f52e9` did launch the isolated Dev.app, capture a first-run screenshot, verify last-window close and same-PID LaunchServices reopen, and issue normal Cmd+Q.
- Corrected APP04, AUTH03, and `PROJECT-STATE.json`: the smoke used temporary CI Application Support and no account; it does not prove live TDLib, real login, 20-profile operation, Keychain persistence, or visual quality of the captured screenshot. The previous “did not launch” checkpoint sentence was wrong.

## 2026-10-13 — Site v123 deployed and anonymously checked

- Existing public Site project retained: `appgprj_6acba85192e08191acdf7011928848cf`; version 123 source `bbfa7c7df93f9bf2974291109a71f11ccaad80a4`, deployment `appgdep_6ace3a2734c881918019aefea91f33ee`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_4a7ee91928508191b97b4eb69d1e62ad`.
- Exact saved archive SHA-256: `23f329caf27bf679b3863498fe27da8693c99bd9c35e913df45d7208a2707c5b`; Sites-reported content hash `sha256:fff05212b572d4aebe8f9f0e6f2b98780828fceeb00ced58589d49a49e9ccc1e`.
- Anonymous TLS-verified checks: `/devlog/` 200 HTML with `04279b9`; `/downloads/` 200 HTML with `NO RELEASE` and no release-download URL; stable and alpha feeds 200 `text/xml` and parse as XML.
- No app binary was built, signed, or released for this test-only milestone.

## 2026-10-13 — APP16 critical update during queue shutdown

- App Swift source is unchanged at `816bbb4ab2a61817cc3da0780f47219b1f8f52e9`; test/evidence commits `12114c5` and `04279b967c8296a8c73719ce79030286dfe4570a` are on `main`.
- Extended the shutdown regression to fill the shared capacity, block a final `updateDeleteMessages` JSON update from the same client, allow the single already-received item through shutdown, and assert FIFO with the preceding authorization update plus rejection of later input. The test comment explicitly limits this to queue preservation; it is not a real expiry/TTL test.
- Targeted local test passed 1/1. Exact-SHA macOS CI [run 38409529115](https://github.com/AffPapa/NeTelegram/actions/runs/38409529115) passed for test/evidence commit `04279b967c8296a8c73719ce79030286dfe4570a`. No app rebuild was needed because Swift app source did not change.
- APP16 stays partial: no real TDLib receive worker, 20-client saturation, real TTL expiry, or runtime overload measurement. Site v122 remains live until v123 archive-backed deployment completes.

## 2026-10-13 — Oversized TDLib updates fail closed

- App source commit: `6c6fff49d6c43746b3990de178b723d1eaf75172`.
- The C bridge measures the borrowed TDLib JSON before copying and rejects payloads above 16 MiB. The Swift queue rejects any single event larger than its configured byte capacity; the receive gateway reports the bound and prevents further sends instead of silently dropping an update.
- Local serial Swift suite: 136/136 passed. Exact-SHA [macOS CI](https://github.com/AffPapa/NeTelegram/actions/runs/38395900507) and [pinned TDLib/Dev.app workflow](https://github.com/AffPapa/NeTelegram/actions/runs/38395900428) passed.
- Public development Site v117 deployed at https://netelegram.iryadom.chatgpt.site from Site source commit `fb9b464c8ae2cbfc687e261cdf3f23237a72152e`; anonymous checks returned 200 for the updated routes and empty stable feed.
- Not verified: real-account overload behavior, Instruments/RSS measurements, and a 20-account burst. No login or account data was used.

## 2026-10-13 — Safe unfinished-login removal published to development Site

- App source: `d57d569c08ca5273435fdb2e95a51629e1527df5`; GitHub docs/checkpoint HEAD before this entry: `8c43b2616e6668498fc4b1bbc89101d0267a3e94`.
- Site source commit: `7447d22eaf613b9c008734e1e883dbc480a8a934`; saved version 115: `appgprj_6acba85192e08191acdf7011928848cf~appgver_e4f6eff6cb308191906c8b63b2d7e682`; public deployment `appgdep_6ace186c4bc08191914b2f9361e1dd4e` succeeded.
- Site archive SHA-256: `0b9ff682c62f1d59fd406ee6356cb6389d8cab7fb9827ad2d53d92105be2da77`; Sites-reported content hash `sha256:a2f4e1d693a67fc615e34681adbd7aaf45dd644e2e5369e56ccf283b6a30ed75`.
- Anonymous verification: in-app browser rendered `/devlog/` with the new d57d569 entry and `/downloads/` with `NO RELEASE` and no download button. Read-only HTTPS fetched both stable and alpha XML feeds as valid empty RSS. `get_site` confirmed active, public, latest version 115.
- Route diagnosis: default local shell could not resolve the Sites Git hostname or public Site host; official helper succeeded with approved network access. Do not change Site origin or route publication through browser uploads.
- Limits: no app binary release, no actual Telegram login/profile close, no 20-account certification, no Developer ID/notarization, and no updater release.

## 2026-10-13 — Acceptance evidence and checkpoint routing corrected

- Updated the top-level acceptance summary to current app-source `d57d569c08ca5273435fdb2e95a51629e1527df5`, 134/134 local serial tests, exact-SHA CI and accountless native smoke.
- Marked older case evidence as commit-scoped historical snapshots. This prevents older test counts or local candidates from being mistaken for proof of the current source; all real-account and twenty-account claims remain open.
- Corrected the ambiguous stale repository-head field to `repo_head_before_checkpoint`; app-source, documentation, Site-source, saved version and deployment identities remain distinct.
- No Swift source changed; no app tests or rebuild were repeated for this documentation-only correction.

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
- Correction: public Site v113 and the Site source devlog actually ended at `e89265c`; the prior checkpoint’s claim that `4478f96` was visible publicly was wrong. Site v114 is now public. Anonymous curl confirms `/devlog/` 200 with both exact commits, `/downloads/` 200 without a release, and valid empty stable/alpha XML feeds. A first verifier had a boolean-expression error; the corrected raw-response check passed.
- Limits: no real Notification Center permission/account/tap/reconcile race, native VoiceOver, or signed release. Process inspection was blocked by macOS sandbox; the old candidate is from `ff3da44`, not `dd11b9f`.


## 2026-10-13 — Site v114 verification

- Site source commit: `9f7b2256db715fd83b90f51a5cf22374ab1d26c4`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_8f91acef31b48191b6fdcb39ab5ad7fb`; deployment `appgdep_6ace12db0d3881918a0b08d461c495c7` succeeded.
- Archive SHA-256: `3228b204d8e769eef7ebb51baf150bd7c52d2615f43a6d8ff06f3116a71dec08`; Sites content hash `sha256:8cfcb5561d0f39237bdb5f335ba3c5a60821c861ccfd60e5764b07270a8df3f3`.
- Anonymous checks: `/devlog/` 200 HTML with `4478f96` and `dd11b9f`; `/downloads/` 200 HTML with no-release state; stable and alpha update XML each 200 and parse as valid empty feeds.
- Verification correction: the first local boolean expression constructed a string before membership testing and falsely said commit markers were absent. A corrected verifier and raw response confirmed the deployment.


## 2026-10-13 — Safe removal of an unfinished local login

- App-source commit: `d57d569c08ca5273435fdb2e95a51629e1527df5`.
- Change: the Account menu now offers removal only for a profile without a verified Telegram identity. It writes a durable pending-removal marker, prevents later identity association/restoration, asks TDLib to close, then removes the route before deleting that profile’s keys/files. Failed Keychain, file, or catalogue cleanup retains a retryable marker; confirmed accounts are rejected.
- Local verification: serial Swift suite passed 134/134 on Xcode 27.0 / Swift 6.4 / macOS 27 SDK. Failure-injection tests cover pending restore exclusion, retry after file failure, preserving files after Keychain failure, and refusing verified identities.
- Exact-SHA CI: macOS run `38390951012` and pinned TDLib/Dev.app run `38390951049` succeeded for the app-source SHA above. The native workflow built and verified the arm64 Dev.app, launched its accountless first-run screen, captured a screenshot, and quit. It did not interact with the new removal item or close a real Telegram profile.
- Checkpoint correction: this audit found a stale `workspace.app_source_commit` and a `current_head_native_smoke` record tied to an older source. Those fields are now separated/labeled historical. No old local Dev.app was relaunched.
- Site: existing public v114 remains live; one factual devlog update for this commit is in progress. Downloads remain unavailable.
- Limits: no real login, real TDLib profile close, 20-account operation, Developer ID/notarization, updater, or stable release.

## 2026-10-13 — NeTelegram name, bilingual search copy, and APP04 window lifecycle

- App-source SHA: `13625c702e6dbd5d14b2f6d7d2acbf210806a8f3`. Local serial Swift suite: 136/136 passed on Xcode 27.0 / Swift 6.4.
- Exact-source macOS CI: [run 38399172699](https://github.com/AffPapa/NeTelegram/actions/runs/38399172699); pinned TDLib/Dev.app lifecycle: [run 38399172724](https://github.com/AffPapa/NeTelegram/actions/runs/38399172724). Both passed. Accountless Dev.app closed its last titled app window while the same PID remained alive, LaunchServices reopened one window in that PID, and Cmd+Q exited. This does not prove background Telegram updates; no account was logged in.
- GitHub README pages now include detailed Russian and English descriptions, the observed RU/EN query wording, a clear “no download yet” answer, and the independent/no-direct-connection notice. Search wording was taken from current result phrasing; search volume and ranking were not measured. The GitHub repository short description remains a separate metadata field.
- Search wording cross-check: English result copy uses “unofficial Telegram client for macOS” (Fenixuz: https://github.com/Novagramorg/macOS) and “alternative client for Telegram for macOS” (ForkGram: https://forkgram.en.uptodown.com/mac). Russian result sample was noisy; “альтернативный клиент Telegram для macOS” appeared in a Mac app result (https://ru.uptodown.com/mac/internet/newreleases/2). These are observed phrases only, not volume/rank evidence. Avoid “Telegram alternative” without “client” because results also mean replacement messengers.
- Removed the obsolete current-name claim from the checked-in GitHub Site snapshot while preserving the current NeTelegram name. Existing historic build labels remain only as historical facts when needed.
- Site v118 published from `6a02f20f94d1bc460cfb2f39a3350b8033d0ad44` as `appgprj_6acba85192e08191acdf7011928848cf~appgver_9c707118acac81918c9a4f27d010aec4`; deployment `appgdep_6ace28a09f9c819193ded68a92048fd4` succeeded at https://netelegram.iryadom.chatgpt.site. Anonymous checks passed for home, features, roadmap, devlog, downloads, and stable feed. Downloads still say NO RELEASE. Local archive SHA-256: `74ab3f64766d8bc28baf0496404f9c6ffa9dbab5a8ac09e84c9be9cb0a492f2c`.
- CI diagnostic lessons: an early smoke counted the status-bar service window; the final check counts visible titled app windows and waits until the main window is shown before recording launch. Do not reuse failed run IDs as evidence.
- Open: §2.3 current display-title compatibility, single-account real login (user deferred), all-20 real account coverage, Developer ID/notarization/Gatekeeper/Sparkle, channel/sponsored-media compatibility, and a downloadable release.

## 2026-10-13 — APP02 injected Keychain startup faults

- App source/test commit: `2ba4ccf0e8d899a2da7e4e42dedd30cbb5dc9b01`; two targeted local tests passed: injected Keychain error propagates without fallback, and one stalled synthetic read does not prevent the other 19 profile startup attempts from finishing at scheduler parallelism 2.
- Exact-SHA [macOS CI run 38401445104](https://github.com/AffPapa/NeTelegram/actions/runs/38401445104) succeeded, including Apple Silicon Swift tests and JSON validation.
- These are injected operation/scheduler tests. They do not exercise system Keychain behavior, app-level account failure UI, real login, or 20 authorized sessions. APP02 remains partial; no application release.
- Public development Site v119 is live at https://netelegram.iryadom.chatgpt.site. Anonymous checks returned 200 with expected MIME for all eight pages and valid stable/alpha RSS feeds; `/downloads/` truthfully reports NO RELEASE. Bilingual devlog and no-direct-connection disclosure are present; no current Neridian brand remains on public routes.
- Next implementation slice: APP03 A→B→A presentation/account snapshot isolation, with same numeric chat ID across distinct accounts, topics, and drafts. Reuse existing APP04/APP02 evidence; do not rerun unchanged checks.

## 2026-10-13 — APP03 account-local conversation snapshot

- App source commit: `9a984aeb74ff84d54c9e4c23d64db43c6434882e`. `presentRuntime` captures an account/generation-bound snapshot of selected conversation and draft; the reopen path restores snapshot text only when account, generation, and typed conversation key still match.
- One targeted local test passed: same numeric chat ID in accounts A and B retains distinct forum topics and drafts across A→B→A; a mismatched generation is rejected. This is synthetic core coverage, not a 1000-switch or real GUI test.
- Exact-SHA [macOS CI run 38402873737](https://github.com/AffPapa/NeTelegram/actions/runs/38402873737) succeeded. Pinned TDLib/[Dev.app build run 38402873559](https://github.com/AffPapa/NeTelegram/actions/runs/38402873559) assembled and verified the arm64 bundle; it did not launch the app or test an account switch.
- Public Site v120 source `b4b9de7fde9f59d1ff850c49759413afc9ed5dd4`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_60ae63b9fa948191b4399d20f40c1951`, deployment `appgdep_6ace2e966b4c8191ac152ca6ed24b509`. Anonymous `/devlog/` returned 200 `text/html` with the exact source SHA and CI runs. `/downloads/` remains NO RELEASE.
- APP03 remains partial: 1000 transitions, real account GUI, and real runtime generation stability were not tested. No application release.

## 2026-10-13 — NeTelegram brand/SEO sync, APP03 1000-selection check, Site v121

- Current product name is **NeTelegram** across canonical runtime identity, GitHub About, bilingual README, and Site v121. GitHub About now contains a concise RU/EN description, points to the existing public Site, and has topics `telegram-client`, `macos`, `swift`, `appkit`, `tdlib`, `open-source`. The full repository README has English and Russian descriptions, natural observed search phrases, honest development/download status, and an explicit statement that NeTelegram has no direct relationship with Telegram.
- Qualitative live SERP review found wording such as «неофициальный клиент Telegram для macOS», «клиент Telegram для Mac», «альтернативный клиент Telegram для Mac/macOS», «приложение для Telegram на Mac», “unofficial Telegram client for macOS”, “alternative Telegram client for Mac”, and “native macOS Telegram client”. Search volume and rankings were not measured. See Telegram API Terms §2.3: https://core.telegram.org/api/terms; the chosen brand remains an app-title compatibility gate for release.
- App-source commit `2285792bd360b392c79e4fe9da70dd7d70b86be7` factors draft restoration into the same account/generation/typed-conversation policy used by AppKit. One local targeted synthetic test passed 1000 alternating selections; exact-source macOS CI [38404936494](https://github.com/AffPapa/NeTelegram/actions/runs/38404936494) and pinned TDLib/Dev.app build [38404936522](https://github.com/AffPapa/NeTelegram/actions/runs/38404936522) succeeded. The bundle workflow did not launch the app; the synthetic loop is not native UI, a real account, or 20-runtime certification. APP03 remains partial.
- Existing Site `appgprj_6acba85192e08191acdf7011928848cf` advanced once from v120 to v121. Source `98208c1042c06f64cd112f8894861cf7ddf7f802`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_769a13e3472c8191851a46d9a8e4823e`, deployment `appgdep_6ace333a26f88191b1fe8b6a4ba9c0ee`, URL https://netelegram.iryadom.chatgpt.site. Local archive SHA-256 `2697fcc6ce3df8ce63e720e59e4f5d8c382ac3d81e76ae3fb60f4bdc2c5e8a80`; Sites content hash `sha256:d1d6a32d6453260a8c71f6404345683f7d197de355cb4a4d324478dc05aa1360`.
- Live anonymous validation returned 200 on all 8 HTML routes (`text/html`) and both alpha/stable feeds (`text/xml`). Current app SHA, title, bilingual SEO phrases, non-affiliation disclosure, and APP03 devlog are present; downloads remain NO RELEASE. Site `dist/` was synchronized into the app mono-repo's `website/dist/` mirror. The exact NeTelegram Site source helper was used; sandbox DNS denied its host once and the same helper succeeded with approved network access. No alternate Site, app version, or browser upload was created.
- Limitations: no live account/UI switch, no 20 authorized accounts, no signed/notarized application/download, no search-volume data. A stale divergent checkout still carries historical Neridian checkpoint text; preserve it, and use canonical `/private/tmp/netelegram-cli-work` for current state.


## 2026-10-13 — APP25 login-item policy and OPS02 source scan

- App-source commit `816bbb4ab2a61817cc3da0780f47219b1f8f52e9` adds a shared `LoginItemPreferencePolicy` for the four observed `SMAppService.mainApp` states and the user's requested enabled/disabled state. Registration still occurs only after explicit opt-in; disabling requests unregister; a status that does not confirm the operation is reported as unresolved.
- Targeted local command: `CLANG_MODULE_CACHE_PATH=/private/tmp/netelegram-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/netelegram-swift-module-cache swift test --no-parallel --jobs 2 --scratch-path /private/tmp/netelegram-app25-policy-check --filter loginItemPreferencePolicyOnlyRegistersAfterExplicitOptIn`; 1/1 passed on Xcode 27.0 / Swift 6.4. Exact-source [macOS CI run 38407467618](https://github.com/AffPapa/NeTelegram/actions/runs/38407467618) and [pinned TDLib/Dev.app run 38407466662](https://github.com/AffPapa/NeTelegram/actions/runs/38407466662) succeeded. The native workflow built and verified an arm64 bundle but did not launch it. Real Login Items persistence/removal remains untested; APP25 is partial.
- Gitleaks 8.30.1 scanned 241 commits (~5.15 MB), the current source tree (~218.91 MB), and saved Site v121/v122 archives (184,529 / 187,375 bytes); no known secret-pattern matches. A 99-file tracked-path inventory found no account sessions, databases, raw logs, certificates, or profile data. This is scanner and filename evidence, not a guarantee against arbitrary sensitive content. OPS02 stays partial pending a release-time asset/receipt allowlist review.
- Public Site v122 is live: source `c0d0b70c25a9f5517ec9a55a87e5f885bda34a5b`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_67852fdff6788191a59e7b785d19b7d8`, deployment `appgdep_6ace36ed4f988191aad661fa4bb63ff6`. Local archive SHA-256 `bab59f286f6fcfa40fcf03a91607597d290cd77773d05c9ec84bdb2283e4435e`; Sites content hash `sha256:b3f0e2f29a37f01e86d47571b48c3061d761a86630caca3270bc4436dc4fe19b`.
- Anonymous validation returned 200 for all 8 HTML pages and both valid empty XML feeds, with expected MIME. The current app-source SHA is on homepage/features/roadmap/devlog. The download route still reports no release.

## 2026-10-13 — Release preflight correction

- Evidence: read-only `security find-identity -v -p codesigning` exited 0 and reported 0 valid identities / 0 Developer ID Application identities. Public GitHub REST releases endpoint returned an empty list.
- Correction: supersedes the stale REL03 statement that four identities (including two Developer ID identities) were available. No key material or notary credentials were read.
- Result: release remains unavailable; no signed/notarized build, Gatekeeper result, or public application download is claimed.
- Also reconciled public Site state to v123; its download page still correctly says NO RELEASE.

## 2026-10-13 — APP01 restore/startup Core composition regression

- Change: added `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges`, combining the restore plan, two-at-a-time startup scheduler, runtime route registration, a stalled open, a rejected first request, fresh-generation retry, 20 routed update identities, and A→B→A presentation selection.
- Verification: focused local Swift test passed 1/1 on Xcode 27.0 / Swift 6.4.
- Limits: synthetic Core-only contracts; it does not invoke AppDelegate restore/startup functions, TDLib, real Telegram accounts, all-20 network sessions, or performance measurement. APP01 remains partial. Hosted validation: exact-SHA macOS CI 38412386934 passed on commit `5879143cc420cb0047606d099aa49810a609060e`.

## 2026-10-13 — NeTelegram landing redesign, public Site v126

- The official [Telegram homepage](https://telegram.org/) was used as an information-architecture reference: concise navigation, one clear first-screen message, direct platform/status paths, and short capability groupings. Text, identity, and the accessible SVG diagram are original NeTelegram work; no Telegram logo or app screenshot was reused.
- App repository commits `4d90d76` and `d63250d` update only the website assets and factual devlog. Both commits are pushed to `AffPapa/NeTelegram` `main`. The CI endpoint has no run for the documentation-only final commit; HTML parsing/internal-link checks, duplicate-ID checks, CSS brace/reduced-motion checks and `git diff --check` passed locally.
- Site v125 was deployed once for public visual review. The screenshot exposed an oversized hero heading wrapping into five lines; the layout was corrected in v126 and v125 is superseded, not edited. No app binary/version was created.
- Final Site: existing project `appgprj_6acba85192e08191acdf7011928848cf`, public version 126, Site source commit `6ce2199219b8adb692afb6b21780a42c436b0314`, app repo doc commit `d63250d8c3a4805144e0498d358d2608b0751a07`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_853bf475c108819182b4c3e60068279b`, deployment `appgdep_6ace41cb6cb081918195dc7caef7ee8e`; URL https://netelegram.iryadom.chatgpt.site.
- Exact archive `/private/tmp/netelegram-site-v126.tar.gz`: 280,158 local bytes; local SHA-256 `6683e8cd6f18344de07c3306b116943816a12c08ccffb15dbc0d3919cbe8dc7e`; Sites saved archive hash `sha256:0fa30ac22043981779ac8fdb34aeb4efdc8e9714a7213a807c876df0017ef276`, 471,040 bytes / 14 files.
- Public Playwright check returned 200 `text/html` for `/`, `/features/`, `/downloads/`, `/changelog/`, `/devlog/`, `/roadmap/`, `/privacy/`, `/source/`; both `/updates/stable.xml` and `/updates/alpha.xml` returned 200 `text/xml`. Final desktop (1440px) and mobile (375px) screenshots inspected: no horizontal overflow; headline height 119px / 74px; console 0 errors and warnings. No release asset exists; download status remains unavailable.
- Remaining app coverage is unchanged: no real account login, no 20 authorized runtime certification, no Developer ID identity or signed/notarized application. Next implementation work: bridge the APP01 Core composition test to the production AppDelegate restore/startup path.

## 2026-10-13 — APP01 startup-selection seam and Site v127

- App-source commit `62a75087e8c37ff07fa327613ff765f07c1d229a` adds `AccountRestorePlanner.pendingStartupProfiles` and calls it from `AppDelegate.restoreProfiles`. It preserves candidate order and excludes only account UUIDs with an existing runtime or startup task.
- Focused local Swift tests passed 2/2 on Xcode 27.0 / Swift 6.4: all 20 free candidates remain eligible; when one is running and one is starting exactly 18 remain. Exact-SHA [macOS CI run 38415556054](https://github.com/AffPapa/NeTelegram/actions/runs/38415556054) passed. This is a Core seam regression, not an AppDelegate execution harness: it does not create TDLib clients, read Keychain/storage, use real Telegram sessions, or measure 20-runtime load. APP01 remains partial.
- Updated the existing public Site project to v127: Site source `f1ffa1f9eff05c14f85bbd34b635733586f39511`; app-source commit `62a75087e8c37ff07fa327613ff765f07c1d229a`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_fe02914dc55081918588abbba3ce05a7`; deployment `appgdep_6ace43d1a9f8819187cf9829a862cb6f`; URL https://netelegram.iryadom.chatgpt.site.
- Exact archive `/private/tmp/netelegram-site-v127.tar.gz`: local SHA-256 `4fa34c21cd6a90bd534d01003e5b081ec206c5b161783ceee5219715ea7f281a`, 280,619 bytes. Sites saved content hash `sha256:119965791b77cc60f3c8d245e70f870b2c378314c33ba40e74fc43cbd67314ce`, 471,040 bytes / 14 files.
- Public check returned 200 `text/html` on all eight pages and 200 `text/xml` for stable/alpha updater feeds. Current APP01 entry appears on homepage/devlog; downloads still say NO RELEASE. Mobile 375px has no overflow, console has 0 errors/warnings. Final landing screenshot/desktop visual QA is recorded at v126; v127 changes only milestone copy and labels.

## 2026-10-13 — Site v128 stale asset cleanup

- The Telegram-inspired landing design was already complete; no second redesign was started. The official site's concise hero, direct app routes and benefit grid are structural references only. NeTelegram already has a short RU-first hero, scoped feature cards, explicit download status, product pages and an independence note.
- Removed two unreferenced old `Neridian Dev` PNG captures from the Site static assets. Static-source scan found no `Neridian` branding in served HTML/CSS/XML; the packaged archive excluded both assets (44 archive members checked).
- Existing public Site https://netelegram.iryadom.chatgpt.site was saved as v128 from `bcf5b46502c04681d20ef20eb3193d4384a7cec3` and deployment `appgdep_6ace458edd8081919c27948f7f12730b` returned `succeeded`. App source remained `62a75087e8c37ff07fa327613ff765f07c1d229a`. Archive `/private/tmp/netelegram-site-v128.tar.gz`: SHA-256 `759cfd6a80e0f96013e661f73439eed56dd5442eac69e38bdf8479f37cbdcf37`, 51,649 local bytes; Sites content hash `sha256:d02292ba21045dcd3b4fa03a301ec782cf9a7766d3747bafa4d682109fce7ae7`, 12 files / 215,040 bytes.
- Direct public HTTP fetch was unavailable because this environment could not resolve the Site hostname; the successful Sites deployment response and archive checks are recorded, but they do not constitute a route-level HTTP check for v128.

## 2026-10-13 — APP01 production enqueue dispatch and Site v129

- App-source commit `6434b101b8bd7124321858e79beb8535536b1aca` adds synchronous `AccountRestorePlanner.enqueueStartupProfiles`, now used directly by AppDelegate. The callback hands each eligible profile to the bounded scheduler without awaiting an earlier auth/network flow.
- Three focused local tests passed 3/3. Full exact-SHA [macOS CI 38417637060](https://github.com/AffPapa/NeTelegram/actions/runs/38417637060) and [pinned TDLib/Dev.app workflow 38417637092](https://github.com/AffPapa/NeTelegram/actions/runs/38417637092) passed for `6434b101b8bd7124321858e79beb8535536b1aca`. The native workflow built pinned TDLib and ran an isolated Dev.app window-lifecycle smoke: launch; close last window with same PID alive; reopen via LaunchServices in same PID; Cmd+Q. Screenshot captured but not visually reviewed; no account was entered.
- Public Site v129 uses source `3d8768a41c35c2a58155af796fdce93e1742ff59`, deployment `appgdep_6ace47b7829481919509682da8984d45`, version `appgprj_6acba85192e08191acdf7011928848cf~appgver_06de39ff88d481919aa752aa7254b159` at https://netelegram.iryadom.chatgpt.site. Devlog now has RU/EN exact-SHA evidence. Archive SHA-256 `4a67fa0b8983f984b12aa6452d25ca8a93f7e94894bb9ed51d79c46b0df60acf`, local 52,273 bytes; Sites content hash `sha256:1405033d04e1eb84b9ad7f93fb398b02b777c5176b642c6b4becdd45c91c717a`, 12 files / 225,280 bytes.
- No real Telegram account, twenty real runtimes, performance, Developer ID signature, notarization, Gatekeeper or app download was certified. Direct Site HTTP fetch remains blocked by DNS from this environment; Sites deployment succeeded but this is not a route-level verification.


## 2026-10-13 — NeTelegram Site v130 landing clarity pass

- Reference research: official telegram.org uses language/platform navigation, a concise product hero, benefit blocks and grouped informational links. Adapted only its information hierarchy; kept NeTelegram’s original editorial visual system and did not reuse Telegram marks, copy, or assets.
- Site source commit: `eb33a39823a068d5405b2d1792508dcb41254467`; public Site v130 saved as `appgprj_6acba85192e08191acdf7011928848cf~appgver_fbc448b84be881918f54b53ea22254bd`; deployment `appgdep_6ace4a5da9648191ba9e6ada4a9cf801` succeeded.
- Changes: replaced the multiple-profile/“20” hero drawing with an original abstract single-window illustration; made the conceptual/non-screenshot status explicit; simplified internal jargon; added a header EN link to the existing English overview; refreshed homepage and features evidence to app-source `6434b10` and exact CI/native run links. No download CTA or release claim added.
- Local checks: HTMLParser/anchor checks passed for homepage and features; `git diff --check` passed; stale old commit/run strings absent from the two edited pages. Public browser tab was refreshed and its accessibility tree confirmed the new content and version. Sites reported successful public deployment. Direct web-fetch tool could not access the hostname; no raw HTTP status claim.
- Archive: local SHA-256 `b3e2115a0d32da9cdf66015ca9ea66848f5161c20ab50a88a01e07157630054c`, 52,152 bytes; Sites reports content hash `sha256:2bccaef60fb35a85cff28b9ee35d8693eca15e6e430569de09bde439e30a7760`, 12 files / 225,280 bytes.
- Next: planned SecretsStore backend injection; no Telegram session entered and no 20 authorized runtimes measured.


## 2026-10-13 — SecretsStore Keychain backend injection and Site v132

- App-source commit: `3934bd21bc563fc8a0cc9b901a3650dd1b3cbd15`. `SecretsStore` now delegates typed read/add/update/delete operations to an immutable per-instance `KeychainItemBackend`; production default stays on Security.framework.
- Local verification: five focused tests passed on Xcode 27.0 / Swift 6.4 using an in-memory backend. They exercise real `SecretsStore` CRUD/policy methods for fail-closed read errors, explicit not-found creation, read-only no-create, API-hash update error without add fallback, and account-scoped deletion. No real Keychain was touched; system Keychain ACL and lock/unlock remain unverified.
- Exact-SHA macOS CI `38420552764` succeeded. Pinned TDLib/Dev.app run `38420551856` succeeded: dependency build and isolated arm64 app assembly/verification passed. It did not perform window interaction or account login.
- Site entries v131/v132: v131 published the new Keychain milestone. A cross-page verification caught `/features/` still referring to the older `6434b10`; corrected to current `3934bd2` in v132. This correction is recorded so resume checks the whole active route set once before finalizing, and does not treat history entries as current status.
- Site v132 source: `6302d3a84904c013ee38039bcdd332fe1987a824`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_288dc25fd4f4819185a89c65ddf837e3`; deployment `appgdep_6ace4cdaba7881919bc3cc02e5216327` succeeded. Local archive SHA-256 `757d336e4f5f69d5e82534bafa3e00cf743abf605e7277cd630c561a9314e1ed` (52,645 bytes); Sites hash `sha256:90846368dd019fc5a7969551ae1a0aa34b67cb9ee9daba59b240e998e2901a37` (12 files / 225,280 bytes). Refreshed browser accessibility trees verified new homepage, `/features/` and links. Direct web fetch remains unavailable.
- Release/account limits remain: no real Telegram login, no 20 authorized-runtime certification, Developer ID/notarized app and public downloads not available.

## 2026-10-13 — APP02 per-profile storage preparation and NeTelegram Site v137

- App source `26abae365b4eec54882ae69cc1274e20ddabb276` adds production-used per-profile storage preparation before TDLib runtime creation. Two focused tests passed; exact-SHA CI run [38425731506](https://github.com/AffPapa/NeTelegram/actions/runs/38425731506) and pinned TDLib/Dev.app build run [38425731851](https://github.com/AffPapa/NeTelegram/actions/runs/38425731851) passed. The latter assembled an arm64 Dev.app but did not launch the GUI or log in. APP02 remains partial; real Keychain, Telegram login, and 20 authorized sessions are not verified.
- Landing review against [telegram.org](https://telegram.org) found the existing NeTelegram hierarchy already communicates the product clearly: concise introduction, explicit no-download state, evidence-labelled features, direct navigation, and an original concept SVG. No additional illustration or broad redesign was justified. Branding and disclaimer remain independent and factual.
- Published Site v137 from source `775fee7bc71391ba90a5976492542128e1b16044`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_04790af39c4c8191af0e2d10eeff20be`; deployment `appgdep_6ace570e7e6481918128a73c93c1e559` succeeded at https://netelegram.iryadom.chatgpt.site. Public `/devlog/?v=137` and both restored screenshot assets opened; browser identified each PNG as 1024×768. The asset audit caught two historical image references missing from v136; both were restored before v137.
- Site archive: `sha256:e33b7240ce7799f65b72be5e163345865cf11b609322444c2779ae06a98ff767` (15 files / 491,520 Sites-reported bytes); local saved archive `/private/tmp/netelegram-site-v137-restored-images.tar`, SHA-256 `6671753a0140be6bafe2d30da674e5ff05d9e771f193103f71b351c66ea671f7`, 285,875 bytes. App repo `website/dist/` was synchronized to the v137 Site output.
- Next: continue from a distinct acceptance gap; do not repeat APP02/Site v137 checks without changed input. User deferred real login. No signed app release or twenty-account certification.


## 2026-10-13 — Shared NeTelegram site template and Site v141

- Rebuilt the existing public Site using `website/build_site.py`, one shared shell, route metadata in `website/content/*.json`, and independent HTML content fragments. Generated output remains static HTML/CSS with no client-side framework or JavaScript dependency. Added a native `<details>` mobile navigation, active route state, canonical and Open Graph metadata, shared footer, and a route validator.
- The v138 first pass exposed a dark status pill and the v140 devlog screenshot showed horizontal overflow. Both were corrected in the Site source; the final public rendering is Site v141. The public Site remains the same project and hostname.
- Focused validation passed: all eight routes have one H1, three consistent nav regions, active state, canonical metadata, existing local links and required assets; `git diff --check` passed. Public browser screenshots visually checked home, downloads and the dense devlog. The download page continues to state NO RELEASE and contains no fake download action.
- Site source: `4f99890bb6e01872e0e13dc02f975981c103abd7`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_89adc85509388191a024b0ec32faf360`; deployment `appgdep_6ace5c143c2c819182fe7243ce9a7c42` succeeded at https://netelegram.iryadom.chatgpt.site. Archive SHA-256 `390ea6353ec63a6c6bc319adb943282d5e77aec22d8c0faa49d0cca8d802b16d`; Sites content hash `sha256:157432c3b19cf4bfabfe1f85a0c3aa951d09305779300996f8b99885674c82bb` (15 files / 522,240 Sites-reported bytes).
- The mirror, generator, content source and validator are synchronized under the app repository's `website/`; app-source code and identity were not changed. Next: commit and push the docs/mirror checkpoint, then return to a distinct app acceptance gap. User login remains deferred; real-account/20-runtime proof and signed release remain open.


## 2026-10-13 — APP14 identity gate, Site v144, and checkpoint sync

- App source `14565217d47645248390853f1d7a7e495c3270dd` implements identity-bound local profile state: verified Telegram user ID gates private-state hydration, `getMe` is correlated by `@extra`, and mismatched identity closes that runtime. Two focused local tests passed. Exact-source [macOS CI 38431733861](https://github.com/AffPapa/NeTelegram/actions/runs/38431733861) and [pinned TDLib/Dev.app workflow 38431733910](https://github.com/AffPapa/NeTelegram/actions/runs/38431733910) passed. Real account revocation/reauth and 20 authorized runtimes remain untested; APP14 remains partial.
- Public Site v144 is live at https://netelegram.iryadom.chatgpt.site from source `dc015ddca81330db297f13d4289cf1c40a43faca`; deployment `appgdep_6ace60f0033081918e279cc45c848e65`, saved version `appgprj_6acba85192e08191baff6d10d81d5e71`. Sites archive hash `sha256:98081fb347d51b72a87a4ac3804c31e9d090195265f46772901d0042c584c422`, reported 522,240 bytes. Public devlog links the exact passing workflows. Local validator passes all eight routes. Public widths: 390px viewport → 375px document; 1440px viewport → 1425px document. No app download or release is available.
- Synchronized the v144 static site source and generated output into `website/`; updated APP14/site evidence and checkpoint pointers. Checkpoint commit `378cf388b59c1aba25b1a17f43dbd4f38aa1feb6` was pushed to `origin/main` after the sandbox DNS restriction was cleared for the authorized Git operation. No credentials, keys, or account data were recorded.

## 2026-10-14 — Shared Site design v145 and APP15 shutdown barrier

- Reworked the Site's visual system once for all eight static routes. `website/site.css` is now the editable design source; `build_site.py` copies it to generated `dist/site.css` alongside the shared HTML shell. `website/README.md` records the single-file restyle workflow. Existing route content remains separate; the home illustration and truthful no-download state are preserved. Static generation and `validate_site.py` passed. Local browser checks covered all eight routes at 390px (document width 375px, one H1 each); desktop home/devlog remained within 1425px at a 1440px viewport. Screenshot capture timed out in Playwright while waiting for fonts, so no screenshot visual PASS is claimed.
- Public Site v145: source `6fa7d210cad42c6407c46c5b422f22572cb201eb`, deployment `appgdep_6ace66bb8fb88191a1ee9f1dc6ac04ac`, version ID `appgprj_6acba85192e08191baff6d10d81d5e71~appgver_452c78e881208191bfdcf82e4edcfb20`. Source archive byte SHA-256 `4bd0febc96a2e971b10902349f139bcbb3bd474a547045fa47f97870a620078e` (286,415 bytes); Sites stored content hash `sha256:ee6e0d34cdfdc0aed9c9293900e23ba5111ca9036227dbc63e0ae32b7765b471`. Deployment returned succeeded at https://netelegram.iryadom.chatgpt.site.
- APP15 adds `RuntimeShutdownCoordinator` to track the expected client IDs separately from ordinary logout closes. Receiver/reducer drain is gated until each expected client reports `authorizationStateClosed`; unknown/duplicate acknowledgements cannot satisfy the barrier. A rejected close cancels quit and existing lifecycle bookkeeping waits for already-accepted closes.
- The first targeted Swift run correctly exposed compile errors because Swift Testing `#expect` cannot wrap mutating calls. Assertions were changed to evaluate into local variables. The rerun passed both focused tests. Exact-SHA macOS CI [38437898571](https://github.com/AffPapa/NeTelegram/actions/runs/38437898571) passed 150/150 tests on `256caf4faea294cddf4dd4e168cc2b64bd18a3d8`. Pinned TDLib/arm64 Dev.app workflow [38437335165](https://github.com/AffPapa/NeTelegram/actions/runs/38437335165) passed for product-code commit `15cb93b63c1654f256403b793ff05995a4907a09` (the later `256caf4` change only fixes test assertions); its accountless GUI smoke verified last-window close, LaunchServices reopen in the same PID, one-window state and normal quit. APP15 and APP04 remain partial for real authorized-account behavior.
- Updated the Site devlog with the exact test/workflow scope and deployed public Site v146: source `240412d258b98c19e3de876d60bf996eb352bbde`, deployment `appgdep_6ace695c756881918f8d2efde416ab90`, version ID `appgprj_6acba85192e08191acdf7011928848cf~appgver_d6ca329e03a481918117d1b7745327d4`. Source archive byte SHA-256 `4496f8195bdcc32e502725d83b75c5b820bb608cdf8f581b2bfbc94ffd0bc113` (286,941 bytes); Sites stored content hash `sha256:d53b0004b0e3002ba3a99cdc4de6cf034fcfe8ae9dfe5d096ece5f1f89fba702`. Public v146 `/devlog/` and `/downloads/` returned HTTP 200; both fit 390px (375px document width), one H1. The stylesheet returned `text/css`, 23,814 bytes, SHA-256 `a1154df7cc9c9a71b3a4892046de059655767eb4fb6d204ee7d71c3eb81115b1`. Downloads show no ZIP/DMG/release links.
- Fresh local signing-identity count: 0 valid code-signing identities, 0 Developer ID Application identities. Notary profile was not inspected. Real Telegram login remains user-deferred; no authorized 20-account quit, stable app, signing, notarization, or unresolved Telegram compatibility gate is claimed closed.

## 2026-10-13 — APP16 pipeline evidence and Site v147 checkpoint

- App-source `0fc9e8604a851ce8ab2968f5b2623a1417a7e350` adds integrated synthetic coverage for the common TDLib receive pipeline: 20 routes, one held callback while 19 lanes progress, bounded receive backpressure, and ordered accepted-event drain during shutdown. Two focused tests and the full local Swift suite passed (151/151, Xcode 27.0 / Swift 6.4). Independent read-only review confirmed the explicit callback-entered/drain-requested handshake is deterministic.
- Fresh GitHub API access failed during this checkpoint. Exact-SHA macOS CI run `38440068849` therefore has no established current terminal result; do not report PASS, failure, or pending. Exact-SHA pinned TDLib/Dev.app run `38440068795` was cancelled before any steps and provides no native-build evidence. Earlier accountless lifecycle smoke remains tied to product-code commit `15cb93b63c1654f256403b793ff05995a4907a09`.
- Existing shared responsive site design remains a single stylesheet and shared shell across all eight routes; no page-by-page redesign or app binary was added in v147. Public Site v147 uses source `a445eedc691d66943746781ad13384dd89304050`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_cbd5c1d62f088191bb98de8b500ac9d7`, deployment `appgdep_6ace70fe25388191816150f1949f6d64`, at https://netelegram.iryadom.chatgpt.site. Archive SHA-256 `19729a5a2921eff625b05e87c03b9a7c50752a9655d63973beb09eafb5ba6186` (286,675 bytes); Sites content hash `sha256:4c9685a0fab6ac72c5fccfae8683683edc693465af704ef18c15f67982861ffd`.
- Anonymous browser rendered the homepage, `/devlog/`, and `/downloads/` at 390px; checked pages had 375px document width. Devlog shows APP16 and local 151/151 while distinguishing unverified hosted CI and canceled native workflow. Downloads have no ZIP/DMG or GitHub-release link and state no application release. Existing all-eight-route validator/design evidence from v145 remains applicable because shared shell/CSS did not change.
- No real Telegram login, authorized 20-runtime operation, performance certification, Developer ID/notarization, or compatibility gate is claimed complete. User deferred login. Do not repeat APP16/site checks without changed inputs.

## 2026-10-13 — APP26 claim aligned to dispatch evidence

- A read-only review at repository checkpoint `ad1a81787a8cf9948eb7d6eaed00873370c37540` confirmed `LocalAccountRuntime.send` and `.close` share `RuntimeCommandGate`, with no direct gateway-send bypass. The gate guarantees synchronous call/dispatch ordering and reopens after an immediate close enqueue rejection.
- Corrected APP26 acceptance wording: it does not wait for a remote TDLib/Telegram response to each command before requesting close. This keeps the claim aligned with what source and deterministic tests prove. APP26 remains partial because exact-HEAD native lifecycle and real multi-account quit are not verified.
- No code changed and no tests were rerun; the existing deterministic gate tests are the evidence for this documentation correction. The exact-HEAD native workflow was canceled before steps; the previously passed accountless GUI smoke belongs to an older app-source commit.

## 2026-10-13 — Sign-in affiliation text corrected

- App-source commit `86855e4599ae4dc9d00274c07331617ddc5b3684` removes contradictory sign-in wording that called NeTelegram part of the Telegram ecosystem while also denying affiliation. The auth subtitle now says it is an independent unofficial client using Telegram API/TDLib with no direct relationship to Telegram Messenger LLP, and that other clients' sessions are not imported.
- Exact-HEAD AppKit `swift build` passed on Xcode 27.0 / Swift 6.4 in 4.69 seconds. The 151/151 local Swift suite is from unchanged Core code at parent app-source `0fc9e86`; it was not rerun for this copy-only UI change. Exact-SHA [macOS CI 38444116182](https://github.com/AffPapa/NeTelegram/actions/runs/38444116182) and [pinned TDLib/Dev.app workflow 38444116358](https://github.com/AffPapa/NeTelegram/actions/runs/38444116358) were running when this checkpoint was recorded.
- No Dev.app was launched and no local profile or Telegram client data was accessed. Native visual layout/contrast, login, and 20 authorized runtimes remain unverified. Public Site v147 was unchanged.

### 2026-10-14 — sign-in disclosure and Site v148 checkpoint

- App source commit: `86855e4599ae4dc9d00274c07331617ddc5b3684`. Exact-HEAD AppKit compile passed locally on Xcode 27.0 / Swift 6.4; the full 151-test suite is from base `0fc9e86` and was not repeated for the copy-only change.
- Exact-source GitHub macOS CI run [38444116182](https://github.com/AffPapa/NeTelegram/actions/runs/38444116182) concluded **cancelled** during “Build app and run core tests”; no CI test PASS. Exact-source pinned TDLib/arm64 Dev.app workflow [38444116358](https://github.com/AffPapa/NeTelegram/actions/runs/38444116358) succeeded for pinned dependency build/verification, isolated Dev.app assembly/verification, and artifact upload. This is accountless packaging evidence only.
- Public Site v148: source `48c314b77fa06f635399089aad316c5993c36cff`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_c23cd449d07c819196f72e9cf7d9befd`, deployment `appgdep_6ace755eb3e4819185693db0ce1866a3`. Source archive SHA-256 `79afff4bc7bc4695923f700b195ea8f6043f74e027503714339d460d8194f58e` (287,196 bytes); Sites content hash `sha256:3e9ca1b8ede1d70c40d350341b264549b3f8be61096de299917289af757e2f83`. Anonymous public `/devlog/` check at 390px showed 375px document width and confirmed commit, non-affiliation wording and no-login statement. Downloads remain unavailable.
- Synced the v148 devlog source and generated route into the app repository. Real login, 20 authorized runtimes, Developer ID/notarization, and compatibility gates remain open.

### 2026-10-14 — align hosted CI toolchain

- GitHub macOS CI run `38444116182` used Swift 6.1.2 / Xcode 16.4 on `macos-15`. Its 10-minute job timeout canceled `swift test` while `cancelledQueuedStartupDoesNotRunAfterItsPermitBecomesAvailable` was the only started test without a completion line. No concurrent workflow run existed to explain the cancellation.
- The exact test passed alone locally, and the full 151-test suite passed locally on Swift 6.4 / Xcode 27. CI now selects the `xcode-27` runner to match the tested toolchain generation; app deployment target remains macOS 14. Hosted verification for the workflow change is pending.
- Evidence is diagnostic, not a claim that the prior hosted suite passed. No account data or credentials were accessed.
- **Diagnosis correction:** the same 10-minute cancellation reproduced on the `xcode-27` runner with Swift 6.4, so the compiler-version mismatch was not the cause. Logs show Swift Testing starting the cancellation-sensitive test concurrently with the other tests. `swift test --no-parallel` completed locally with all 151 tests passing in 1.27 seconds. CI now returns to `macos-15` and invokes that explicit serial mode; hosted confirmation is pending.

### 2026-10-14 — hosted CI serialized and Site v149 published

- App repository/workflow commit `7eb1d292adc0d0f59d362c9eb925193d25128df6` changes CI to run Swift Testing explicitly with `--no-parallel` on `macos-15`. Exact run [38447978740](https://github.com/AffPapa/NeTelegram/actions/runs/38447978740) passed all 151 tests and checked-in JSON validation on macOS 15 / Xcode 16.4 / Swift 6.1.2. Local `swift test --no-parallel` passed 151/151 in 1.27 seconds on Xcode 27 / Swift 6.4. This resolves the prior 10-minute cancellations; the failed hypothesis that Xcode generation was the cause is superseded. Product source remains `86855e4599ae4dc9d00274c07331617ddc5b3684`.
- Public Site v149 source `c7c551dc5ddbd021cec894539e281c7d27cc3aae`, version ID `appgprj_6acba85192e08191acdf7011928848cf~appgver_fe401e8fbf848191ac535d721b3f7629`, deployment `appgdep_6ace7b3e44148191b1b9848cca2fd031` at https://netelegram.iryadom.chatgpt.site. Local archive SHA-256 `c9dc05bad1f314f5bc8b950b9139f616deeb799aa90a89db4e06f2e507d456ee` (287,610 bytes); Sites content hash `sha256:820c84b847c8b67a8ae9074bc13f761c9d6e69e0cd736b7fce3d1d2c3cfdbaf3`. Anonymous `/devlog/?v=149` showed the passing run/commit at 390px viewport (375px document width); `/downloads/?v=149` stated no verified release and linked zero ZIP/DMG assets.
- No app binary was released. Real account login, 20-runtime measurement, signing/notarization and Telegram compatibility gates remain open.

### 2026-10-14 — Shared Site design v150 and exact-state publication

- One shared CSS/design system and the existing HTML shell now serve all eight Site routes. The home keeps its original, clearly labelled concept illustration; content pages share consistent type, cards, status styles, navigation, footer, mobile layout, and reduced-motion behavior. The structure adapts Telegram.org's concise hero/value sections/footer without copying its assets or unsupported claims.
- App repository Site source commit `33147b0fff262db4825c5aa11b0782015d7485f1` was pushed to `AffPapa/NeTelegram`. The official Sites source helper committed/pushed exact Site source `92fdb0289165157b5f9ee8939dc96767c2915490`; archive `/private/tmp/netelegram-site-v150.tar` is 288,025 bytes, SHA-256 `5a732c4596fde83acba720ee464b8bc51ef3d12f01e2d9278ac1a688f2dc64d8`.
- Saved Site version `appgprj_6acba85192e08191acdf7011928848cf~appgver_50db2aac69548191bedc2057d6d3fcb5` and deployed successfully as `appgdep_6ace7e38f5d881918fa29d7fa0ebbd18` at https://netelegram.iryadom.chatgpt.site. Sites archive content hash `sha256:de3218cd58bdfef61848d4b7f6840aeb88c780b37761298374ee457eafa4c0c0` (15 files / 512,000 reported bytes).
- `python3 build_site.py` and `python3 validate_site.py` passed; both zero-item stable/alpha RSS files parse. Live public browser checked all eight routes at 375px: one H1, correct canonical, no horizontal overflow. Home was visually checked at 1440px and 375px. Downloads has zero ZIP/DMG/release links; both appcasts return HTTP 200 and `text/xml` with valid XML.
- Checkpoint was reconciled: previous nested Site v147 record now agrees with live v150, and latest repository HEAD is distinguished from unchanged product-code SHA `86855e4`. No native app code/build/release changed in this milestone.

### 2026-10-14 — clarify local profile slots in the sidebar

- App-source commit `4e96a1556e6cd5f74d0cabeb651e21fa64793b51` adds visible Russian copy below the account picker: these are local NeTelegram profiles on this Mac, and sessions from other apps are not imported. The sidebar search/chat list moved down to preserve spacing; picker identity/status behavior was not changed.
- Exact-source `swift build` passed on local Xcode 27 / Swift 6.4. SwiftPM's scratch and module caches were redirected to `/private/tmp` because the default user cache was inaccessible in the sandbox. The 151 Core tests were not rerun because this change only edits AppKit labels and frames. No Dev.app was launched and no Telegram profile/session data was accessed.
- Public Site remains v150; no download or release state changed. Native visual review, real login, 20 authorized runtime coverage, Developer ID/notarization and Telegram compatibility gates remain open.

### 2026-10-14 — shorten validation loop and reconcile current checkpoint

- Exact repository commit `40ca82e5065456b1ab98f675963682bf846da9a4` passed serial macOS Swift CI run [38452464811](https://github.com/AffPapa/NeTelegram/actions/runs/38452464811): 151/151 tests, 47-second job. Dedicated metadata validation run [38452464851](https://github.com/AffPapa/NeTelegram/actions/runs/38452464851) passed. The pinned TDLib/arm64 Dev.app workflow [38451242039](https://github.com/AffPapa/NeTelegram/actions/runs/38451242039) passed accountless close/reopen/quit smoke for app source `4e96a1556e6cd5f74d0cabeb651e21fa64793b51`.
- CI now runs Swift tests only when application, tests, package, dependency pin, or CI workflow inputs change. JSON checkpoint edits use a separate lightweight validator. The 47-second hosted suite and prior 1.27-second local suite do not justify adding SwiftPM cache complexity; the existing TDLib dependency cache remains for native app assembly. Tests stay serial because prior parallel execution stranded a cancellation-sensitive test.
- Reconciled `PROJECT-STATE.json` and `ACCEPTANCE.json` to Site v150, app source `4e96a155`, repository evidence baseline `40ca82e`, and the current passing workflows. This is documentation/checkpoint work; no Site publish or app release was appropriate. Real account, 20-runtime, signing/notarization, and Telegram compatibility evidence remains open.

### 2026-10-14 — narrow AUTH03 to evidence still missing

- Static review of app source `4e96a1556e6cd5f74d0cabeb651e21fa64793b51` confirms a 900×700 minimum window, a 568 px maximum auth card and 360 px inputs. The constraints fit at the declared minimum width; this does not establish visual quality or height behavior.
- Exact-source pinned Dev.app run `38451242039` published a review artifact containing the native first-run image. The image has not yet been visually inspected. Code/2FA/QR/registration screen layouts and accessibility remain unverified; AUTH03 stays partial. Next action is to inspect the artifact and make only screenshot-backed layout changes.

### 2026-10-14 — make Telegram ecosystem disclosure explicit in sign-in

- Rechecked current primary Telegram API Terms and pinned TDLib 1.8.68 schema. Terms §2.2 calls for prominent notice that the client uses Telegram API and is part of the Telegram ecosystem. The sign-in intro now says both explicitly while preserving NeTelegram's independent/no-affiliation disclosure.
- The exact pinned TDLib schema contains sponsored channel messages with `messageVideo` plus timed video-message advertisement APIs. User previously declined a video player; channel access/stable release therefore remains deferred. Terms §§1.3/1.4 do not enumerate a minimum feature checklist in the primary page, so this compatibility review remains open.
- Exact-source local AppKit/Core build passed on Xcode 27 / Swift 6.4 in 5.69 seconds. No account or keychain data was accessed. CI and pinned Dev.app smoke are pending for the changed source.

### 2026-10-14 — verify ecosystem disclosure change on exact source

- App source `78d96212b45df18f5a5aea206a467ff397d273b4` makes the sign-in intro explicitly say the client uses Telegram API/TDLib and belongs to the Telegram ecosystem, while retaining the independent/no-affiliation statement. Local Xcode 27 / Swift 6.4 AppKit/Core build passed in 5.69 seconds.
- Exact-source hosted serial CI [38453959840](https://github.com/AffPapa/NeTelegram/actions/runs/38453959840) passed all 151 tests in 53 seconds on macOS 15 / Xcode 16.4 / Swift 6.1.2. Metadata validation [38453959743](https://github.com/AffPapa/NeTelegram/actions/runs/38453959743) passed. Pinned TDLib/arm64 Dev.app workflow [38453959931](https://github.com/AffPapa/NeTelegram/actions/runs/38453959931) passed bundle verification, accountless first-run capture, last-window close, LaunchServices reopen/same PID and normal quit.
- Current official Terms and pinned TDLib v1.8.68 schema were reviewed. The sign-in disclosure now covers API use and ecosystem membership. Terms §2.3 title conflict, sponsored-video requirement for channels, and basic-functionality review remain open; no compatibility or stable-release pass is claimed. No real accounts, Site, or release assets changed.

### 2026-10-14 — report explicit photo opens to TDLib

- The exact pinned TDLib 1.8.68 schema says `openMessageContent` informs TDLib when a user opens photo/video/document/location content and may generate `updateMessageContentOpened` (pinned schema, lines 11812–11816; https://raw.githubusercontent.com/tdlib/td/c15d3f5a5de6e3ba5839822c451152e5e18bb700/td/generate/scheme/td_api.tl). The NeTelegram photo viewer previously displayed an opened full-size image without sending that request.
- The viewer now sends the request after ImageIO decoding succeeds and the viewer is shown, through `PrivacyDispatchBarrier` bound to account, server identity, runtime generation and privacy epoch. This does not mark inline thumbnails as opened and does not claim real-account behavior.
- Final local serial `swift test --no-parallel` passed 151/151 on Xcode 27 / Swift 6.4 (build 5.33 seconds, tests 0.207 seconds). Hosted CI and pinned Dev.app checks are pending for the changed source. APP20 remains partial until native/account-backed photo flows and memory pressure are verified.


### 2026-10-14 — shorten and instrument the Swift CI feedback loop

- Exact app source `55dd12b5bbcfab871df3473dba0d9e5a03b51814` is pushed to `AffPapa/NeTelegram`. Local serial Swift suite passed 151/151 (build 5.33 seconds; test execution 0.207 seconds). Exact-source pinned TDLib/arm64 Dev.app workflow [38454870134](https://github.com/AffPapa/NeTelegram/actions/runs/38454870134) and metadata workflow [38454869806](https://github.com/AffPapa/NeTelegram/actions/runs/38454869806) passed.
- Exact-source macOS CI [38454870102](https://github.com/AffPapa/NeTelegram/actions/runs/38454870102) compiled and linked the test bundle in 40.26 seconds, then emitted no test-start output for about 9m23s and was cancelled at the 10-minute limit. This establishes a runner stall after build/link and before visible test output; it does not identify a failing test or prove a product defect. A prior 151/151 hosted pass was for SHA `78d9621`, not this source SHA.
- GitHub's connected Actions integration returned 403 for a same-job rerun, so no retry or new credential was attempted. CI now keeps the serial suite, enables verbose driver output to expose the test-runner handoff, and caps silent stalls at five minutes. `DEV-WORKFLOW.md` records one-checkout/one-candidate cadence and which workflow applies to source, metadata, native bundle, and release changes. Hosted confirmation for this workflow adjustment remains pending. Local rerun of the new `--verbose` command could not proceed: SwiftPM manifest compilation hit the managed `sandbox-exec: sandbox_apply: Operation not permitted` restriction even with its scratch/module caches under `/private/tmp`; this is an environment block, not a Swift test result.
- No app release or Site deployment occurred. Account-backed login, all-20 runtime certification, Developer ID/notarization, and Telegram compatibility gates remain open.


### 2026-10-14 — confirm fast CI diagnostics on the exact candidate

- Workflow/checkpoint commit `fa021866d59db2f797fea5c49eab7f4798c95f2c` passed macOS CI [38456932580](https://github.com/AffPapa/NeTelegram/actions/runs/38456932580) for app-source `55dd12b5bbcfab871df3473dba0d9e5a03b51814`. `swift test --no-parallel --verbose` reported all 151 tests passed in 0.486 seconds after build; the complete hosted job took about 59 seconds.
- This confirms the verbose command and serial suite. It does not retroactively turn prior cancelled run 38454870102 into a pass; that run stalled before visible test output. The new log boundary makes future runner-startup stalls diagnosable, and the five-minute limit bounds that wait.
- Exact app-source local suite remains 151/151 (5.33-second build, 0.207-second test execution); exact-source native TDLib/Dev.app smoke 38454870134 and metadata validation 38454869806 passed. No Site, app release, or Telegram account state changed.


### 2026-10-14 — validate the updated project checkpoint

- Metadata-only validation [38457141078](https://github.com/AffPapa/NeTelegram/actions/runs/38457141078) passed for checkpoint commit `cd1fbe457ad8c14884bd781b84ef2ac007b88909`. It does not rerun the Swift suite; exact-source Swift PASS remains run 38456932580.


### 2026-10-14 — verify sign-in disclosure on one exact candidate

- Canonical checkout `/private/tmp/netelegram-cli-work`, `main`, source `6145b0156068f784e1eea3bf70df77a8b834bf83`, clean and equal to `origin/main`. Local AppKit/Core build passed in 5.27 seconds; serial suite passed 151/151 (0.202 seconds) on Xcode 27 / Swift 6.4.
- Pinned TDLib/arm64 Dev.app run [38457814416](https://github.com/AffPapa/NeTelegram/actions/runs/38457814416) passed exact-source bundle verification, first-run capture, window close/reopen in the same PID, and normal quit. Screenshot review confirms the phone-entry card and API/TDLib + non-affiliation disclosure; the line is small/low-contrast. CI has no API hash configured, so no login was attempted.
- Hosted macOS CI [38457814445](https://github.com/AffPapa/NeTelegram/actions/runs/38457814445) passed 151/151 in 0.468 seconds after a 36.31-second build (about 52 seconds total) on macOS 15 / Xcode 16.4 / Swift 6.1.2. The first attempt completed build but the Swift Testing runner stayed silent and hit its five-minute timeout; one same-SHA rerun passed. No code change or duplicate native build was used to resolve it.
- No real account, private account data, Site deployment, or app release was accessed or published. Site remains v150; real login/all-20-runtime coverage and signed distribution remain open.


### 2026-10-14 — publish the exact candidate evidence to Site v151

- Updated the existing public Site using its official source helper. Source commit `08b31c8ca6a5a0c1957fa268abeba9b1c2366a24` and saved version 151 were deployed as `appgdep_6ace8ec76e4081918ae04844ab188b40` at https://netelegram.iryadom.chatgpt.site; no new Site was created.
- The devlog links app source `6145b0156068f784e1eea3bf70df77a8b834bf83`, hosted CI [38457814445](https://github.com/AffPapa/NeTelegram/actions/runs/38457814445), and pinned TDLib/Dev.app smoke [38457814416](https://github.com/AffPapa/NeTelegram/actions/runs/38457814416); it states the 151-test pass, the same-SHA runner timeout/rerun, the accountless scope and the low-contrast disclosure observation. It does not claim a live login or release.
- Anonymous HTTPS checks returned HTTP/2 200 and `text/html` for `/devlog/` and `/downloads/`. Live content matches the source. Downloads says no verified macOS build exists and contains zero ZIP/DMG/release URLs.
- Local archive `/private/tmp/netelegram-site-v151.tar.gz`: SHA-256 `644bfe466d0557f269c645f36a0744f74bbc3f1eabb75d30775dbf999cc7d21b`, 288543 bytes. Sites saved archive receipt: `sha256:4a651fc1aa376c021101ee64ccc46ab7976fe5cd4ba20d8157d468c757dbc001`, 512000 bytes, 15 files. Checkpoint commit `3664214a842913ed03c5413a18beb39b95cc817e` passed metadata validation run 38459557354; this Site receipt is recorded in the subsequent checkpoint edit.


### 2026-10-14 — avoid rebuilding pinned TDLib for source-only edits

- Removed `Sources/**` and the workflow-file self-trigger from automatic push/PR paths for `native-app.yml`. Swift source and tests remain covered by the macOS serial CI; pinned TDLib/Dev.app still runs automatically for SwiftPM, TDLib lock and native build/lifecycle script changes, and remains available through `workflow_dispatch` for runtime integration or a frozen release candidate.
- Updated `DEV-WORKFLOW.md` to match. Ruby YAML parse and `git diff --check` passed. No app code changed; no application build or test suite was repeated for this trigger/documentation-only change. The prior exact-source native run 38457814416 remains valid for app source 6145b015.

### 2026-10-14 — improve sign-in disclosure readability

- Source commit `2cd13c2bd97431ab4e6f7f0b03fa9a6e5f2cfbb` changes only the sign-in disclosure from 11 pt tertiary-label gray to 12 pt secondary-label gray. Copy, auth behavior, profile catalogue and account state are unchanged.
- Exact source-tree fingerprint `3038c01c875af925bdf39eb7134cdd3f861bd14597d53c1138a7ecfdf0f51e1c`; canonical arm64 Dev.app executable SHA-256 `2ba1f7c3adc0d9214b3fa62051959e38f84849058a4c173ed2c00676ead52259`; pinned TDLib JSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. The app was built with ad-hoc development signing only.
- Local `swift test --no-parallel` passed 151/151 on Xcode 27.0 / Swift 6.4 (5.30 s build, 0.203 s test execution). Managed sandbox rejected SwiftPM module-cache sandbox setup even with caches under `/private/tmp`; one reviewed escalation allowed the exact test command to run. This was an environment permission boundary, not a product test failure.
- One canonical Dev.app ran with isolated empty support root `/private/tmp/netelegram-auth-ui-support`. Accessibility inspection confirmed the normal phone-entry form and no profile picker. Screenshot `/private/tmp/netelegram-auth-ui.png`, SHA-256 `f3a8b27087f3b559168352debee1e97a4a122d03d1be1cb635d3f38def84c36c`, visually reviewed with no clipping and clearer disclosure. No login credentials or account data were used. Lifecycle close/reopen was not repeated for this UI-only edit.
- Exact-source hosted CI, metadata validation and public Site devlog sync are pending. No app release or download link exists. Real login, all-20 certification, Developer ID/notarization and Telegram compatibility gates remain open.

### 2026-10-14 — publish current sign-in verification and Site v152

- App source `2cd13c2bd97431ab4e6f7f0b03fa9a6e5f2cfbb` and checkpoint commit `0c8ee8358e8fe7d5e79204336ccc0c6a9e387f7a` were pushed to `AffPapa/NeTelegram` through Git. Exact-source macOS CI [38461168203](https://github.com/AffPapa/NeTelegram/actions/runs/38461168203) passed; the run log reports all 151 tests passed in 0.620 s. Metadata validation [38461168216](https://github.com/AffPapa/NeTelegram/actions/runs/38461168216) passed for checkpoint `0c8ee83`. Neither run was manually duplicated.
- Existing public OpenAI Site project `appgprj_6acba85192e08191acdf7011928848cf` was updated through its official source helper. Site source `e671ff012964561583051b18772ddbae0d34f409` was saved as version 152 and deployed as `appgdep_6ace91b5ca288191bd66fe1f88c5f08b` at https://netelegram.iryadom.chatgpt.site. The audience remains public.
- Site archive `/private/tmp/netelegram-site-v152.tar.gz`: SHA-256 `90a5e6a35fdf21a4e180fc046504464108d3a8268715954f8596fd148be693ae`, 288544 bytes. Sites receipt: `sha256:2758ac725793abf912182785aa5cd48110e70432c6c819f4b600114d396d0786`, 512000 bytes, 15 files.
- Anonymous system `curl` verified `/devlog/` and `/downloads/` as HTTP/2 200, `text/html`. Devlog contains app source `2cd13c2`, CI run `38461168203`, metadata run `38461168216`, and the accountless test scope. Downloads still have zero ZIP/DMG links and state that no verified app build is available.
- A Python HTTPS probe failed TLS certificate validation because its local CA bundle could not build a trust chain; standard system `curl` verified the same public routes with normal certificate validation. No TLS bypass was used.
- No app release, release asset or user account changed. Real login/all-20 coverage, Developer ID/notarization, updater, and Telegram API compatibility remain open.

### 2026-10-14 — remove stale evidence pointers from the checkpoint

- Consolidated evidence labels after review: pinned native workflow `38457814416` is now explicitly a historical baseline for app source `6145b015`, while the current source `2cd13c2` has separate accountless local Dev.app UI evidence. No Swift tests or TDLib build were repeated.
- Current Site acceptance evidence now points to public v152/source `e671ff0` and deployment `appgdep_6ace91b5…`. Anonymous live checks cover only `/devlog/` and `/downloads/`; local static validation covers all eight routes. Other public routes/feeds were not claimed as live-checked. SITE03/04/05 remain partial because downloads, accessibility/browser coverage and signed-byte/updater coherence are incomplete.
- Removed duplicate Site archive size/hash aliases and renamed the stale top-level devlog pointer to `latest_site_source_commit`. Acceptance workflow evidence is now structured by current app-source CI, checkpoint metadata, and historical native baseline.
- This is checkpoint hygiene only. The already-passed app CI `38461168203` remains valid for unchanged app source `2cd13c2`; one metadata validation will run for this consolidated JSON, with no source or package rebuild.

### 2026-10-14 — reconcile the current checkpoint and stop stale-version loops

- Resume audit found `PROJECT-STATE.json` still pointed its repo HEAD and native candidate to mixed historical labels, while the latest metadata run for `f99ce19` had already completed. Reconciled app-source SHA (`2cd13c2`), repository checkpoint HEAD (`f99ce19`), Site-source/version/deployment, metadata receipt, and historical local Dev.app evidence as distinct identities.
- Marked the captured local bundle historical because its process state was not re-queried; it is no longer described as the current running app. Corrected the prior Site receipt's `app_repository_commit` to the app source SHA mirrored by the Site.
- Updated the single next action: investigate pre-account country selection without creating an account/runtime just to fetch a list; retain explicit international-number input as the existing fallback. No product code, app build, Swift tests, Site deploy, account data, or release assets changed.
- Local metadata-equivalent JSON validation and `git diff --check` passed. GitHub API was unreachable on this resume, so metadata run `38462120071` is carried forward from the immediately preceding workflow receipt; this checkpoint-only change will receive the normal metadata workflow after push. No app test or native workflow is needed.

- Push of checkpoint `2e27871ce636639873de1c9769b26c2a7ce1229a` to `origin/main` succeeded. The expected metadata-only workflow [38462809234](https://github.com/AffPapa/NeTelegram/actions/runs/38462809234) completed successfully for that exact commit. No app-source workflow, Swift suite, TDLib build, Site deployment, or release was triggered. This is the current metadata receipt and supersedes the previous pending note.

### 2026-10-14 — first-run country selection slice

- Added a pre-account country selector backed by 245 region/calling-code pairs derived from Google libphonenumber v9.0.41 at pinned commit `b68df884d42d5e9860fc1956a99ce6afae361100`. Source XML and license SHA-256 values match `COUNTRY-DATA.lock.json`; the generator reproduced the checked-in Swift catalog byte-for-byte. Apache-2.0 attribution/license are retained.
- The macOS locale only suggests a region when that region exists in the catalog. No implicit `+1` is selected. International numbers with `+` are accepted without selecting a country; national-format numbers require an explicit calling code. Country data is bundled, so first-run UI does not create a TDLib runtime/profile just to fetch the list. Existing TDLib country data can replace the local list after a profile runtime exists.
- Local serial `swift test --no-parallel` passed 152/152 on Xcode 27.0 / Swift 6.4 (4.88-second build; 0.200-second test execution). JSON parsing, lock hash checks, deterministic generator comparison, and `git diff --check` passed.
- Native UI smoke of this candidate was not run. The old canonical Dev.app stayed open after a graceful Cmd+Q attempt and the launcher refused replacement; no forced process termination or second app bundle was used. Hosted exact-source and metadata CI are pending the candidate push. Site remains public v152 and still describes the previous milestone; no app release/downloads were added.
- No real login, account/profile data, installed Telegram data, signing identity, or release credentials were accessed. Real login, server-list reconciliation, all-20-runtime coverage, signed/notarized release, updater, and API compatibility gates remain open.

### 2026-10-14 — publish country-selection milestone and record hosted CI timeout

- Source commit `be58d831aaa1d53c3d47e1313758feb7f9e32384` and checkpoint commit `1ff4cf578e634623bbcdd5d876041f100f9290f0` were pushed to `AffPapa/NeTelegram`. The pre-push fetch confirmed origin/main was the prior ancestor, so this was a fast-forward with no remote changes overwritten.
- Exact checkpoint metadata validation [38464148278](https://github.com/AffPapa/NeTelegram/actions/runs/38464148278) passed. Hosted macOS CI [38464148650](https://github.com/AffPapa/NeTelegram/actions/runs/38464148650) completed its build step but the test step was cancelled at the five-minute workflow timeout. Local serial suite passed 152/152. The GitHub connector denied a same-run retry with HTTP 403 `Resource not accessible by integration`; job logs were unavailable through the connector. Hosted PASS is not claimed.
- Existing public Site v153 was deployed from source `7790a235a570dd9923c58be9b714af91585732ab` as deployment `appgdep_6ace9871f63c819180a67d58b1591c98`. It adds bilingual factual notes about the first-run country picker and the hosted timeout. Anonymous checks found `/devlog/` and `/downloads/` at HTTP/2 200 `text/html`; the downloads page still has no app binary links.
- Site archive `/private/tmp/netelegram-site-v153.tar`: local SHA-256 `a882fb669d8b8dae055018589dd826753a11c0141a51c8235ba298391bdcb064`, 289466 bytes. Sites stored receipt `sha256:32919270e3e8acd907b89f912b17492587827f4f85e9dff0bc500dcebf469c08`, 522240 bytes, 15 files.
- No current-candidate Dev.app GUI smoke, real Telegram login, account data, app release, or downloads. Existing old bundle was not force-terminated or replaced. Next: diagnose the hosted runner timeout and use only an authorized Actions retry route; then perform one canonical accountless UI smoke after safely quitting the old bundle.

### 2026-10-14 — show first-run phone UI before API hash lookup

- A native Dev.app smoke after the country-catalog milestone exposed a startup ordering issue: on an empty profile catalogue, `restoreProfiles()` attempted Keychain API-hash lookup before it called `showPhoneEntry()`. The form could remain at “Подключаю экран входа…” while that asynchronous lookup ran or failed. The code now shows the bundled country selector and phone form as soon as the empty catalogue is confirmed; only explicit Continue/QR proceeds to `addAccountProfile()`, which still requires the API hash before creating a profile.
- App source commits `74265a3525d0ba4351c89e57ea63dafbc0802804` and `94740d38bfa845919ac2863ad0e78d1a7d494a04` are on `main`; the latter only changes the first-run status copy to remain neutral until the credential check happens.
- Exact-source canonical Dev.app for 94740d3 built in 9.12 seconds on arm64 / Swift 6.4; ad-hoc nested codesign verification passed. Fresh AX and screenshot inspection show Thailand +66 as a locale suggestion, phone field, Continue and QR. Status is “Выберите страну и введите номер телефона.” No phone, OTP, account, profile or session was entered or created. Bundle fingerprint `e79a341bdfc0c7cd1c7da64c68b0a42112af892000c42c01bac16fed836d32b6`; executable SHA-256 `af309b5551f57682e86d8a521da99ae97f04606fbfc17d4df5d10cd101fc2a31`; bundle `/private/tmp/NeTelegram-Dev.app`; isolated support root `/private/tmp/netelegram-first-run-smoke-94740d3`.
- The serial core suite passed 152/152 for preceding source be58d83, before this AppKit-only startup-order change. A current-source `swift test` run compiled the app in 5.14s but emitted no test result for over a minute; it was interrupted, so it is not a PASS. Automatic exact-source macOS CI run [38466197778](https://github.com/AffPapa/NeTelegram/actions/runs/38466197778) is pending. Earlier run [38464148650](https://github.com/AffPapa/NeTelegram/actions/runs/38464148650) on be58d83 was cancelled at its five-minute workflow timeout; the GitHub connector denied retry with 403.
- Public Site v153 still refers to be58d83 and says the updated UI was not visually checked. Update the existing public Site once after CI status resolves; no app release/downloads are available.

### 2026-10-14 — publish current first-run UI smoke as Site v154

- Existing public Site project `appgprj_6acba85192e08191acdf7011928848cf` remains public at https://netelegram.iryadom.chatgpt.site. Site v154 source `6242beb8ecd26008e235b46b7f922c37010b14b2` deployed as `appgdep_6ace9add32348191ad8bf25dc41140bf`; saved version ID `appgprj_6acba85192e08191acdf7011928848cf~appgver_0e843b0b1ca08191a89301eb4a734108`.
- The bilingual devlog reports exact app source 94740d3, the first-run country UI visible in a current-source Dev.app, prior-source 152/152 suite coverage, current test-runner interruption and current hosted CI still in progress. It makes no current-source test PASS claim. Downloads remains without app URLs.
- Anonymous HTTPS checks: `/devlog/` and `/downloads/` both returned HTTP/2 200 and `text/html`; live content assertions passed. Site archive `/private/tmp/netelegram-site-v154.tar`: local SHA-256 `a9f68baeb47fbb9d59f9e06d86917d1a2084919329fc2e7da5c28c8b61c77836`, 290346 bytes; Sites archive receipt `sha256:4c62478ca725e7d990ef4829ba912136ca34990d0c4236197532f900434390e2`, 522240 bytes, 15 files.
- Current exact-source macOS CI run [38466197778](https://github.com/AffPapa/NeTelegram/actions/runs/38466197778) was in progress at publication time. Metadata run [38466400353](https://github.com/AffPapa/NeTelegram/actions/runs/38466400353) is queued for checkpoint d2df61b. No app release/downloads, real login, or account data.


### 2026-10-14 — reconcile test status and remove stale-version loops

- Rechecked GitHub run 38466197778 against exact app-source SHA 94740d38bfa845919ac2863ad0e78d1a7d494a04: macOS CI ended `cancelled` at the five-minute timeout during `swift test --no-parallel --verbose`. No failed assertion surfaced and no test result was produced; current-source suite is not PASS. Metadata validation 38466847617 passed for checkpoint 4d9989c.
- Reconciled the top-level acceptance summary to app source 94740d3, prior-source-only 152/152 coverage (be58d83), Site v154 and the terminal CI result. The existing `last_verification` and PROJECT-STATE already had the correct current source, but ACCEPTANCE top-level still said 2cd13c2, 151/151 and Site v152.
- Read-only Site QA found stale homepage/features cards still linking run 38447978740 and claiming 151 tests. One corrective Site publication is being prepared; no app rebuild or test rerun is needed for these metadata/content changes.
- Fast path from here: diagnose why the serial test runner stalls before retrying once; choose the next independent production-wiring slice after that. Real login remains user-deferred. No account/session data or credentials accessed.


- Publication update: checkpoint reconciliation commit `6ee3a837aba4e737d84443b5a3dc61ca9bef6c69` is local and unpushed. `git push origin main` failed before transport because DNS could not resolve `github.com`; no retry was made. Existing Sites source checkout `/private/tmp/netelegram-site-source` has a prepared homepage/features/devlog correction (all eight static routes validate); the official helper failed before commit/push because DNS could not resolve `git.chatgpt-team.site`. No Site version was saved or deployed. Both DNS checks failed at `curl` resolution; no fallback endpoint/token route was attempted. Resume by checking DNS once, then push the exact checkpoint and use the official Site helper once.


### 2026-10-14 — isolate the silent CI runner with two focused tests

- Downloaded job logs for exact-source macOS run 38466197778. Xcode 16.4 / Swift 6.1.2 compiled and linked the test bundle in 47.20s; the job log then shows no test completion output before `The operation was canceled` at 20:58:21Z. GitHub cleanup terminated orphan `swiftpm-testing`. The job's configured timeout is five minutes; the log does not identify the cancellation initiator, so cause is recorded as unknown rather than asserted.
- Built current source 94740d3 locally with Xcode 27 / Swift 6.4 in 5.38s and ran only two filtered tests: `cancelledQueuedStartupDoesNotRunAfterItsPermitBecomesAvailable` passed in 0.002s; `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges` passed in 0.001s. These are synthetic Core tests; they do not invoke AppDelegate restoration or real TDLib accounts. No full suite PASS is claimed.
- Initial targeted launch under the default sandbox failed before the test runner because `sandbox-exec` was denied; the authorized host execution completed the two focused commands. No app source changed and no full-suite retry was made.
- DNS still fails for `github.com` and `git.chatgpt-team.site`. The app checkpoint is local/ahead and the Site homepage/features/devlog edits remain uncommitted locally; no external source push, Site version save, or deployment occurred.


### 2026-10-14 — make account startup queue failures visible

- `AccountRestorePlanner.enqueueStartupProfiles` now returns queued and rejected account UUIDs. `AppDelegate` records rejected starts as per-profile failures and keeps the other eligible profiles running; status text reports partial queue rejection instead of implying all were restored.
- Added a 20-candidate regression test: 17 accepted, one explicitly rejected, one already-running and one already-starting are accounted for, and the last candidate remains queued.
- Exact app-source commit: `4d6820da73f2790c73a35177b8f9c1d1ecf8685c`. Focused serial `swift test` on Xcode 27 / Swift 6.4 built in 18.37s; both `restoreEnqueueReportsOneRejectedProfileWithoutDroppingOtherEligibleProfiles` and `startupDispatchQueuesAllFreeProfilesWhileFirstStartupIsStalled` passed (0.001s each). These synthetic Core checks do not prove real TDLib accounts or 20-account lifecycle. The full suite was not run.
- `git diff --check` and JSON parsing passed for the reconciled checkpoint. Fresh DNS checks still fail for `github.com`, `netelegram.iryadom.chatgpt.site`, and the Sites helper host. `gh auth status` reports its stored tokens invalid; no new credential was created. App source and checkpoint remain local; public Site v154 remains unchanged.
- Efficient next sequence: one DNS recheck; once available, push source + checkpoint once and wait for exact-source CI once; then publish the already-prepared Site correction once through the official helper. Do not repeat these focused tests unchanged or build an app bundle for Site-only copy.


### 2026-10-14 — full serial suite confirms startup rejection slice

- Current app-source commit `4d6820da73f2790c73a35177b8f9c1d1ecf8685c` passed the complete serial Swift suite: 153/153 on Xcode 27.0 / Swift 6.4 / arm64 / macOS 27 SDK. With the test bundle warm, build took 0.23s and test execution took 0.200s. The run includes both startup queue tests; no real Telegram account or TDLib session was used.
- Exact command: `CLANG_MODULE_CACHE_PATH=/private/tmp/netelegram-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/netelegram-swift-module-cache swift test --no-parallel --jobs 2 --scratch-path /private/tmp/netelegram-fast-validation --verbose`. The sandbox denied SwiftPM manifest setup; the same selected host execution then completed successfully.
- This establishes a local full-suite PASS for this source, not a hosted CI PASS. Exact-source CI has not run because the source is still unpushed. Parent-source CI 38466197778 (94740d3) remains cancelled in runner phase with initiator unknown.
- Site homepage/features/devlog were updated locally to source 4d6820d and exact coverage; static validation passes all 8 routes. Sites confirms the existing public deployment remains v154. No app binaries or downloads.
- External checks still show DNS failure for github.com; do one DNS/remote check on resume, then push source + checkpoint once, let CI/metadata run together, and publish the prepared Site once after the hosted result. Do not repeat 153/153 unchanged.


### 2026-10-14 — exact app CI and public Site v156 reconciled

- Verified canonical app repo `/private/tmp/netelegram-cli-work`, branch `main`, clean before publication; live `origin/main` was `4d9989c04f07875dbed7218c77c33b60a1f5e1c6`. Existing Git transport pushed the three reviewed commits fast-forward to checkpoint `c9dd915e5e79dd9027db568c68c8a2e3283950e5`; no token creation or auth login.
- GitHub macOS CI `38469520583` and metadata validation `38469520931` both completed successfully on the checkpoint; product app-source remains `4d6820da73f2790c73a35177b8f9c1d1ecf8685c`. Local full serial suite remains 153/153 on Xcode 27 / Swift 6.4; tests were not repeated unchanged.
- Official Sites helper initially failed inside sandbox on DNS for `git.chatgpt-team.site`; same helper succeeded through approved host network using credential only over hidden stdin. No Site origin was replaced and no token was printed. Site source `7590ad7` saved/deployed as v155, then anonymous QA found that the intended new devlog marker had not landed. Corrected the source and published v156 from `5e9651446a4bfbae4bd3bc0f086c9d481f9560d5` (deployment `appgdep_6acea15c55f881918a6f848cac79f7a6`).
- Public v156 checks: `/`, `/features/`, `/devlog/`, `/downloads/` each returned HTTP 200 `text/html`; current CI/source markers pass, and downloads contains no installer links. Local v156 archive SHA-256 `0c473115004e34a4119b8d9eae36a295e08c571a78ae0465131f0d095e3e1fab`; Sites archive receipt `sha256:f96442371e6bf138335de9f090bcec6cdf07b4e6a225ebfdb7f000cd13de79ac`.
- No app bundle was rebuilt or launched. No real Telegram account was entered. All-20 runtime, current-source native GUI smoke, Developer ID/notarization, updater and compatibility gates remain open; no binary release/download is claimed.


### 2026-10-14 — current-source accountless Dev.app smoke

- Canonical `Scripts/dev-app.sh --launch` passed its process guard and built `org.affpapa.netelegram.dev` from clean HEAD `c028bd3859d76b6abf31634a4bb62f071d5e9f57` in 9.05s; nested ad-hoc codesign verification passed. arm64, minimum macOS 14.0; isolated support root `/private/tmp/netelegram-c028-dev-support`.
- Bundle source fingerprint `d4a02f5339d4d87b9f79ab6d4df9f9ca56639e6f09366e3520e1afc66c9586d8`; executable SHA-256 `e9a30f6e2413e2b2cbc163ce3f5ce82462c431a546e258e7b513a9843bf2fa35`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- Accessibility smoke: country/phone form, locale-suggested Thailand +66, neutral status, Continue and QR visible. No phone, OTP, profile or Telegram session entered. Native Dev.app remains open. This is not a release signature/notarization check.
- Metadata validation `38470536609` passed for c028bd3. No app-source changes since 4d6820d; 153/153 local suite and macOS CI `38469520583` remain the current app-source test evidence.


### 2026-10-14 — current-source smoke published to Site v157

- Site homepage/features/devlog now report canonical Dev.app smoke from clean app checkpoint `c028bd3`, not only historical parent `94740d3`. The status remains accountless, ad-hoc development signed, and not a release.
- Official Sites helper source commit `3c14efda4c204c0bb3ca57a95aca0b2b8f27b751`; saved version 157 `appgprj_6acba85192e08191acdf7011928848cf~appgver_68bbface67388191aa283ec451dcb128`; deployment `appgdep_6acea2b8963481919ba43b8a1b5c0dfa6` succeeded on the existing public Site `https://netelegram.iryadom.chatgpt.site`. No Site project/origin changes.
- Archive SHA-256 local `458456229885704413ba63fbe22b7f6baaa9415fe184a00f66875af8f8274cb5`; Sites archive receipt `sha256:f4237d5da1dc9a5dc55be20b61c0ca8acb672bf9c1fe42c8620f9aff52c55eef`, 532480 bytes/15 files.
- Anonymous public checks after v157: `/`, `/features/`, `/devlog/`, `/downloads/` each HTTP 200 `text/html`; current-source/CI markers passed; downloads has no installer links.
- App source unchanged. Local suite 153/153 and hosted macOS CI 38469520583 remain valid; current-source Dev.app c028bd3 AX smoke passed with no phone/code/profile/session. No real login or 20-runtime certification.


### 2026-10-14 — native workflow trigger accuracy and faster verification policy

- Review found the native workflow filters used lowercase `scripts/...`, while the tracked native inputs are under case-sensitive `Scripts/...`. Corrected both push and pull-request filters, and added the workflow file itself so future trigger edits receive the native bundle check.
- Kept source-only Swift edits off the expensive pinned-TDLib workflow: `ci.yml` already runs the serial macOS tests for `Sources/**` and `Tests/**`; dispatch the native workflow only for TDLib/runtime integration, native packaging inputs, or a frozen candidate. This preserves fast iteration without dropping source test coverage.
- Local validation passed: Ruby YAML parse; case-sensitive existence and inclusion of each native script in both filters; `git diff --check`. No Swift code changed, so the 153/153 suite was not repeated.
- Current Dev.app lifecycle script was not claimed as a pass: the shell process/LaunchServices route could not control the already-running app (`pgrep` reports sysmond unavailable; `open -n` returns `kLSNoExecutableErr`). CUA independently confirms the existing canonical c028bd3 window is running on the accountless phone form. No replacement instance, profile, or login data was created.

## 2026-10-14 — Privacy Lock notification-cache redaction

- App-source commit `be4707d2876c183fa5760f7264ee0fd51c740461` redacts plaintext previews already held in the app's notification route cache on lock, clears the pending locked-notification handoff, and avoids copying preview text from notifications arriving while locked. Exact account/chat/topic/message routing is preserved.
- Focused local privacy tests passed 2/2. Exact-SHA [GitHub macOS CI run 38473154528](https://github.com/AffPapa/NeTelegram/actions/runs/38473154528) passed the complete Apple Silicon serial suite, 155/155 (41 seconds).
- A local full-suite attempt stalled in the existing blocked-receive drain test; it was interrupted and is not counted as a local PASS. The exact-source hosted full suite passed. No duplicate run was launched.
- Synthetic route/cache evidence only. Native Notification Center behavior, secure RAM erasure, late image/picker callbacks and real-account send races remain unverified. No Dev.app build, login, release asset, or Site update was made.

## 2026-10-14 — Public devlog v158 synced to privacy-cache milestone

- Existing public Site/project retained: `appgprj_6acba85192e08191acdf7011928848cf`; source commit `02a5dbdde3d877e3791397b392c183453b03fa50`; saved version 158 `appgprj_6acba85192e08191acdf7011928848cf~appgver_042a2e3e757881919cdfd4e1ba0d6c2b`; deployment `appgdep_6acea846c16c8191b1db071a9eb334c0` succeeded at https://netelegram.iryadom.chatgpt.site.
- Site archive SHA-256 `320c16dc1960daacfb27f16c9488c236e59d33db99c527e658fbdc09a95929fc`; Sites-reported archive hash `sha256:7ee8dcf223331b8ae32405033935c0b72509235434276cf13699b98ef6eda36b`.
- Static build and focused validation passed for all eight routes. Anonymous HTTPS checks returned 200 `text/html` for `/`, `/features/`, `/devlog/`, and `/downloads/`; the devlog contains app-source `be4707d` and CI `38473154528`. Downloads still has no installer links.
- Site source uses its own Sites checkout/remote; the NeTelegram app origin was not changed. No app binary was built or published.

## 2026-10-14 — One canonical current-source Dev.app build and login smoke

- Gracefully quit the one old accountless `org.affpapa.netelegram.dev` process (source c028bd3), confirmed its PID exited, and rebuilt the same canonical `/private/tmp/NeTelegram-Dev.app` once from clean checkpoint `e7ee13a87275140615da8328244964b1b5faad48`. Build completed in 9.20s on arm64 / Swift 6.4; nested ad-hoc `codesign --verify --deep --strict` passed. Source fingerprint `0d26a0d079dc72136b29f31f72079329c73238c488c315fae493434e0bdabca0`; executable SHA-256 `580aa2cec16857a043381660bd331424129f8b9cb880b476cf55ad36ffb613a5`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- AX confirms the single running window is titled `NeTelegram · dev e7ee13a8`, with welcome text, phone field, Continue, and QR; no UUID profile is visible. No phone, OTP or account data was entered.
- Smoke is partial: after at least five seconds the status remains `Подключаю экран входа…`. A one-second process sample observed `restoreProfiles` awaiting Security `SecItemCopyMatching` on a utility task while AppKit's main thread was idle. The cause of the Keychain wait is not yet diagnosed. This is not an auth PASS and no API hash was reused.

### 2026-10-14 — isolate Security calls from Swift executor and diagnose test stall

- On the canonical repo `AffPapa/NeTelegram`, source commit `1de572048aec9ecb6fa04f2f7c6ed786473888df` changes Security reads to use a dedicated serial DispatchQueue and adds `LAContext.interactionNotAllowed = true`; AppKit reports the Keychain restore state and fail-closed errors without resetting catalogue/key data. The same change replaces detached Security work in logout cleanup.
- A first focused local test invocation built but hung. Diagnosis found a test-only deadlock: the test awaited the Keychain operation before its `defer` could signal the semaphore releasing that operation. The signal is now sent before awaiting completion. Focused tests `secretsStoreReadQueryDisallowsImplicitKeychainAuthenticationUI`, `keychainReadsRunOutsideTheMainThread`, and `blockedKeychainOperationDoesNotBlockSwiftCooperativeTasks` passed 3/3 locally; `git diff --check` passed.
- Exact-source GitHub macOS CI [38475546446](https://github.com/AffPapa/NeTelegram/actions/runs/38475546446) passed 157/157 on macos-15 arm64 / Xcode 16.4 / Swift 6.1.2. The commit was pushed using the existing Git credential helper; no new credential or login was used. Default sandbox DNS failed once; the same `git push origin main` succeeded on the approved host-network retry.
- After confirming the old accountless process had exited, rebuilt and launched exactly one canonical `/private/tmp/NeTelegram-Dev.app` from the clean commit in 9.26s. Build fingerprint `be0f24718ae00fd4bc95d5a08a0c845dfc60d5b39cc1a210514f79ff911e23e3`; executable SHA-256 `0bdc4bbf9effd0ddb374fbc9f6b9ddc3628333e0e4ecc4fb2f9845ea8eb7b40a`; pinned TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; ad-hoc nested code verification passed. Accessibility shows the phone form/Continue/QR and the new explicit status “Проверяю доступ к Связке ключей macOS для восстановления сохранённых профилей…”. It remains there after >20 seconds; this is partial, not startup PASS. No phone/code entered. The app support root was preserved and not inspected or reset.
- Remaining focused action: diagnose why the local Security call still waits and obtain either a phone-ready state or a clear Keychain failure. Never import/inspect installed Telegram sessions. Real login and twenty authorized runtimes remain untested; no Developer ID/notarization, updater, app release, or download links.

### 2026-10-14 — clean first-run smoke without touching prior app data

- Checkpoint `43980cf0f654d7d0d38c71b5ec73154871c26400` records the source/CI/Dev.app evidence and was pushed to `origin/main` by Git. Public app source remains `1de572048aec9ecb6fa04f2f7c6ed786473888df`; exact CI run 38475546446 passed 157/157.
- The earlier running Dev.app used the default `/private/tmp/netelegram-dev-support` and reached a saved-profile Keychain restore that stayed pending for >20 seconds. I did not inspect or delete that catalogue, its keys, or its files.
- After confirming that one app process exited, the same `/private/tmp/NeTelegram-Dev.app` path was rebuilt from cached clean source with fresh QA support root `/private/tmp/netelegram-first-run-1de5720-support`; build took 0.20s. This is the single currently running Dev.app, not a second app identity/version. AX verifies country selector Thailand +66, phone field, Continue, QR, neutral first-run prompt, and no UUID profile. No phone or code was entered. This proves only clean first-run presentation; account login is still deferred.
- Existing default-root Keychain restore remains unresolved. Fresh isolated first run avoids that path until explicit login, but does not diagnose or repair the prior local saved-profile state. Metadata JSON and `git diff --check` were validated locally; the metadata workflow status for checkpoint `43980cf` has not yet been confirmed through GitHub because unauthenticated Actions API rate limit is exhausted until reset.

### 2026-10-14 — publish factual clean-login milestone to the public Site

- Site project `appgprj_6acba85192e08191acdf7011928848cf`, public audience preserved. Official Sites source helper opened the existing checkout and returned source `02a5dbdde3d877e3791397b392c183453b03fa50`; only `content/devlog.html` and its generated `dist/devlog/index.html` changed.
- Site devlog records the clean isolated phone-entry smoke from app checkpoint `43980cf`, app-source `1de5720`, exact CI run `38475546446` (157/157), no real phone/code entry, and the still-unresolved Keychain restore from the old support root. It clearly states the ad-hoc Dev.app is not a user download and that there is no released binary.
- Source helper committed and pushed exact Site source `a37d2b74b9deda24ed0ee47c5459c94f871b4684`; saved public Site version 159 as `appgprj_6acba85192e08191acdf7011928848cf~appgver_601f305ae44881918025fe7bc1c16337`; production deployment `appgdep_6aceadfed7b48191bb0a6b4852fbbba3` succeeded at https://netelegram.iryadom.chatgpt.site. Local archive SHA-256 `6f357ac798e3ac65a0ea2581fe32a9b07d3a81537393c3e89f4c22de9e1f0ac4` (294,495 bytes); saved archive content hash `sha256:d9e794f34c4e272b3e14bdad76ce273abedfc7af90c74dd45edc47b65f6b8f88`.
- Anonymous HTTPS validation: all eight public routes returned HTTP 200 `text/html`; `/devlog/` contains exact source/CI/limitation markers and `/downloads/` has no installer link. The first Python TLS probe failed because the local Python cert store lacked an issuer; no TLS bypass was used. The same routes then passed through system `curl` with normal TLS verification.

### 2026-10-14 — make clean support the routine Dev.app default

- Exact app-repository checkpoint `3cba4c58555bce73802f9ff70f073fe9e5856101` changes `Scripts/dev-app.sh` and `DEV-WORKFLOW.md`: routine Dev.app builds now use `/private/tmp/netelegram-dev-support-clean`. The former `/private/tmp/netelegram-dev-support` remains preserved and is no longer selected by default. Shell syntax and whitespace checks passed.
- Exact pinned TDLib/Dev.app workflow [38477106487](https://github.com/AffPapa/NeTelegram/actions/runs/38477106487) succeeded for checkpoint `3cba4c5`: pinned arm64 app build, nested bundle validation, and last-window close / LaunchServices reopen in same PID / one-window / quit smoke passed. Hosted GUI uses its own isolated runner support path; it does not access user data.
- On the local Mac, after confirming the sole prior process exited and the new root did not exist, the same `/private/tmp/NeTelegram-Dev.app` bundle was built once with the unmodified default. Incremental build 0.22s; AX shows country +66, phone, Continue, QR, neutral status and no UUID profiles. App fingerprint `be0f24718ae00fd4bc95d5a08a0c845dfc60d5b39cc1a210514f79ff911e23e3`; executable SHA-256 `dd65910e1b02dc0ac659d2746fd2edb2239444fcd8bad35e8a7403bfd5ed680b`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. No phone or code entered; the old support folder was not inspected or changed.
- Public Site v160 deployed from Site source `cc15fded6d6a54aba81b033df930c1a405bbf6ed` as deployment `appgdep_6aceaf8916848191bdc8bc64d3243a49`; anonymous validation passed for all eight public routes and confirmed no installer link. Local archive SHA-256 `d9759d68c397adf63b7aeadb51537d2487ad0500191ecb237c015679598d2436` (295,113 bytes); saved content hash `sha256:fce37102474e27300a03b8e341a2179840dfd6d2b68786b0efbdd41274e352e7`.
- Real authentication remains deferred. The prior support-root Keychain wait and migration/recovery are unresolved; no profile keys/data were inspected or reset. All-20 real runtime coverage, Developer ID/notarization, updater and user downloads remain open.

### 2026-10-14 — checkpoint reconciliation and fast-path validation

- Reconciled the state/acceptance checkpoint to the already verified Dev.app workflow 38477106487 and public Site v160. The documentation-only checkpoint commit `07586a90cacccfd2b4ff28788691542c8f1a059d` was pushed to `AffPapa/NeTelegram` `main`; exact metadata validation run [38477842919](https://github.com/AffPapa/NeTelegram/actions/runs/38477842919) completed successfully for that SHA.
- No Swift suite, TDLib build, Dev.app rebuild, or Site deployment was repeated: no corresponding inputs changed. Local JSON parsing and `git diff --check` passed before push.
- Efficiency note: Git transport succeeded while the local `gh run list` API lookup could not resolve `api.github.com`; the connected GitHub API reader returned the exact run result. Treat Git transport and GitHub API as separate routes, switch once to an available read path, and do not repeat a failed route without a changed network condition.
- Keep one source checkout, canonical `/private/tmp/NeTelegram-Dev.app`, and isolated default support root. The next product slice should be chosen from acceptance gaps; current auth is deferred, no real Telegram accounts are in test coverage, and release prerequisites remain open.

### 2026-10-14 — clarify login disclosure and verify one source-matched UI slice

- Source change `209be94fde904d0b666ab5c28f588d78610b05bf` replaces the ambiguous “Telegram ecosystem” phrase with a factual independent-client statement naming Telegram API/TDLib, no direct relationship with Telegram Messenger LLP, and no import of sessions from other apps. Disclosure text uses 13 pt medium instead of 12 pt regular.
- Full local serial Swift suite passed 157/157 (Xcode 27.0 / Swift 6.4 / arm64e; 17.89s build, 0.212s test execution). The sandbox denied the first manifest setup before tests; the same command passed on host execution. Exact-source hosted CI is pending; earlier CI for 1de5720 does not cover this change.
- Reused the one canonical `/private/tmp/NeTelegram-Dev.app` and clean default support root. Build completed in 8.57s; ad-hoc nested code signature verified. Build source fingerprint `b954e21469bfc42bf0c98e05867f2b107857255d84b9daecda010033e35b97bc`, executable SHA-256 `f31409c71cb07c6b8568adbfbe4a444cc149475b3c6ca4918465ae2a9cb9d844`, TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. Screenshot/AX confirm revised copy, +66, phone, Continue, QR, neutral status and no profile or credentials. Bundle was built before source commit and therefore still displays parent `87c9257+dirty`; source fingerprint identifies the tested source bytes.
- Normal Quit was selected once from the app menu. The process remained live and the UI unchanged for more than two seconds. The cause is unknown; no force kill or bundle replacement was attempted. Treat local graceful-quit behavior as unresolved; investigate before the next canonical rebuild.
- Fast-path lesson: test the completed source slice once; use the canonical UI smoke only because AppKit text changed; defer Sites publication until exact-source CI, then update the existing Site once. Do not use a parent-SHA CI result as a pass for this source.

### 2026-10-14 — Site v161 records exact hosted-CI cancellation

- App source `209be94fde904d0b666ab5c28f588d78610b05bf`: local serial suite passed 157/157 and one accountless canonical Dev.app smoke showed the phone/QR entry screen. No phone or code was entered.
- Exact-source GitHub Actions run [38478591456](https://github.com/AffPapa/NeTelegram/actions/runs/38478591456) built its test package but was cancelled after five minutes during test execution. No hosted test result exists. The connected GitHub rerun operation returned 403 `Resource not accessible by integration`; no alternate credential or route was created.
- Existing public Site v161 source `69f99f815da78275650cae1324545f2e70392883`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_356c9c33a0cc8191a6fe2b322a7e83b8`, deployment `appgdep_6aceb40c64cc81918919940bc8772ca4` succeeded at https://netelegram.iryadom.chatgpt.site. Public audience and existing project retained.
- Archive SHA-256 `8472f0346a9617ea90d47731d5647fcbe6431608574676607cf5c7b3ad2a7024` (295,698 bytes); Sites archive content hash `sha256:844ed8b274bb0b37b5d74d7ee5e6c565b6a451a6399266c7a9f8052ac74e3164` (542,720 bytes, 15 files). Anonymous HTTPS validation returned 200 `text/html` for all eight routes. Devlog displays the exact cancelled CI state; downloads contains no binary link.
- Speed rule reinforced: do not rerun a full suite with unchanged source/harness after a terminal cancellation that cannot be retried through the authorized connector. Preserve the local PASS and classify hosted status separately. Next source change should run one full local suite and produce one exact-source hosted run.
- Graceful Quit remains unresolved: normal app-menu Quit left canonical Dev.app running; no force-kill or replacement. Real login remains deferred; 20-runtime, signing/notary, updater and release gates remain open.

### 2026-10-14 — clean Dev.app rebuilt and menu Quit verified; Site v162 corrected log

- Correction to the prior entry: the earlier observation that the process was still alive after menu Quit was made too soon and was not terminal evidence. On the new canonical build, selecting the NeTelegram app-menu Quit item ended the process; subsequent CUA inventory showed the app not running. No force kill. A `super+q` UI automation attempt did not close the app, so Cmd+Q remains unverified; this is not treated as a confirmed product defect.
- Canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt once from clean checkpoint `7f95e03c12457d522f2e7e50b3baa497db6e731d`; app source remains `209be94fde904d0b666ab5c28f588d78610b05bf`. Build took 0.23s, `working_tree_dirty=false`; fingerprint `b954e21469bfc42bf0c98e05867f2b107857255d84b9daecda010033e35b97bc`; executable SHA-256 `5ab67ec7a147680421930e57112573438c4edb8f3164b1fdfed689a369a8d8d0`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; ad-hoc codesign verification passed.
- AX confirms +66, phone, Continue, QR and non-affiliation/session-import disclosure. No phone/code or account profile was entered. This is accountless development evidence only.
- Corrected public Site v162 source `6e1d7be28feb32c651f60e352971a3f8d493a1ad`, version `appgprj_6acba85192e08191acdf7011928848cf~appgver_9487e710ff248191b1f497281a7797ff`, deployment `appgdep_6aceb5a92a448191a0f3cf120850b40c` succeeded at https://netelegram.iryadom.chatgpt.site. Archive SHA-256 `4d01f8f646db834a84ddc6160deea4fc9e91facb78d30223f342207a77293b80` (295,795 bytes); saved content hash `sha256:d02427da812a53a2d2eceb6f3d70960311edcf2617a808b7e59225e35234acc2` (542,720 bytes/15 files). All eight public routes returned 200 `text/html`; Downloads has no binary URL.
- Local 157/157 result still covers unchanged app source `209be94`; it was not repeated for this docs/site-only checkpoint. Exact hosted run 38478591456 remains cancelled/no result. Real auth, 20-runtime coverage, Developer ID/notarization, updater and user release remain open.

### 2026-10-14 — diagnose hosted test cancellation from exact job logs

- Retrieved jobs and decoded logs for exact-source Actions run [38478591456](https://github.com/AffPapa/NeTelegram/actions/runs/38478591456), job `115575330981`, using the connected GitHub read API. macOS 15.7.9 arm64 / Xcode 16.4 built the test binary successfully in 31.65s. The workflow then produced no test output for 272s before cancellation; cleanup terminated `swiftpm-testing`.
- This rules out a compile failure but does not identify a hanging test or prove the runner itself is at fault. Keep hosted status cancelled/no PASS. Same-SHA rerun remains unavailable (connector returned 403); do not retry unchanged inputs. At the next planned Swift source change, add a filtered deterministic runner probe before the one full serial suite and use that exact run to localize the stall.
- Efficiency decision: use one checkout and one app candidate; no rebuild or full local suite was repeated because this turn changed only workflow/evidence documentation. The canonical Dev.app was exited normally after the accountless login UI check; no phone/code was entered.


### 2026-10-14 — reduce CI rebuild time and localize silent test stalls

- Updated `.github/workflows/ci.yml` with a SwiftPM `.build` cache keyed by macOS, architecture, Swift/Xcode versions, `Package.swift`, and `TDLIB.lock.json`. Added a known-fast filtered runner probe before the existing serial full suite. This keeps the concurrency-sensitive test suite serial while distinguishing runner startup from a later suite stall.
- Local validation passed: Ruby YAML parse, both checkpoint JSON parses, and `git diff --check`. No Swift source changed, so no Swift tests, app rebuild, or Site deployment were run.
- The optimization is not proven faster yet. First hosted run must report cache status, probe output, full-suite result and elapsed time. Baseline run 38478591456 compiled in 31.65s, then emitted no test output for 272s before cancellation; hosted PASS remains absent.


### 2026-10-14 — bound the hosted runner probe

- The filtered probe passed locally: `publicDisplayNameMatchesRepositoryName` passed 1/1 (9.10s build, 0.001s test execution) on local Xcode 27.0 / Swift 6.4 / arm64e. The first pushed workflow run 38481765351 restored the cache step successfully but was still executing the probe after more than one minute; its cache hit/miss detail and active logs were not yet available.
- Added `timeout-minutes: 2` to the isolated probe so a hosted runner startup stall cannot consume the full five-minute job budget. At the moment of observation the first run was still shown as in progress; its decoded logs later confirmed it completed successfully before the follow-up workflow commit. This limit is diagnostic; the full serial suite remains required after a passing probe.

### 2026-10-14 — cached probe and exact-source suite passed

- GitHub Actions run [38481987804](https://github.com/AffPapa/NeTelegram/actions/runs/38481987804) passed on checkpoint `d8055a1967e029b27e2db427939d5220f48dc0d8`, with unchanged app source `209be94fde904d0b666ab5c28f588d78610b05bf`. The 51 MB SwiftPM cache restored from the preceding checkpoint, then was saved under the new checkpoint key.
- The deterministic runner probe passed 1/1 in 0.001s. The existing serial suite passed 157/157 in 0.504s. The filtered invocation compiled in 17.50s; the prior uncached baseline compiled in 31.65s. The hosted job completed in 42s, versus the prior run cancelled after five minutes with no test result. This confirms a faster compile and a current hosted PASS; it does not explain why the uncached parent run stalled.
- Decoded logs for the preceding cold-cache run [38481765351](https://github.com/AffPapa/NeTelegram/actions/runs/38481765351) show it also passed the probe 1/1 and full suite 157/157; first compile took 48.43s, then the 51 MB cache was saved. The following warm run compiled in 17.50s, about 64% less compile time for these two comparable checkpoint runs. The first run was not cancelled.
- Metadata validation [38481987832](https://github.com/AffPapa/NeTelegram/actions/runs/38481987832) also passed. No AppKit source changed, no Dev.app rebuild or Site deployment was needed. Real login, twenty authorized runtimes, Developer ID/notarization and public app assets remain unverified.

### 2026-10-14 — Site v163 records measured CI improvement

- Updated only the existing public Site devlog through its official source helper. Exact Site source commit `73bdefad3368d9ed6d65d0e15745303e138db127` mirrors to the app repository's `website/` directory. No Site `origin` was changed and no new project was created.
- Saved version 163 as `appgprj_6acba85192e08191acdf7011928848cf~appgver_763225b471fc8191a19b41d759f602f1`; deployment `appgdep_6acebad482b88191b71d3ba495b4ba9b` succeeded at https://netelegram.iryadom.chatgpt.site with the audience still public. Archive SHA-256 `183568ef690995b5e3047a9da2b26314b4fb9e3566f39bd5a5693378d2b0b2e0` (296,477 bytes); Sites stored hash `sha256:97d555f676cc5e463e93f66bc6791ab719d3176fde98486d2d80659accc60f02` (552,960 bytes, 15 files).
- Static build/validation passed for eight routes. Archive inspection confirmed release feed files and assets, exact run/source markers, and no download URL. Anonymous HTTPS `/devlog/` returned 200 `text/html`. No app binary was built or published; real login, 20-runtime certification, Developer ID/notarization and updater remain open.

## 2026-10-14 — Verification cadence aligned with measured CI cache

- Corrected `DEV-WORKFLOW.md`: exact cold/warm cache runs 38481765351 and 38481987804 both passed the probe and 157/157 suite; compile step measured 48.43s then 17.50s with a restored 51 MB cache. The result is explicitly not a guarantee of later cache hits.
- Added a changed-path-to-check mapping so unchanged gates are reused and failures are investigated at the failing stage before retry. Documentation-only change; no Swift build, app launch, or Site deployment was needed.
- Checks: `git diff --check`; `PROJECT-STATE.json` and `ACCEPTANCE.json` parsed successfully. CI trigger review confirms this file change does not run the Swift suite.

## 2026-10-14 — Removed misattributed historical Site screenshot

- Public devlog previously embedded an authentic but obsolete screenshot whose binary title showed a former working name; its alt text incorrectly called it the current NeTelegram UI. Removed the image and its packaged asset, retaining a brief bilingual explanation in the historical entry. No app source or app bundle changed.
- Sites version 164 source `458e535ef2a81ff1a8ffe35a0428711d2a469d37` was saved and deployed to the existing public project `appgprj_6acba85192e08191acdf7011928848cf` as deployment `appgdep_6acebc95df188191a0a76fe5b408adbc`. Anonymous `/devlog/` returned 200 `text/html`; live content includes the correction and excludes the obsolete image path/name. Archive SHA-256 `604bcd6645f27b49b27e894db078968a486e45c3f2f938f6854769d7fb4dca88`, 185332 bytes; Sites saved archive hash `sha256:3959c3f17d243017cfe88cd6d82afced055bd4f44686343ed4686b40f2ed30df`, 419840 bytes.
- Mirrored the two changed devlog files and removed asset into the NeTelegram app repository. This is Site content/checkpoint work only; no Swift build/test or Dev.app rebuild was run.

### 2026-10-14 — Fail-closed release candidate validation

- Added `Scripts/validate_release.py` with candidate and post-publication receipt modes. Candidate checks bind immutable manifest metadata to frozen local artifact bytes, require real account evidence, require a 1/5/10/20 same-host measurement matrix and closed Telegram compatibility gates for stable, and validate signing/notarization/Gatekeeper and Sparkle metadata. Receipt checks bind the exact manifest hash to public byte downloads and required install/Site/feed checks.
- Added 11 targeted unit tests and wired them into the fast Ubuntu metadata workflow. Updated the manifest template with safe local asset paths and explicit empty coverage/open compatibility gates; documented the two commands in `DEV-WORKFLOW.md`.
- Local verification: targeted Python suite 11/11; JSON parse; Python byte-compile; `git diff --check`. This does not prove release readiness or app behavior. No Swift source changed, so no Swift suite or Dev.app rebuild; no login, signing, notarization, publication, or Site deployment.
- Reconciled checkpoint to public Site v164 deployment `appgdep_6acebc95df188191a0a76fe5b408adbc`; Site v164 remains development-only with no download asset.

### 2026-10-14 — Scope macOS CI to Swift test sources

- Changed both push and pull-request path filters from all of `Tests/**` to `Tests/NeTelegramCoreTests/**`, matching the SwiftPM test target. Python release-validator tests under `Tests/release/**` stay in the fast Ubuntu metadata workflow.
- Hosted run [38484677460](https://github.com/AffPapa/NeTelegram/actions/runs/38484677460) passed for exact workflow checkpoint `4ee0a210d36a9ca2b9c2bf0cc783b167f239d16e`; the probe and full serial Swift suite passed. This single run was triggered by editing `ci.yml`.
- Expected benefit: later metadata-only Python test changes no longer run the unrelated Swift suite.

## 2026-10-14 — Per-account network update recovery

- App-source commit `ec2d91b96dfed996d32d825bd03c1aabc3596c1a` now records failed TDLib network-type setters per account, keeps only the latest desired type, surfaces pending state for the selected account, and clears it only after setter success. A failure does not make the profile appear offline or start an unbounded retry loop.
- Local serial Swift suite passed 158/158. Exact-source GitHub Actions run [38485519098](https://github.com/AffPapa/NeTelegram/actions/runs/38485519098) passed 158/158 on macOS 15 arm64 / Xcode 16.4 / Swift 6.1.2. Synthetic tests include 20-runtime fanout and one-account failure/recovery; no physical sleep/wake, real account, or server-side delivery test was performed. No new local Dev.app was launched or rebuilt during this step.
- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf`, version 165, deployed as `appgdep_6acec1e799448191924afe11a2e1014b` from Site source `a445ea6dcd555c8b812941ae048182c5d4340234`. Anonymous `/devlog/` and `/downloads/` returned HTTP 200 `text/html`; the live devlog contains the exact commit/run and limitations, while downloads still correctly reports no release and has no installer URL. Site archive SHA-256: `c30c31060910e23290e6250ca4b7e9ce49686c3a5bbd73c690d031056323447d` (186103 bytes).
- Site helper initially failed because sandbox DNS could not resolve `git.chatgpt-team.site`; the same official helper and source succeeded with approved network access. No alternate Site, repo, credential route, app build, or release was created.
- Next: run one exact-source Dev.app smoke only after the existing instance is closed; real login remains deferred. All-20 hardware certification, signing/notarization, Telegram compatibility gates, and app downloads remain open.

## 2026-10-14 — Canonical Dev.app aligned with current source

- CUA confirmed the sole running NeTelegram Dev.app was stale (`7f95e03c`). The accountless window was exited; the same `/private/tmp/NeTelegram-Dev.app` path was rebuilt and opened once from clean repository checkpoint `e1fa50933066273344e6544eb3fcf0a368d66ac5` (app source `ec2d91b96dfed996d32d825bd03c1aabc3596c1a`).
- Incremental native build completed in 9.33 s with Xcode 27 / Swift 6.4 / arm64 and pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Bundle ID `org.affpapa.netelegram.dev`; source fingerprint `b237c73467dc5a9b1576182e679d67f0da51fd3f2323c9c2c2d0c2030f2457db`; nested code and bundle signature verification passed (ad-hoc development only). The visible title now matches `e1fa5093` and UI shows the accountless phone/QR entry and disclosure. No phone, OTP, account, profile, or old Telegram session was used.
- First build attempt was stopped by inaccessible default Swift module cache; retry with caches redirected to `/private/tmp` passed. Process inspection through shell is blocked in this sandbox, so the stale app was closed and absence of a running app confirmed through CUA before rebuilding; a one-call `NETELEGRAM_PGREP_BIN=/usr/bin/false` override was used only after that UI confirmation.
- This is a native accountless startup smoke only. It does not prove login, read/send, 20-account lifecycle, sleep/wake or release readiness. The canonical Dev.app is now left running at the current checkpoint; do not launch another copy.

## 2026-10-14 — Bind native app smoke to Swift source commits

- Updated `.github/workflows/native-app.yml` so push and pull-request changes under `Sources/**` run the pinned-TDLib Apple Silicon Dev.app build and lifecycle smoke, alongside the serial Swift unit suite. This closes the prior gap where source CI could pass while no native bundle was built for that source SHA.
- Updated checkpoint operating rules: metadata-only changes remain on the fast metadata workflow; source commits use both exact-SHA CI runs and one canonical Dev.app. No extra bundle was launched and app source did not change.
- Local validation: Ruby YAML parsing for both macOS workflows, JSON parsing for both checkpoint files, and `git diff --check` passed. Exact checkpoint metadata run [38486733576](https://github.com/AffPapa/NeTelegram/actions/runs/38486733576) passed. The workflow-only commit also triggered the pinned-TDLib arm64 Dev.app lifecycle smoke [38486733631](https://github.com/AffPapa/NeTelegram/actions/runs/38486733631), which passed. Swift app source/tests did not change, so no separate Swift unit suite was needed; the existing local Dev.app was not relaunched.

## 2026-10-14 — Bound Keychain work so one stalled account cannot hold the rest

- Replaced the single serial Keychain executor with an `OperationQueue` capped at two blocking operations. This keeps synchronous Security calls off the main/cooperative executors and allows one other account's key work to proceed if a call stalls, without spawning work for all 20 accounts at once.
- Replaced the misleading startup test (which only proved unrelated scheduler tasks could run without accessing the blocked Keychain queue) with a direct executor regression: operation 1 stalls, operation 2 enters, operation 3 remains queued until a slot frees, then proceeds.
- Focused local validation passed 1/1 under Xcode 27 / Swift 6.4; compile completed in 16.76 seconds and test in 0.111 seconds. This does not establish physical Keychain behavior. Exact-source macOS Swift run [38487262779](https://github.com/AffPapa/NeTelegram/actions/runs/38487262779), pinned-TDLib Dev.app/lifecycle run [38487262804](https://github.com/AffPapa/NeTelegram/actions/runs/38487262804), and metadata run [38487262753](https://github.com/AffPapa/NeTelegram/actions/runs/38487262753) all passed. No account credentials or Keychain contents were read.

## 2026-10-14 — Published bounded-Keychain milestone to the existing Site

- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf` was opened through the official source helper at prior Site source `a445ea6`. Added a bilingual factual devlog entry linked to app-source `4f7cb6f`, local focused test scope, exact macOS/native/metadata CI runs, and the limits of synthetic stall coverage. No stable changelog entry or download was fabricated.
- Source helper pushed and packaged exact Site source `350f12d472bc5cd925cb540d0e95214221f5f44e`. Local archive `/private/tmp/netelegram-site-keychain-4f7cb6f.tar.gz`: SHA-256 `3d64c522f05cb54afbb6e035d5644eca07fecadb10df32be7eada8a2c3642a83`, 186849 bytes, 50 tar entries. Local build and 8-route structural/link validation passed before packaging.
- Existing public Site version 166 saved as `appgprj_6acba85192e08191acdf7011928848cf~appgver_b95c27859c148191a6e6fc47997ce6b2`, saved archive hash `sha256:fbc7000935902e4c98c94789f239422f0152f5cbff039b0c124a48e51e8443b1`, then deployed as `appgdep_6acec7108bc48191b1670b457ca8ea24`.
- Anonymous TLS-verified `/devlog/` and `/downloads/` returned HTTP/2 200 `text/html`; devlog markers for source and all three exact CI runs were present. Downloads continues to state no release and offers no download button. Public audience and existing hostname were preserved.

## 2026-10-14 — Reuse the verified Dev.app and pin its identity to app source

- `Scripts/dev-app.sh` now derives the displayed/build identity from the latest commit touching `Package.swift`, `Sources/**`, or `TDLIB.lock.json`, so docs/checkpoint commits do not make unchanged app code appear to be a new build. The dirty marker tracks those same app inputs.
- Before rebuilding, the script checks the canonical GitHub origin and local checkout, then validates the existing app-source commit, source fingerprint, Swift version, pinned TDLib ref, support root, executable and TDLib hashes, Info.plist identity, and ad-hoc code signature. An exact match is reused; `--launch` only opens that verified bundle. Any mismatch retains the existing process guard and normal rebuild path.
- Native CI now compares the bundle identity against the app-source commit, not the docs/workflow commit. Checkout fetches full history so a script/docs-only trigger can still identify the exact last source commit. This avoids false version changes while retaining exact source traceability.
- Targeted local checks passed: `bash -n Scripts/dev-app.sh`, native workflow YAML parse, `python3 -m json.tool PROJECT-STATE.json`, `git diff --check`, and release metadata tests 11/11. Running `bash Scripts/dev-app.sh` against the already-open canonical app returned “Reusing verified canonical bundle” for source `4f7cb6f` in under one second; no build, bundle replacement, or relaunch occurred. CI validation for the changed script/workflow is pending publication.
- Canonical app remains `/private/tmp/NeTelegram-Dev.app`, source `4f7cb6f`, arm64, macOS 14 baseline, ad-hoc development signature. This does not test login, real accounts, 20-runtime behavior, Developer ID or notarization. Site v166 is unchanged because this was build-pipeline work, not a user-visible product milestone.

## 2026-10-14 — Exact-source validation for the Dev.app reuse guard

- The first native workflow attempt, [38488971908](https://github.com/AffPapa/NeTelegram/actions/runs/38488971908), correctly stopped before bundle assembly: GitHub Actions supplies `https://github.com/AffPapa/NeTelegram` without `.git`, while the local remote includes it. Accepted both forms without weakening the repository owner/name check.
- Follow-up commit `2fd84223a420a3aa7ac602085a34c0a3fc39bf3e` passed pinned TDLib, Dev.app bundle verification and lifecycle smoke in [38489107253](https://github.com/AffPapa/NeTelegram/actions/runs/38489107253). Metadata validation for the implementation/checkpoint commit passed in [38488971873](https://github.com/AffPapa/NeTelegram/actions/runs/38488971873).
- Local no-op validation continues to reuse the one canonical `4f7cb6f` Dev.app without replacing it. Current checkout is clean at tooling commit `2fd8422`; app-source SHA remains `4f7cb6f` until Swift changes.

## 2026-10-14 — Reflect privacy-lock state in the menu-bar status

- `Sources/NeTelegramApp/main.swift` now changes the menu-bar status to `Заблокировано · синхронизация продолжается` while privacy-locked and disables the already-satisfied `Заблокировать` command. Both lock and successful unlock refresh the menu immediately; background runtimes remain untouched.
- Local `swift build` passed for the changed source under Xcode 27 / Swift 6.4 in 8.92 s. The default sandbox attempt was rejected before compilation by macOS `sandbox_apply`; the same bounded build passed on the host. No unrelated or full local test suite was repeated; exact-source serial Swift and native Dev.app workflows will validate after push.
- The currently open canonical Dev.app remains the old, accountless source `4f7cb6f`; it has not been replaced. Rebuild/AX verification occurs once only after exact hosted checks.

## 2026-10-14 — Убрал дублирование полного Swift suite и выровнял checkpoint

- `DEV-WORKFLOW.md` теперь задаёт один полный serial Swift suite на exact-source hosted CI. Локально запускается только целевой тест для быстрой диагностики; второй полный suite нужен лишь при hosted-only сбое, смене toolchain или offline работе. Так один и тот же неизменившийся набор больше не гоняется подряд локально и удалённо.
- Checkpoint синхронизирован с app source `752f6842855373061f3a5e8cafb2b164838cf417`, Swift CI run `38489454775`, pinned-TDLib/native run `38489454777`, metadata run `38489454774` и публичным Site v167. CI запуски прошли; число Swift tests для этого run в checkpoint не указано и здесь не выдумывается.
- `Scripts/dev-app.sh` проверил clean app source, toolchain, pinned TDLib, support root, executable/TDJSON hashes, plist и подпись и повторно использовал `/private/tmp/NeTelegram-Dev.app` менее чем за секунду; сборки и второго запуска не было. CUA подтвердил AX-заголовок `NeTelegram · dev 752f6842` и пустой экран телефона/QR. Авторизация и смена lock/unlock в этом проходе не проверялись.
- Публичный in-app browser отобразил `/devlog/` с текущим SHA и ссылками CI. Site остаётся development-страницей; `/downloads/` не содержит фиктивной ссылки на бинарник.
- Точечная проверка checkpoint: `python3 -m json.tool` для обоих JSON, `python3 -m unittest discover -s Tests/release -t . -p 'test_*.py' -v` (11/11) и `git diff --check` прошли. Swift suite не повторялся, app source не менялся.
- Остаются открытыми: отложенный пользователем реальный login, 20 реальных авторизованных runtime, Developer ID/notarization, стабильная совместимость с требованиями Telegram и публичный бинарный релиз. Следующий цикл начинается с этого checkpoint, не с пересборки или повторного деплоя сайта.

## 2026-10-14 — Обновлён release preflight Developer ID и notarization

- Свежий `security find-identity -v -p codesigning` read-only inventory дважды возвратил четыре валидные identity: Apple Development, Apple Distribution и две Developer ID Application identity для Team ID `H6VGU2M6JD`. Один соседний вызов вернул ноль; повторные enumeration дали четыре, поэтому нестабильное чтение отмечено явно. Отпечатки и private keys не выводились.
- Read-only Keychain metadata query к штатной notarytool службе `com.apple.gke.notary.tool` вернул `errSecItemNotFound`; содержимое credential не запрашивалось. Проверка имён environment variables не обнаружила `APPLE_`, `ASC_` или `NOTARY_` credential names. Notarization profile пока не подтверждён.
- Это снимает только прежнее утверждение «Developer ID identity отсутствует». Никакой app signing, upload в Apple, notarization, release, аккаунтный тест или новый Site deploy не выполнялся. Stable release по-прежнему закрыт реальным login/20-account и Telegram compatibility gates.


## 2026-10-14 — Bound profile restore waiting on the shared API hash

- Source commit: `80b69f338e9df01955ffacb8925f4c56800e576c` (parent `d9e1fda7a203002d283ccd6eac314eaf07b304c3`). Added a single-flight `TelegramAPIHashReadiness` shared by saved-profile restore, profile retry, and new-account creation. A wait ends with a clear 10-second status; the blocking Security operation remains bounded in the existing Keychain queue and is not duplicated by a retry. A late successful value is reused and invalidated after the user replaces the app API hash. Timeout leaves profile failure state and account storage untouched.
- Focused local SwiftPM test `apiHashReadTimeoutRetriesJoinOneLookupAndCacheItsLateResult` passed 1/1; app and test targets compiled; `git diff --check` passed. No full suite was repeated locally. The running canonical Dev.app remains source `752f684`; no bundle replacement, login, or credential use occurred.
- Git push was attempted twice and failed before authentication with `Could not resolve host: github.com`. Connected GitHub API read verified `main` remains at the expected parent `d9e1fda`; no hosted CI or Site publication exists for `80b69f3`. Keep this exact commit and push it when DNS is available, then inspect its exact-source Swift, pinned-TDLib Dev.app, and metadata workflows. Physical Keychain stall/recovery remains unverified.


## 2026-10-14 — Offline exact-source serial validation

- With GitHub DNS still unavailable, ran the project’s exact serial offline command on app-source commit `80b69f338e9df01955ffacb8925f4c56800e576c`: `swift test --package-path . --scratch-path .build/canonical-dev-build/swift --no-parallel --verbose`. Result: **159/159 passed** in one suite; Swift compiled `NeTelegramApp` and `NeTelegramCoreTests` under arm64 / Xcode 27 / Swift 6.4. The focused timeout/single-flight regression passed 1/1, and release metadata validation passed 11/11. JSON parsing and `git diff --check` passed.
- This proves synthetic logic and compilation for the local source only. It is not hosted CI, a packaged Dev.app smoke, a physical Keychain stall/recovery, real account login, or 20-account certification. The open canonical Dev.app stays at source `752f684`; no second bundle was created.
- The GitHub API read still reports `main` at `d9e1fda`; Git transport cannot resolve `github.com`. The exact two local commits remain queued for one push when DNS is available. Site remains public development version 167, unchanged.


## 2026-10-14 — Discard stale API hash after in-flight replacement

- Final source commit `5e47c4eec6bf57d03e76b92dcb449b5eaf7c0f56` folds the bounded API-hash wait and its replacement-race fix into one source revision. Replacing the app hash invalidates existing waiters; the non-cancellable old SecItem read may finish, but its value is discarded. New waiters queue one fresh lookup after it finishes. No old hash can be cached or passed to a profile startup after invalidation.
- Both focused regressions passed 2/2, including replacement during a blocked lookup. Full serial Swift suite passed **160/160** under arm64 / Xcode 27 / Swift 6.4; release metadata suite passed 11/11; JSON and diff checks passed. No real Keychain daemon was blocked and no account credentials were used.
- Candidate is local only. GitHub API last confirmed `main` at `d9e1fda`; Git transport still failed to resolve `github.com`, so no hosted CI, native bundle workflow, Dev.app replacement, or Site publication has occurred. Current canonical Dev.app stays at source `752f684`.

## 2026-10-14 — Gate API-hash reads during Keychain replacement

- Consolidated source commit `2d8a4e5964211c9fbd40136f5470da7d47266937` starts the readiness replacement barrier before the Keychain write and releases it after either success or failure. A profile restore arriving during the write waits; it cannot read/cache the old hash during that write. Local history was consolidated against `origin/main` so one source candidate replaces the abandoned unpublished intermediate commits.
- Focused `replacingAPIHashDiscardsOldInFlightLookupBeforeStartingProfiles` passed 1/1. The exact consolidated source passed serial SwiftPM suite 160/160 under arm64 / Xcode 27 / Swift 6.4. `git diff --check` and checkpoint JSON parsing passed.
- No app bundle was rebuilt or launched, no Telegram credentials were read, and no Dev.app was replaced. This is synthetic readiness coverage, not physical Keychain daemon recovery or a real Telegram login.
- Source is local only and one commit ahead of `origin/main` at `d9e1fda`. Next: commit this checkpoint, make one push attempt, then inspect exact-SHA CI/native workflows. Reuse the existing Dev.app only after its exact-source native workflow passes.


## 2026-10-14 — Published API-hash readiness development milestone

- App source `2d8a4e5964211c9fbd40136f5470da7d47266937` and checkpoint/source-aggregate `7d63518026eb17266cfb816d4af22189be859374` are pushed to `AffPapa/NeTelegram`. Exact run results: [macOS CI 38492400249](https://github.com/AffPapa/NeTelegram/actions/runs/38492400249), [pinned TDLib/Dev.app 38492400259](https://github.com/AffPapa/NeTelegram/actions/runs/38492400259), [metadata 38492400278](https://github.com/AffPapa/NeTelegram/actions/runs/38492400278) all succeeded. Local serial tests passed 160/160; focused replacement race passed 1/1.
- Canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt once after the prior empty welcome instance quit. BuildInfo records app SHA 2d8a4e5, arm64, macOS 14 baseline and pinned TDLib; ad-hoc `codesign --verify --deep --strict` passed. CUA confirmed title `NeTelegram · dev 2d8a4e59`, accountless phone/QR welcome and non-affiliation note. No credentials entered.
- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf` advanced to version 168 from Site source `8a90bfa27cb219f4c86838b2f027f4d6533f72f6`, deployed as `appgdep_6aced33c6180819180ed76df0094ad26`. Saved archive hash `sha256:d7af3b2d8b75b2c1c140fe747d098f02d6bacec10ec81a4754ba5043f27e8a1e`; local tar SHA-256 `fcbde11c88acc4645df7d2448a58ad815e97d7ad34d37d33aa1df92af50502e2`. Anonymous CUA verified `/devlog/` with the new 2d8a4e5 entry and exact workflow links; `/downloads/` shows NO RELEASE, no empty binary button, and a GitHub source link. Downloads correctly have no app binary.
- The app repository website mirror and checkpoints were updated locally; `website/validate_site.py` passes 8 static routes. Next: commit/push this docs-only mirror, verify metadata validation for the new checkpoint and anonymously check the public Site routes. No real auth, 20-account, Developer ID, notarization or release test was performed.


## 2026-10-14 — Связал тест all-active fan-out с production helper

- Усилен APP01: `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges` теперь вызывает тот же `AccountRestorePlanner.enqueueStartupProfiles`, который вызывает `AppDelegate.restoreProfiles()`. Проверяется синхронная постановка всех 20 профилей до bounded startup scheduler, один зависший open, отказ первого TDLib-запроса одного профиля, retry с новой generation, регистрация route до первого запроса и изоляция маршрутов при переключении A/B.
- Целевой локальный тест прошёл 1/1 на arm64 / Xcode 27 / Swift 6.4. Первичная sandbox-команда остановилась до компиляции из-за запрета системного Clang cache; тот же тест прошёл на host runner за 8.81 s сборки и 0.001 s исполнения. `git diff --check` и exact-source CI ещё ожидают фиксации/публикации кандидата.
- Только тесты и checkpoint изменились; Swift application source, TDLib pin, текущий bundle и UI не менялись. Канонический Dev.app остаётся на `2d8a4e5`, без rebuild/relaunch. APP01 остаётся partial: это production-helper synthetic integration, не 20 авторизованных Telegram-сессий.


## 2026-10-14 — APP01 fan-out test passes exact-source hosted CI

- Test/checkpoint commit `bb9b38f8abee386b83b9f7949b22b6cfcc985744` is pushed to `AffPapa/NeTelegram`. The exact-source macOS CI [38493619014](https://github.com/AffPapa/NeTelegram/actions/runs/38493619014) passed the filtered runner probe and serial suite **160/160**. Metadata validation [38493619106](https://github.com/AffPapa/NeTelegram/actions/runs/38493619106) passed. No native-app workflow was triggered because only Tests/checkpoint paths changed.
- The focused local APP01 test passed 1/1. It now calls the same synchronous `AccountRestorePlanner.enqueueStartupProfiles` helper used in production `restoreProfiles()` and verifies 20 queued startup tasks with bounded concurrency, one stalled opening, one first-request failure/retry with new generation, route registration, and account-selection isolation.
- Scope remains synthetic. It does not execute all of `AppDelegate.restoreProfiles`, TDLib with real sessions, or certify 20 real accounts. App source remains `2d8a4e5`; the single canonical Dev.app was not rebuilt. Public Site remains v168 because this was test-coverage work only.


## 2026-10-14 — Revalidate photo send after asynchronous staging

- Source commit `5b40336754462cc767727a1bde9c553e2513d13e` adds a live-target guard after ImageIO finishes staging a photo. Immediately before manifest registration, production checks that the exact captured account/runtime is still registered and ready, Telegram identity and generation still match, privacy lock/epoch is unchanged, chat permission still allows the captured sender and typed topic, and Stars remain zero. If state changed, the staged file is removed and the caption stays in its draft.
- Focused local regression `photoSendRevalidatesLiveTargetAfterAsyncStaging` passed 1/1. After the exact-source hosted runner stalled before its first test event, the one permitted diagnostic full local serial suite passed 161/161 under arm64 / Xcode 27 / Swift 6.4.
- Exact-source macOS CI [38494308524](https://github.com/AffPapa/NeTelegram/actions/runs/38494308524) was cancelled at its 5-minute limit. The filtered probe passed and test bundle compiled, but logs contain no `Test run started`; runner cleanup terminated `swiftpm-testing`. GitHub connector retry returned 403 (`Resource not accessible by integration`), so no hosted suite PASS is claimed. The separate pinned TDLib/arm64 Dev.app build [38494308687](https://github.com/AffPapa/NeTelegram/actions/runs/38494308687) passed exact-source assembly.
- No app login, canonical local Dev.app rebuild, Site update, or release asset change occurred. Real picker/TDLib send remains unverified. APP17 remains partial. Next inspect APP16's unrouteable-update failure handling; do not repeat an unchanged hosted CI attempt.

## 2026-10-14 — Exact-source routing guard verified; stale failure status superseded

- App source `a45536262185b13e2bb47703449f6d4c69a7bb3d` contains APP16 fail-closed routing: an unknown TDLib client route terminates the shared receiver after draining already accepted events. Focused route test passed 1/1. The commit also includes the APP17 photo dispatch guard; its focused test passed 1/1 on the parent source.
- Exact-source macOS CI [38495482988](https://github.com/AffPapa/NeTelegram/actions/runs/38495482988) passed **162/162** tests on macOS 15 / Xcode 16.4 / Swift 6.1.2 arm64. Pinned TDLib arm64 Dev.app assembly [38495482965](https://github.com/AffPapa/NeTelegram/actions/runs/38495482965) passed. It did not launch the app or test a real account.
- The older 5b40336 test-runner cancellation is superseded by this exact-source CI result. Do not retry it or rebuild a455362. Real login, picker/send against Telegram, 20-account certification, Developer ID notarization and Telegram compatibility gates remain open.
- Site remains public v168. The official Sites helper was opened in a fresh empty workspace; its exact remote lookup failed because DNS cannot resolve `git.chatgpt-team.site`. The initial non-empty workspace invocation also failed during reserved checkout setup. No Site source push, save, or deployment occurred; do not repeat until that DNS route changes.

## 2026-10-14 — Published APP16/APP17 development log

- Public Site `appgprj_6acba85192e08191acdf7011928848cf` advanced to v169 while preserving its public audience. New bilingual entries report the exact app source `a45536262185b13e2bb47703449f6d4c69a7bb3d`, macOS CI `38495482988` (162/162), and pinned-TDLib Dev.app assembly `38495482965`. The entries explicitly say real accounts and native photo picker/send were not tested.
- Site source commit: `348ae0873fa32549b38d8134bce3b48ca7a58f4b`. Deployment: `appgdep_6acedbaf4dd4819197f0e5816d5b03db`. Saved archive content hash: `sha256:8f269a1cb3049efb4e4d111db0c309587f89123f16ef860e1cfc078da51b870b`; local ZIP-tar bytes SHA-256: `d4eb83c574fa30165e68a33018cc0799b91a47b3e1851639d6d3c22073ca89ac` (189019 bytes).
- Anonymous in-app browser loaded `/devlog/` and exposed both entries with exact CI/native links. `/downloads/` still has no app binary or download action. No app build or release occurred.
- Site helper needed host-network execution because the sandbox could not resolve either exact Git hostname; host DNS resolved both. No new credentials were created; the existing short-lived Site credential was passed only by hidden stdin and will expire.

## 2026-10-14 — Checkpoint consistency guard and faster resume path

- Reconciled the authoritative resume snapshot to app source `fa80d5a5f77b1fecf583754f3fe5cf69209be75b`, the one canonical `/private/tmp/NeTelegram-Dev.app` (BuildInfo/CUA title and fingerprint match), and public Site v170 / deployment `appgdep_6acee10806988191b7212e17add857a3`. Corrected stale pointers that still said Site v169, Dev.app source `2d8a4e5`, Site source `8a90bfa`, and older release-identity inventory. Historical per-case evidence remains unchanged.
- Added `Scripts/validate_checkpoint.py` to make metadata CI fail fast when app source, Dev.app fingerprints, or Site version/project/deployment/source pointers disagree. Wired it into the existing metadata workflow; checkpoint-only changes still do not run Swift or rebuild/relaunch Dev.app.
- Local checkpoint validator passed; release metadata tests passed 11/11; JSON parse and `git diff --check` passed. Commit `1341f4f30053454525864fa8f65c48949c9addd3` is pushed to `AffPapa/NeTelegram`; exact metadata workflow [38499013967](https://github.com/AffPapa/NeTelegram/actions/runs/38499013967) passed. Post-push local `main` and `origin/main` matched, and the validator passed again.
- No Swift app source, binary, Dev.app process, Site deployment, release asset, or user account changed. Next resume at the current acceptance gaps from this checkpoint; do not rerun AUTH05 or rebuild the unchanged app.

## 2026-10-14 — Native keyboard path and current Telegram API gates

- On the exact open canonical `/private/tmp/NeTelegram-Dev.app` at app source `fa80d5a`, CUA accessibility state confirmed Tab focus order: country search → country picker → phone number → Continue → QR. No button was activated; no phone number, code, profile, or Telegram account was created. This narrows APP22 evidence only; VoiceOver, IME, RTL, and authenticated conversation keyboard use remain unverified.
- Local metadata tests passed 11/11 and `Scripts/validate_checkpoint.py` passed. Checkpoint commit `083e9db8a300466f1a0024ca8998e20e368d03b4` is pushed. Exact checkpoint metadata run [38499490904](https://github.com/AffPapa/NeTelegram/actions/runs/38499490904) passed. No Swift source changed; no app rebuild/relaunch or Site deployment was needed.
- Re-read current primary [Telegram API Terms](https://core.telegram.org/api/terms) and [sponsored-message rules](https://core.telegram.org/api/sponsored-messages). Terms §§1.3–1.4 require basic functions and correct Telegram semantics; §2.1 requires this app's own api_id; §2.2 requires prominent API/ecosystem disclosure; §2.3 conflicts with public title `NeTelegram`; §3.3 requires sponsored channel messages. The sponsored video path has required playback, timing, and click behavior. The user declined a video player, so channel access/stable release remains deferred; no title or feature scope was silently changed.
- Current app search uses TDLib `searchChats` (offline search over known chats), `searchMessages` (all non-secret chats), and local NeTelegram profile-name matching. It does not invoke MTProto `contacts.search`; the separate sponsored-peer path documented for that global contact-search flow is therefore not implied by the current UI. No broader public-user search claim is made.

## 2026-10-14 — Stop redundant pinned-TDLib builds on ordinary Swift edits

- Narrowed `.github/workflows/native-app.yml`: ordinary `Sources/**` edits and edits to the workflow itself no longer trigger a pinned-TDLib/Dev.app rebuild. `Package.swift`, `TDLIB.lock.json`, and native build/lifecycle scripts still trigger it automatically. The existing `workflow_dispatch` remains the explicit bundled app/lifecycle gate for integration and visible UI changes.
- Added `Tests/release/test_native_workflow_scope.py` so the trigger split and manual dispatch cannot silently regress. Updated `DEV-WORKFLOW.md` to match the route.
- Validation: Ruby YAML parser passed; trigger-scope tests passed 2/2; complete release metadata Python suite passed 13/13; `git diff --check` passed. No Swift source, app binary, canonical Dev.app, account data, release asset, or Site changed. Hosted metadata CI is expected after push; native app packaging is intentionally not part of this workflow-only change.
- This removes a duplicate heavy job from ordinary Swift changes: cached serial macOS CI remains automatic for Swift source; native packaging is now run only when its integration evidence is needed.
- Publication verification: commit `b5184c252ed8bd9a4e1e67ff744543a40dd0901d` is `origin/main`; GitHub metadata validation [38499847748](https://github.com/AffPapa/NeTelegram/actions/runs/38499847748) passed. No native bundle workflow ran.

## 2026-10-14 — AUTH05 disclosure polish and one-bundle verification

- Source commit `e43bcd0d5e7304f6731e589ce88bf5438493f520` shortens the login disclosure and reduces its visual weight. It still states that NeTelegram is an independent Telegram API/TDLib client and is not affiliated with Telegram Messenger LLP; it also says sessions are not imported.
- Exact-source macOS CI [38500525870](https://github.com/AffPapa/NeTelegram/actions/runs/38500525870) succeeded. The returned job evidence did not include a test count, so none is claimed. The optimized workflow did not run the separate pinned-TDLib native bundle job for this ordinary Swift UI edit.
- Reused the one canonical `/private/tmp/NeTelegram-Dev.app`; embedded BuildInfo identifies source `e43bcd0`, fingerprint `f020523821ea483e933cc7bf5712e4df3d06ab62b284bb1e816046fc39ad6229`, arm64, macOS 14 baseline, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`, ad-hoc development signature. Its executable SHA-256 is `ed17b1e108223fd97e921cf2691abdee6c4ab927539326471b28a7bdfdb4c461`.
- CUA confirms the app title/source and accessible accountless login controls. No phone, code, Telegram account or session was used. This is a presentation check, not real-auth or accessibility certification. Public Site remains v170 and has no app download.
- Checkpoint update only; no app rebuild, full local suite, Site deployment, or release asset change. Next: use the exact current-source partial acceptance list to select one bounded implementation slice; keep the real-account step deferred until the user logs in.

## 2026-10-14 — Auth disclosure contrast correction; native replacement guarded

- Source commit `0a7cbe627d253c5cb9751573b014145ee9f630d3` changes only the disclosure color from tertiary to secondary label contrast. Exact-source macOS CI [38501111688](https://github.com/AffPapa/NeTelegram/actions/runs/38501111688) passed; no test count is claimed from the available output.
- Native visual verification is pending. CUA Cmd+Q and menu Quit did not terminate the old accountless app at `e43bcd0`; `Scripts/dev-app.sh` refused replacement. Sandbox `pgrep` cannot access macOS process state (`sysmond service not found`); the guarded unsandboxed invocation confirmed the app is still running. No second bundle or forced kill was used.
- Added a checkpoint rule/test so a stale running bundle can be recorded only when the pending candidate names the exact new source, old bundle source, blocked state, and reason. This prevents a false claim that an old UI is the current binary while still allowing an honest resumable checkpoint.
- Next: diagnose/complete the normal quit barrier, then rebuild only the canonical Dev.app from `0a7cbe6` and inspect the contrast once. Real account entry remains deferred.
- Checkpoint validator regression and metadata suite passed locally **14/14**; `Scripts/validate_checkpoint.py`, both JSON parses, and `git diff --check` passed. Checkpoint metadata CI [38501377674](https://github.com/AffPapa/NeTelegram/actions/runs/38501377674) passed for exact commit `5aaadc7bb4dbb1635fe8574ef7e00e5f4790b6d5`.

## 2026-10-14 — Verified current auth disclosure contrast in the canonical app

- The normal quit barrier completed after the previous turn's UI action; fresh CUA inventory confirmed NeTelegram Dev was no longer running. No process was force-killed and no second app bundle was created.
- Rebuilt `/private/tmp/NeTelegram-Dev.app` once from exact source `0a7cbe627d253c5cb9751573b014145ee9f630d3`; Swift build completed in 5.24s with pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. BuildInfo fingerprint is `f80ce59a1b8fa6497e1abaa2441dc3c1d10b491e5929606e6290162672a3639b`; executable SHA-256 is `f5b47d8ab41381bbe045ac0d3c7696a4ac78d7284bb5a7ec83b2d94523220b4d`; `codesign --verify --deep --strict` passed. Ad-hoc dev signing only.
- CUA title and screenshot confirm `NeTelegram · dev 0a7cbe62`. The non-affiliation notice is now readable in secondary contrast without dominating the login form. No phone, code, account, or Telegram session was entered. This is a visual smoke, not real-auth or accessibility certification.
- Exact-source macOS CI [38501111688](https://github.com/AffPapa/NeTelegram/actions/runs/38501111688) and prior checkpoint metadata CI [38501473452](https://github.com/AffPapa/NeTelegram/actions/runs/38501473452) passed. No app release or Site deployment occurred; Site remains public v170 without a download.

### 2026-10-14 — remove duplicated resume-action drift and record auth review

- Exact source `0a7cbe627d253c5cb9751573b014145ee9f630d3`: the one canonical `/private/tmp/NeTelegram-Dev.app` was reviewed in light appearance after restoring its centered default window. CUA screenshot and accessibility tree showed the complete accountless phone/QR form and disclosure. Minimum size, dark appearance, accessibility contrast, and subsequent auth states remain unverified; AUTH03 stays partial.
- The two resume checkpoints had different `next_action` text. `Scripts/validate_checkpoint.py` now rejects that drift, with a regression in `Tests/release/test_validate_checkpoint.py`; both files now name the same next slice: APP02 production restore orchestration under an injected stalled Keychain preparation.
- Scope is metadata/checkpoint only: no Swift source, app bundle, TDLib or Site changed. Verify with the release metadata tests and checkpoint validator; do not rerun the Swift suite or rebuild Dev.app.

### 2026-10-14 — keep 19 profile preparations moving past one stalled Keychain operation

- Added `oneStalledProfileKeychainPreparationDoesNotBlockTheOtherNineteen` in `Tests/NeTelegramCoreTests/RuntimeCoordinatorTests.swift`. It runs 20 local account namespaces through the production `RuntimeStartupScheduler`, `SecretsStore.performKeychainOperation`, and `ProfileStoragePreparer` path; one Keychain operation is held while the other 19 finish, then released and drained.
- Focused test passed 1/1 on arm64 / Xcode 27.0 / Swift 6.4 (compile 17.99 seconds; test 0.018 seconds). The first unredirected run failed before manifest compilation because the managed sandbox denied the default Clang module cache; the documented `/private/tmp` cache route still hit SwiftPM sandbox setup denial. The identical focused test then passed in an explicitly authorized host execution. This is harness setup, not a product test failure.
- Synthetic-only evidence: no real OS SecItem stall, AppDelegate lifecycle, Telegram login, authorized accounts, or 20-runtime resource measurement. The existing canonical Dev.app at app source `0a7cbe6` was not rebuilt; this test-only change triggers one hosted exact-source Swift suite, not the pinned TDLib bundle workflow.

### 2026-10-14 — make shutdown drain awaitable and the photo-cache regression deterministic

- Source commit `67341bab5399fcf3323f0a9fd5b486b0dd8bf6d1` changes `TDLibUpdatePipeline.finishInputAndDrain()` to async and moves its blocking DispatchGroup wait off Swift cooperative executor threads; AppDelegate now awaits the barrier directly. The focused 20-client accepted-update drain regression passed 1/1.
- Repeated full-suite evidence isolated one prior false failure to the test's assumption that system `NSCache` must retain an unrelated preview under memory pressure. Added an internal cache seam and a deterministic test cache; the production implementation still uses bounded `NSCache`. Scoped invalidation checks now target the exact cache entries. The photo regression passed 1/1, then the serial suite passed 164/164 locally in 0.455s.
- Exact-source GitHub macOS CI [38504170791](https://github.com/AffPapa/NeTelegram/actions/runs/38504170791) passed the runner probe and all 164 tests in 65 seconds.
- Rebuilt the one canonical arm64 `/private/tmp/NeTelegram-Dev.app` once from `67341ba` in 5.22s with pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Ad-hoc `codesign --verify --deep --strict` passed; executable SHA-256 `ad0acae841e326944953a49cebd7ba5629ad068f00d7b5887946042a5594a694`; TDLib SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. CUA showed `NeTelegram · dev 67341bab` and the accountless welcome screen. Normal menu Quit exited the process. No credentials were entered.
- This is synthetic/accountless lifecycle evidence. Real Telegram login, 20 authorized runtime behavior, Developer ID/notarization, Gatekeeper and stable distribution remain unverified. No Site or app release was changed.
- After recording the normal quit, reopened the same fingerprint-verified canonical bundle through `Scripts/dev-app.sh --launch`; it reported `Reusing verified canonical bundle` and CUA again confirmed title `NeTelegram · dev 67341bab`. No second bundle or rebuild was created.
- Checkpoint validation after source commit `6b9fc7b716de62044bcb6b56e088d885dbe7a37c`: metadata workflow [38504598500](https://github.com/AffPapa/NeTelegram/actions/runs/38504598500) completed successfully. It checked JSON, checkpoint consistency, and all 15 release metadata tests. This run was for the exact checkpoint commit; this RUN-LOG-only receipt does not change app source or trigger another metadata suite.
- Final checkpoint commit `51c5fc1ae13d41715153e00569824824dd5d3198` passed metadata validation in [38504749164](https://github.com/AffPapa/NeTelegram/actions/runs/38504749164). This confirms the checkpoint now records the preceding exact successful 15-test metadata run; no app code, bundle, or Site changed.
### 2026-10-14 — bound silent hosted suite time and avoid duplicate runs

- Workflow-only commit `9cf35eb62ae985e5b7d395e75b4f7e8b329697fb` caps the serial Swift suite step at two minutes; YAML parse and checkpoint validation passed. Push succeeded to `AffPapa/NeTelegram main`.
- Hosted run [38506939379](https://github.com/AffPapa/NeTelegram/actions/runs/38506939379): filtered runner probe passed; full test bundle built in 0.38s, then emitted no test output before the two-minute step timeout. No current-source hosted full-suite PASS. The timeout reduces a repeated silent wait from 5 minutes to 2; it diagnoses/bounds the issue but does not fix it.
- Comparison evidence: parent source `67341bab5399fcf3323f0a9fd5b486b0dd8bf6d1` passed the hosted serial suite 164/164 in run 38504170791. Current app source `aab6a4a2df950ae61de4d69b5f67a2b251e6d8a2` differs in this test suite by two assertions for the notification transition and passed locally 164/164 plus the focused regression 1/1. Do not rerun unchanged inputs.
- Checkpoint commit `d089ecd22e282d48357463a44a97bcd4998eeb07` is pushed; its metadata validation run [38506808954](https://github.com/AffPapa/NeTelegram/actions/runs/38506808954) succeeded. This entry records the later workflow diagnosis; no app source, app bundle, Site, or release assets changed in this slice.
- Next source iteration: finish one production restore/startup slice; run one focused local regression plus one local serial suite, and make the hosted probe target that changed regression before one bounded full CI run. Reuse the existing canonical Dev.app unless app inputs change.

### 2026-10-14 — APP02 cleanup fan-out and exact-source checkpoint

- Production restore now schedules pending per-profile cleanup independently; one blocked cleanup no longer holds restore before other profiles are queued. Added `restoreCleanupFanoutDoesNotWaitForOneBlockedProfileBeforeQueueingOthers`. This is synthetic orchestration coverage, not a real Keychain or account test.
- App source `e7cc4b3be3d51d199dd16c3e0991feb001eb905c`: focused regression passed 1/1; local serial Swift suite passed 165/165. Exact-source hosted macOS CI [38508018017](https://github.com/AffPapa/NeTelegram/actions/runs/38508018017) passed the probe and all 165 tests.
- One canonical arm64 Dev.app was built from that exact source in 5.29s. Ad-hoc `codesign --verify --deep --strict` passed; executable SHA-256 `8847aff674738b94a758a77a21a5a876a0b258130fcab86b5d9505459f04bdeb`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. CUA confirmed matching accountless login. No credentials entered.
- Existing public Site v172 source `12d774c1523681d6cc948ba25c635393fefa3ee5` was saved and deployed as `appgdep_6acefc4c79888191afe5b199682996a2` at https://netelegram.iryadom.chatgpt.site. Saved archive SHA-256 `92b1515168051f7e7ae954a0b8ffbecd37ef0aa903ee0a9f96cd2c9e008dd920` (450,560 bytes). Anonymous browser loaded `/devlog/`; no application download was created.
- Checkpoint now separates app source, Site source/version, hosted suite, local Dev.app and publication evidence. Real login remains deferred; actual SecItem stall, 20 authorized accounts, distribution, updater and Telegram compatibility remain unverified. Next is one APP01 production-path slice; no unchanged tests/builds should be repeated.

- Checkpoint commit `2ff390a2324ab611d0a0d98dcbf606bcd1afaa2b` passed exact-commit metadata validation [38508667707](https://github.com/AffPapa/NeTelegram/actions/runs/38508667707). No additional app tests or build were run for this documentation receipt.

### 2026-10-14 — APP01 exact-source evidence reconciliation

- Acceptance now records that `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges` passed within exact-source macOS CI [38508018017](https://github.com/AffPapa/NeTelegram/actions/runs/38508018017) for app source `e7cc4b3be3d51d199dd16c3e0991feb001eb905c`; the complete suite passed 165/165. The test uses the production `enqueueStartupProfiles` helper, bounded startup scheduler and RuntimeCoordinator with synthetic identities.
- APP01 remains partial: this does not run the AppKit restore lifecycle, real TDLib sessions, twenty authorized accounts, or same-Mac resource measurements. The test was not rerun because its exact source and CI result are unchanged.
- Updated the shared next action to AppKit restore-boundary coverage; no app source, build, or Site deployment changed.

- Resume-routing correction: canonical checkout remained `/private/tmp/netelegram-cli-work`, branch `main`; before this metadata snapshot, local HEAD and `origin/main` both matched `78650357b4fc5eefae1211a5758c90c685b92b54`, working tree clean. App-source identity remains `e7cc4b3be3d51d199dd16c3e0991feb001eb905c`; this checkpoint update does not change Swift code or Dev.app.

## 2026-10-14 — APP01 startup presentation coordinator and bounded CI diagnosis

- App-source commit `3f11a0e992b40ac4e905a177605008940f15cf95` moves selected-account intent and the startup presentation decision into `AccountStartupPresentationCoordinator`, used by AppDelegate and the regression test. The duplicate pure policy was removed. This is a narrow production seam; it does not mock TDLib or all of AppDelegate's async profile-start registry.
- Focused regression passed 1/1. Full local serial suite passed 166/166 in 0.441s on arm64e / Xcode 27 / Swift 6.4. `Scripts/validate_checkpoint.py` and `git diff --check` passed before this checkpoint update.
- Exact-source [macOS CI run 38510759384](https://github.com/AffPapa/NeTelegram/actions/runs/38510759384): filtered runner probe passed; full serial suite step timed out after its 2-minute cap. GitHub annotation included a macOS arm64 capacity notice. This is recorded as a timeout/failure; no hosted PASS is claimed. Raw job logs were not accessible through the authenticated CLI route. The previous exact-source run 38509465812 passed 166/166 on source `4dcddcc`, not this source.
- The single canonical `/private/tmp/NeTelegram-Dev.app` remains at source `4dcddcc`. Desktop inventory reported NeTelegram Dev running; no rebuild or second bundle was made. One named AppKit account-selection smoke remains pending after the canonical process exits.
- No Sites deployment, app release, login credentials, or Telegram profiles were used. Real account coverage and all-20 resource certification remain unverified.
- Next: diagnose the full-suite runner/test-runner timeout before any retry; preserve the single canonical Dev.app identity, then rebuild that path once and run one named selection smoke. Current full implementation/release gates remain open.

### 2026-10-14 — reduce hosted Swift CI to one test process

- Current app-source commit `9f4d3cabf6c4ca84489613fbc350fa65baa2130a`: focused production registry, API-hash timeout/retry, and twenty-client receive-drain probes each passed 1/1; exact-source local serial Swift suite passed 167/167 in 0.442s on arm64e / Xcode 27 / Swift 6.4.
- Exact-source hosted run [38512034207](https://github.com/AffPapa/NeTelegram/actions/runs/38512034207) passed all three isolated probes, then the full suite timed out at its 2-minute step cap; GitHub annotated macOS arm64 runner capacity. This is not a hosted suite pass. Repeating the same probes before the full suite added process startups without preventing the timeout.
- Workflow commit `306f2c8` removes the three extra SwiftPM test processes and runs one serial full suite with an 8-minute step cap / 10-minute job cap. Ruby YAML parse, single-test-process assertion, and `git diff --check` passed. `DEV-WORKFLOW.md` now records this as the default and prohibits restoring redundant preflight runs without evidence.
- Checkpoint validation now accepts a diagnosed timeout with any exact-source `PASS N/N` local serial Swift suite record instead of hard-coding the obsolete 166-test count.
- Push of `306f2c8` failed before authentication because the network could not resolve `github.com`. No credential was printed, changed, or retried. Workflow run is pending push/network recovery. Canonical Dev.app remains at source `4dcddcc`; no rebuild, duplicate app, login, Site deploy, or app release occurred.

### 2026-10-14 — fix the final-receive-update shutdown race

- The single-process hosted macOS run [38512759019](https://github.com/AffPapa/NeTelegram/actions/runs/38512759019) exposed a reproducible hang: all earlier tests passed, then `twentyClientPipelineStopsBlockedReceiveAndDrainsAcceptedUpdates` waited forever at the final account-1 event. Its 8-minute timeout was not runner capacity.
- Focused stress made the state concrete: after releasing the blocked callback, the receive thread had exited and callback `1:1` had completed, but `bufferCount=1`, `clientOneQueued=1`, and `1:2` had never reached the reducer. The producer was allowed to append one already-returned TDLib update after input close; the reducer could observe closed+empty first, exit its read loop, then wait forever for the queued final event.
- Source `7fd003088e2593fc2b808f7903e8f8b96c6a1c9b` separates admission close from producer completion. `TDLibUpdateBuffer.take()` now treats EOF only after `TDLibGateway`'s receive worker calls `finishInput()` on exit. The final accepted update is therefore read before the reducer closes its drain barrier.
- Local focused stress passed 20/20 repetitions for both `twentyClientPipelineStopsBlockedReceiveAndDrainsAcceptedUpdates` and `updateBufferShutdownPreservesCriticalInFlightDeleteAndRejectsLaterInput`. Exact-source GitHub macOS CI [38514102824](https://github.com/AffPapa/NeTelegram/actions/runs/38514102824) passed all 167 tests in 0.860s; the repaired regression passed in 0.012s. The simplified workflow used one full serial test process.
- Checkpoint fields now distinguish latest app source `7fd0030` from the one running canonical Dev.app at `4dcddcc`. A stale `current_native_smoke` pointer to `aab6a4a` was moved to an explicitly historical record; the current pointer now reflects the actual canonical bundle. The older `e7cc4b3` candidate is also labeled historical.
- CUA still reports the canonical NeTelegram Dev.app running. No replacement bundle or second app was created; native smoke for 7fd0030 remains pending normal Quit. No real Telegram accounts, Site deployment, app release, Developer ID signing, or notarization occurred.

## 2026-10-14 — APP16 checkpoint and public Site v174

- Exact-source app SHA `7fd003088e2593fc2b808f7903e8f8b96c6a1c9b`: local shutdown regressions passed 20/20 each; hosted macOS CI `38514102824` passed 167/167. No test/build rerun was needed for this documentation-only Site/checkpoint update.
- Public Site source `93ec41836897aac6fd66ad3374790ef23c40d281`; version 174 `appgprj_6acba85192e08191acdf7011928848cf~appgver_ff8218e6295c81919a51ca8f77a0660d`; deployment `appgdep_6acf0d6864e88191b5061f877231e89b` succeeded. Archive `/private/tmp/netelegram-site-v174.tar.gz`, SHA-256 `d81a20b95c017f4d945d9671460bc5ba96442a50629b2e4cc9f537df9701cdda`; Sites stored hash `sha256:60f554092d6e85d20eb14e918da73cd8033da3f72328af99e0e2da2aaf160daf`.
- Targeted Site validation passed all 8 static routes; anonymous in-app browser confirmed the new `/devlog/` entry and exact CI result. No app binary/download exists; accountless app, real login, 20-account runtime certification, Developer ID/notarization and compatibility gates remain open.
- Efficiency rule for the next slice: reuse this exact-source PASS; wait for the one canonical Dev.app to quit normally, rebuild only that bundle once from 7fd0030, and perform one native launch/reopen smoke. A Site-only edit does not trigger app tests or rebuild.

## 2026-10-14 — Acceptance pointers reconciled; official API compatibility gates rechecked

- Corrected the stale top-level `ACCEPTANCE.json.status` and nested v173 Site pointer to match current app-source `7fd0030` evidence and public Site v174. `PROJECT-STATE.json` and `ACCEPTANCE.json` now agree on the current Site deployment and next action.
- Rechecked the primary Telegram Terms and sponsored-message specifications. Terms §1.3/1.4 state a broad basic-functionality requirement without an exhaustive checklist on that page. §2.3 conflicts with the user-required public product name `NeTelegram` unless “Unofficial” precedes Telegram. §3.3 requires channel sponsored messages; video playback has a separate fullscreen/timed-ad flow. User declined a player, so channels and stable compatibility remain deferred. No legal certification or compatibility PASS is claimed.
- This was documentation/evidence reconciliation only; no Swift test or app build was repeated.

## 2026-10-14 — one canonical Dev.app rebuilt and opened

- Reconciled the stale checkpoint: the old 4dcddcc app was normally quit; `Scripts/check-app-process.sh` uses LaunchServices to positively detect a running bundle when `pgrep` cannot read the process list; an empty restricted-namespace result fails closed and cannot authorize replacement. Six focused tests cover running/definitive absence/fallback/error outcomes.
- The canonical app-source SHA remained `7fd003088e2593fc2b808f7903e8f8b96c6a1c9b`; no second bundle or account directory was created. First SwiftPM attempt exposed a protected home module-cache path, so the dev script now stores Clang modules at `/private/tmp/netelegram-dev-swift-modules` and uses SwiftPM `--disable-sandbox` for this trusted local build. Cache-warmed build completed in 0.21 s; bundle executable and TDJSON hashes are in `PROJECT-STATE.json`. `codesign --verify --deep --strict` passed.
- CUA opened `/private/tmp/NeTelegram-Dev.app`; its fresh inventory still shows it running. Shell `pgrep` and `NSRunningApplication` cannot establish process absence in this sandbox, so the rebuilt bundle will not be replaced again until a reliable absence check is available. Window title `NeTelegram · dev 7fd00308`; accessibility tree showed welcome, country selector, phone entry, Continue and QR login. No credentials, account profiles or existing Telegram sessions were used. User previously deferred login, so no auth flow was started.
- Direct shell execution was not treated as GUI evidence: it aborts before AppKit registration, and `open` from this environment returned LaunchServices errors; CUA's native app open succeeded. One diagnostic run and one focused test suite; unchanged 167-test Swift suite and Site deployment were not repeated.
- Tooling changes remain local/uncommitted pending final diff review. Distribution remains blocked by real login/20-account coverage, notarization credentials and explicit Telegram compatibility gates.
- Commit `0e88386f9db97b6a2e044ca91266d6693f1f7818` was pushed to `AffPapa/NeTelegram` main. Metadata validation [38515770379](https://github.com/AffPapa/NeTelegram/actions/runs/38515770379) and pinned TDLib/arm64 Dev.app build plus artifact upload [38515770287](https://github.com/AffPapa/NeTelegram/actions/runs/38515770287) both succeeded for that checkpoint; app-source remained exactly `7fd0030`.

## 2026-10-14 — public Site v175 records Dev.app workflow verification

- The official Sites helper opened the existing public project `appgprj_6acba85192e08191acdf7011928848cf` on its existing source checkout and preserved its provider origin. It pushed exact Site source commit `6794e1c04775930ce779bfe3adc806c96d83ba94`; archive `/private/tmp/netelegram-site-v175.tar.gz`, local SHA-256 `44d480fcefe7b71fd15767626897e3d74dfa5324b07bccdb6865a93c75d3280a`, 192,478 bytes.
- Saved Site version 175 as `appgprj_6acba85192e08191acdf7011928848cf~appgver_7f1f5230cb688191afb604fe43d0be0b`, provider archive hash `sha256:9ad6d7e1e0c1b174701c5e846c099926aaa692c9f32f157d4832a39d4e74f16b`, 14 files. Deployment `appgdep_6acf11bc50e08191a9b7b1cf102155a1` succeeded at `https://netelegram.iryadom.chatgpt.site`.
- Anonymous in-app browser loaded `/devlog/?verify=v175`; the new RU/EN tooling entry, linked app/tooling commits, metadata CI 38515770379 and native TDLib/Dev.app workflow 38515770287 were present. Site source and app-repository `website/` mirror were synchronized and the static validator passed all 8 routes. Downloads were not changed; no binary is available.
- The app-repository mirror commit for the v175 Site source is `64b0a5fe603c09b6ebb70648be74cf47c9169999`; the checkpoint now points the Site receipt to that exact synchronized mirror.

## 2026-10-14 — Faster focused release validation and duplicate-asset guard

- Added a fail-closed rule rejecting repeated artifact kinds, even when their filenames and bytes differ. This prevents a manifest from carrying two app ZIPs (or duplicate SBOM/notice/update archives) while reconciliation silently selects only the first. Added a regression reproducing that ambiguity.
- Tightened metadata CI path filters so edits to `LICENSE` or `NOTICE` run the notice generator and release tests.
- Verification: duplicate-kind test 1/1; release metadata suite 36/36 in 0.867s; checkpoint validation passed; SBOM/NOTICE generators produced valid outputs; `git diff --check` passed. Exact app-source CI 167/167 remains valid because no Swift source or app inputs changed; no native suite or Dev.app rebuild was repeated.
- No release binary or user account was touched. Changes remain unpushed; no hosted CI or Site update is claimed for this dirty tree. Existing public Site v175 remains unchanged.

## 2026-10-14 — Release validation milestone pushed and Site v176 published

- App repository commit [`045ebb1`](https://github.com/AffPapa/NeTelegram/commit/045ebb12762794f3d5d8a5c14fa20be7f403328c) was pushed to `AffPapa/NeTelegram:main` via the existing Git credential helper. The first attempt hit sandbox DNS denial; the same push succeeded through approved network access without creating a token.
- Exact commit metadata workflow [38518330268](https://github.com/AffPapa/NeTelegram/actions/runs/38518330268) succeeded. The 36/36 release-metadata tests passed locally in 0.867s. No Swift source changed, so no Swift suite or Dev.app rebuild was repeated.
- Updated the existing public Site from v175 to v176 using source commit `c414e596b906c04a253d7de4184a0f9cb121f024`; deployment `appgdep_6acf17ae4dd481919d0ad778d0e5b4e5` succeeded at https://netelegram.iryadom.chatgpt.site. The saved archive SHA-256 is `754d0d22d4b4850a4cf7b9170288f738a5785a937eed8d223861c893245234a4`. Anonymous Playwright verified the new RU/EN devlog and exact commit/CI links. App repository `website/` mirror is synchronized in this checkpoint change.
- No application download, release, signing, notarization, real account, or 20-runtime proof is claimed.

## 2026-10-14 — Final app ZIP audit path and faster scoped validation

- Added a macOS-only final-archive verifier to `Scripts/generate_sbom.py`. It validates archive paths, duplicate/encrypted/special entries, one `NeTelegram.app` root, entry count and expanded-size bounds; materializes only regular files/directories in a fresh temporary directory; then runs the existing version/source, arm64, Developer ID, codesign, stapler, and Gatekeeper checks against the extracted archive. Final release audit requires the exact expected Developer Team ID.
- The SBOM now binds the final app ZIP SHA-256 and Team ID. `Scripts/validate_release.py` rejects pre-ZIP SBOM evidence and verifies the frozen ZIP hash plus existing executable/TDLib hashes. `DEPENDENCIES.md` documents this path.
- Targeted tests: 24/24 passed. Full release metadata suite: 39/39 in 0.836s. `Scripts/validate_checkpoint.py`, `git diff --check`, and Python compilation passed. One initial fixture run failed because ZIP hash validation ran before unsafe-path validation; reordered checks and reran the full scoped suite successfully.
- No Swift source or app inputs changed, so no Swift CI/native build/rebuild was repeated. No actual notarized archive exists yet: real signature/stapling/Gatekeeper behavior remains unverified. Changes are local and unpushed; no Site update or app release is claimed.
- Process efficiency rule: select a single workflow by changed paths; reuse exact-source Swift/native PASS while app inputs match; keep metadata-only changes on the sub-second release suite and metadata CI. Do not build or launch alternate Dev.app copies.

## 2026-10-14 — final ZIP audit milestone on public Site v177

- Exact app-repo release-tooling commit `428f49d8963a799c71fcf05ec4eb8fdfa31808ad` was pushed to `AffPapa/NeTelegram:main`; metadata CI run [38519326151](https://github.com/AffPapa/NeTelegram/actions/runs/38519326151) succeeded. Local release suite passed 39/39 in 0.836s.
- Existing Site source commit `91b55f7c126a38ec45589a3df77a018f86507e13` was saved as public Site v177 (`appgver_23739e6db4c08191a694a5227663cf99`) and deployed as `appgdep_6acf1a592a648191be4109bc1abe6290` at https://netelegram.iryadom.chatgpt.site. Archive `/private/tmp/netelegram-site-v177.tar.gz`: SHA-256 `497cd3962e664121dbb6fad1e1413c2d2fbdf44851efe8c2ffc982f3761b1464`, 193748 bytes; provider stored hash `sha256:f6c8ffb77269af1a9c53e13abc460f808bc3faa778ae9b20ba96c878b58e8272`, 14 files.
- Anonymous Playwright confirmed the bilingual entry and exact commit/CI on `/devlog/`. `/downloads/` remains explicitly no-release/no-download with the compatibility gates visible. The static validator passed all eight routes.
- Site source helper initially hit sandbox DNS; one retry accidentally used an incorrect project ID and was rejected before any action. The next attempt supplied the correct project ID but stale base commit and was rejected; inspection showed the helper had already created local source commit `91b55f7` before network failure. Re-running the supported helper with the exact current HEAD and same existing Site credential pushed and packaged the source successfully. No new Site or remote was created.
- App repo `website/` mirror and checkpoints now record v177 and CI. This checkpoint-only follow-up does not change app source; real signed archive, notarization, account login/20 runtime coverage and stable compatibility remain open.


## 2026-10-14 — close final-ZIP audit snapshot gap

- Independent read-only review found that the auditor extracted a ZIP and then reopened the source path to compute its SBOM digest. A concurrent replacement could therefore make the digest describe bytes different from those actually audited. It also found that candidate validation applied weaker structure checks than the signing audit.
- The final ZIP auditor now rejects symlink inputs, copies and hashes through one open file descriptor into a private snapshot, checks the descriptor metadata did not change during copying, and extracts/audits only that snapshot. The same digest is recorded in the SBOM.
- SBOM generation and candidate validation share one fail-closed archive validator for traversal, duplicates, encrypted and special entries, exact `NeTelegram.app` root, entry count, and expanded size. Added regression coverage for path replacement during audit and invalid root/symlink members.
- A first focused run found only a test-message wording mismatch; the rejection behavior was already correct. The message was clarified and rerun. Targeted release tests passed 26/26; full release suite passed 41/41 in 1.803s; checkpoint validation, Python compile, CLI help, and `git diff --check` passed.
- No Swift/app source changed; the current exact-source Swift PASS and canonical Dev.app remain reusable. No native build, real archive signing, login, or actual ZIP audit was performed; the archive tests use fixtures.

## 2026-10-14 — final-ZIP audit fix on public Site v178

- Exact app tooling commit `abdf2268fbbfdf052980d97cfd53e62ba285c45d` passed GitHub Metadata validation [38520311093](https://github.com/AffPapa/NeTelegram/actions/runs/38520311093). Its local focused suite passed 26/26 and full release suite 41/41 in 1.803s.
- Existing public Site project `appgprj_6acba85192e08191acdf7011928848cf` saved source `e1c1209264878e54ba4f9259c102dd52dc14e423` as v178 and deployed successfully as `appgdep_6acf1c9813788191b4e17f6f6ae951d6` at https://netelegram.iryadom.chatgpt.site. Exact source archive `/private/tmp/netelegram-site-v178.tar.gz`: SHA-256 `0f2bc60ba81cbe8e50449dbd5563edf0fe5ca6bc5657a93e0cf8dca6911d1c7c`, 194323 bytes; saved archive hash `sha256:120e0e040a407d0e3eabf2bb52557c3a75d88085032fb3d3795bf979ae182126`, 14 files.
- Anonymous Playwright found the new bilingual entry and exact commit/CI on `/devlog/`; `/downloads/` still states no installable build and no download button. The Site uses the existing project and public audience. Its source mirror and receipts were committed to the app repository in `09a61d7`; exact checkpoint metadata CI [38520743180](https://github.com/AffPapa/NeTelegram/actions/runs/38520743180) succeeded.
- No app release, signed/notarized binary, real Telegram login, or 20-runtime certification was performed. No Swift source changed and no Dev.app rebuild was needed.

## 2026-10-14 — Fail closed on unknown photo download capability

- Source commit `05cfe67130b6c796a2baad062393158101a99c08` changes `PhotoFileVariant` so a missing TDLib `local.can_be_downloaded` flag is false. The AppKit preview action rechecks the captured capability immediately before dispatching `downloadFile`; missing or stale permission cannot trigger a request. Incomplete local files remain not downloaded.
- Focused regression passed 1/1; full local serial suite passed 168/168 on arm64e / Xcode beta / Swift 6.4 (0.459s). Exact-source GitHub macOS CI [38521289189](https://github.com/AffPapa/NeTelegram/actions/runs/38521289189) passed 168/168 in 0.940s.
- No real Telegram account/photo, memory-pressure, or content-protection test was performed. The canonical Dev.app remains at 7fd00308; no replacement bundle or native smoke is claimed. APP20 remains partial.

## 2026-10-14 — Publish photo-permission evidence to the existing Site

- Existing public Site project `appgprj_6acba85192e08191acdf7011928848cf` advanced to v179 from exact Site source `df96ad6548a39c5ad45f5330437ca1554fc3305d`. Anonymous `/devlog/` verification found app-source `05cfe67130b6c796a2baad062393158101a99c08`, Russian and English text, and the exact macOS CI link 38521289189.
- Static validation passed all 8 routes. The v179 saved archive hash is `sha256:587478812d3e08decbf163d91cd55b4036eead856509365aee83483348bcb004` (14 files); deployment appgdep_6acf1f6cc66c8191b7ba93f18a99bf8d succeeded. Downloads page and updater feeds were not changed; no installable binary is claimed.

## 2026-10-14 — Confirm the existing Git publication route

- The authenticated GitHub connector confirmed the existing `AffPapa/NeTelegram` repository and push permission. `gh auth status` reported invalid stored tokens for both configured accounts, so neither CLI credential was used or changed. The already-configured Git credential helper successfully fetched and pushed the authorized `main` commits after approved network access resolved sandbox DNS restrictions. No new token was created. Exact metadata CI 38521890229 passed for the v179 checkpoint commit.

## 2026-10-14 — Report explicit photo opens to TDLib

- Source commit `870b8946eb6441955e035084f099dcacef04a99b` now sends TDLib `openMessageContent` only after the user explicitly reveals a photo and its preview decodes successfully. Automatic history previews do not send this command. The intent captures account, verified Telegram identity, runtime generation, and privacy epoch; lock, chat reset, deletion, and download-start failure clear pending intents.
- Focused regression `photoContentOpenIntentIsBoundToRuntimeAndPrivacyEpoch` passed 1/1. One initial local full-suite run produced two transient Keychain concurrency timeout assertions; the isolated test passed in 0.116s, and explicit serial `swift test --no-parallel` passed 169/169 in 0.456s. Exact-source macOS CI [38522612798](https://github.com/AffPapa/NeTelegram/actions/runs/38522612798) passed.
- No Dev.app rebuild/launch, real Telegram account/photo interaction, or Site deploy was performed. APP20 remains partial; existing Dev.app remains at `7fd00308` pending normal quit and confirmed process absence. Signed release and all real-account/20-runtime gates remain open.

## 2026-10-14 — Photo-open milestone published on Site v181

- Existing public Site project `appgprj_6acba85192e08191acdf7011928848cf` deployed v181 as `appgdep_6acf22a6ef708191a9feb161801806fd` at https://netelegram.iryadom.chatgpt.site. Site source commit `a82cfec5bdc0fcc692fcaa31138bd034fd2a0554` packages app-source `870b8946eb6441955e035084f099dcacef04a99b` and CI run 38522612798.
- The saved archive hash is `sha256:0ae9aff0edb92c06ef617e3718c3c6a1731b658c100d50e8d2eb58d1fa3e2a1e` (471,040 bytes, 14 files). Its local archive SHA-256 is `f697112cea236776e47a55561003784eae68384292b5ffae79ea3b78f0062048`; archive inspection confirmed the exact commit is in `dist/devlog/index.html` before saving.
- Anonymous Playwright verified the bilingual entry, test result and CI link. All 8 static routes validated; downloads were not changed and still offer no binary. An earlier saved v180 archive contained stale `dist`; it was never deployed. v181 includes the rebuilt pages. No application release or signed download is claimed.
- The app repository receipt for Site v181 and the exact source/CI evidence was committed as `5bb20b9c760d88427a28d135e0b4167dbd6ce1c2`; its metadata validation CI [38523210998](https://github.com/AffPapa/NeTelegram/actions/runs/38523210998) succeeded.

## 2026-10-14 — Exact APP20 Dev.app rebuilt and lifecycle-smoked

- After normal Quit, `Scripts/check-app-process.sh NeTelegram org.affpapa.netelegram.dev` returned the documented definitive no-process status. The one canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt in place from clean app-source `870b8946eb6441955e035084f099dcacef04a99b` in 26.58s; no second bundle was created and build did not auto-launch.
- BuildInfo records fingerprint `6354d9a53c4db19f7f747ae4bc45bfa865cc34453ab256cbd841a944df5875cc`; executable SHA-256 `51b3fb618043acd3e455a14a98096c09a482678cad43b53ddc7749a2b81534bf`; pinned TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. `codesign --verify --deep --strict` passed for this ad-hoc development bundle.
- `Scripts/window-lifecycle-smoke.sh` passed on the clean accountless support root: PID 71819 launched with one window, remained the same PID with zero windows after closing the last window, reopened through LaunchServices as one window, and exited through normal Cmd+Q. Process absence was confirmed afterward. No account credentials were entered. This does not prove Telegram photo delivery, real login, Developer ID signing, notarization, or stable release.

## 2026-10-14 — Safe composer keyboard send

- Added Cmd+Return sending from the focused composer only when the current Send button is enabled. Plain Return stays an editor newline. IME marked text, privacy lock, TDLib receive failure, stale focus, or disabled send state prevent dispatch.
- Focused policy test passed 1/1. Full serial Swift suite passed 170/170 in 0.457s on arm64e / Xcode beta / Swift 6.4. Initial sandboxed SwiftPM attempt could not load the macOS SDK module cache; rerunning with the required build permission passed. No app bundle rebuild or account login was needed.
- Source commit `87c0c06560ac0986f7e004d6578b1e3b034c9244` was pushed to `AffPapa/NeTelegram:main`; exact-source macOS CI [38524122936](https://github.com/AffPapa/NeTelegram/actions/runs/38524122936) passed. The one canonical arm64 Dev.app was rebuilt from that exact source; BuildInfo fingerprint `3bed580518b79f64cc21ddb0ac92891e6df3e1a4a4bacb28795b7bcdff8220d0`, executable SHA-256 `baacd5d3a61d628bb058c34a41778883918668b09f25b350d343cd970b69c97d`, pinned TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; strict ad-hoc signature verification passed. No Site deployment yet; no real-account behavior is claimed.
- Exact-source native lifecycle smoke was then run on the single canonical bundle: last-window close, LaunchServices reopen in the same PID, and normal Cmd+Q all passed. No Telegram credentials or profiles were used.
- Public Site v182 deployed from Site source `c7dcd0bb0bfe539ab41bdc68a101f7b5ec582966` as `appgdep_6acf26dd78c48191800ab199010ae77d`. Saved version `appgver_e3046b7aafcc819184cfded1ba1a5314`; provider archive hash `sha256:0f8ba4305d0ae7587bac2673956b1fd22924b7938bd1754cabea93ac142383a7` (471,040 bytes, 14 files); local archive SHA-256 `1826a14c3b77b87c886e47d39d6947861d4572d63fb952e087501653cf698e99` (195,740 bytes). Anonymous Playwright verified the bilingual devlog entry, exact source/CI links, and that downloads still has no installer or ZIP/DMG link. Site validator passed all 8 routes. This is a development milestone, not an app release.
- Checkpoint commit `6bc7bdb4661c585b3661abcf784688b6a6ad1ac3` passed GitHub Metadata validation [38525055679](https://github.com/AffPapa/NeTelegram/actions/runs/38525055679). `Scripts/validate_checkpoint.py` also passed locally and the working tree was clean before recording this CI receipt.

## 2026-10-14 — Explain local account entries and fail closed on Keychain UI

- Source `fc4485b174b61fb14a085fea67d41a2b2606ef2e` changes pending-profile selection status to explain that it is a local NeTelegram entry and that sessions from other apps are not imported. UUIDs remain storage identifiers and are not shown as account names.
- A focused Keychain test exposed that the current macOS 27 runtime returns `LAContext.interactionNotAllowed == false` even after setting it true. The source keeps the documented LAContext guard and adds Security's explicit fail-closed UI mode as a compatibility guard for legacy login-Keychain reads. Apple documents the LAContext property and the fail-on-interaction behavior; the test checks query configuration only, not an actual protected Keychain item.
- Profile-origin and Keychain-query focused tests passed 1/1 each; the serial local suite passed 171/171 in 0.481s. Exact-source macOS CI [38526833332](https://github.com/AffPapa/NeTelegram/actions/runs/38526833332) passed.
- The canonical Dev.app remains running from prior source `87c0c06560ac0986f7e004d6578b1e3b034c9244` on its secure API hash configuration dialog. It was not closed or replaced; rebuilding this same bundle waits for normal quit and confirmed process absence. No secret value was inspected, no Telegram account was logged in, and no real-account or 20-runtime result is claimed.


## 2026-10-14 — Public Site v183 and faster verification routing

- Published the bilingual APP23 devlog entry for source `fc4485b174b61fb14a085fea67d41a2b2606ef2e` and exact-source macOS CI `38526833332`. Site source commit `6f5abe1d092e0a49abe64d83bf95bafea72563f3`; saved version `appgver_4f6aecf4f2c08191a8909f44ff72f890`; public deployment `appgdep_6acf2d5e5d88819183e2040eba051b4c` succeeded. Anonymous Playwright confirmed the entry and source/CI links on `/devlog/`, and confirmed `/downloads/` still has no app download. The 8-route validator passed. No Swift tests were rerun because app source did not change; the existing exact-source 171/171 and CI receipts remain applicable.
- Workflow speed rule: Swift changes get one focused regression while debugging, then one final serial suite and one exact-source CI; metadata-only changes use checkpoint/metadata validation; rebuild the one canonical Dev.app only after its old process exits and its source fingerprint changes; rebuild pinned TDLib only when its pin/build inputs change. Real login, 20-account load, signing/notarization, and Gatekeeper remain separate acceptance gates.


## 2026-10-14 — Current-source AppKit executable compile

- The current app source `fc4485b174b61fb14a085fea67d41a2b2606ef2e` compiled as SwiftPM product `NeTelegram` in 5.01s using the existing canonical development build scratch cache. This fills the gap left by the Core-only test CI without rebuilding TDLib or replacing/opening a second Dev.app.
- Build passed with SwiftPM cache-permission warnings and the existing macOS 11 deprecation warning for `kSecUseAuthenticationUIFail`. This is compile evidence only. The single canonical Dev.app still runs source `87c0c06560ac0986f7e004d6578b1e3b034c9244`; exact-source native bundle/UI smoke waits for its normal exit.

## 2026-10-14 — Make canonical Dev.app process guard diagnostics explicit

- `Scripts/check-app-process.sh` now prints the PID(s) returned by `pgrep`; the LaunchServices fallback names the detected NeTelegram bundle, and an empty fallback explicitly says absence could not be proven. `Scripts/dev-app.sh` displays that evidence when refusing to replace a running bundle.
- Focused process-guard tests passed 6/6; the full release metadata suite passed 41/41 in 1.136s. `bash -n` and `git diff --check` passed. No Swift source/fingerprint changed, and no app build or Swift test rerun was needed.
- A live elevated check reported NeTelegram process PID 79726; the canonical Dev.app remains on app-source `87c0c06560ac0986f7e004d6578b1e3b034c9244`. The guard correctly prevented replacement. No account or API-hash field was inspected.
- Exact pushed checkpoint `4b8b6bd10b5f352920bdc4dfe9feae774f836684` passed metadata CI [38529572875](https://github.com/AffPapa/NeTelegram/actions/runs/38529572875) and pinned TDLib/isolated Dev.app workflow [38529572922](https://github.com/AffPapa/NeTelegram/actions/runs/38529572922). The workflow verified the CI bundle path; it did not replace the user's local canonical bundle or exercise a Telegram account.

## 2026-10-14 — Search results preserve typed topic; public Site v184

- App-source commit `be67983189915d5a45263bc7fd90691455d3b260` now preserves the selected account/topic when opening search results, clears stale per-chat topic state, and loads history around the matched message. It handles main chats, forum topics, message threads, direct-message topics, and Saved Messages topics.
- Local serial Swift suite passed 171/171 in 0.458s; SwiftPM compiled the AppKit executable target. Existing `conversationHistoryRequestsPreserveEveryTypedTopic` coverage passed. Exact-source macOS CI [38530263569](https://github.com/AffPapa/NeTelegram/actions/runs/38530263569) passed. Native search interaction and real-account search were not exercised.
- The one canonical Dev.app was not rebuilt: it remains recorded at source `87c0c06560ac0986f7e004d6578b1e3b034c9244`; the process guard could not prove absence. Do not open another bundle. Rebuild in place only after normal quit and a positive absence check.
- Existing public Sites project `appgprj_6acba85192e08191acdf7011928848cf` deployed v184 (`appgdep_6acf343224788191936cfcaaca4a4c2b`) from source `c8fb20949a5805bde05edc13d9b1e70b9c5fced8` at https://netelegram.iryadom.chatgpt.site. The first publish push was rejected because Site source had advanced from the opening checkout; no force push was attempted. A fresh Site checkout was opened at the current remote base and the exact devlog entry was reapplied. Archive SHA-256 `7a650837db99b803e67def616276d896a3daff58ca44015e634c1546dc2a5808`, 197066 local bytes; saved archive hash `sha256:7886a2858aa6d6b78170226e0d38b0d27a19508aa3c1fe1ba1a9afc5995d4a65`, 14 files.
- Static Site validation passed all 8 routes. Anonymous system-curl checks returned 200 `text/html` for `/devlog/` and `/downloads/`, and 200 `text/xml` for `/updates/stable.xml` and `/updates/alpha.xml`; exact source marker is public and Downloads still offers no binary.
- No real Telegram login, authorized 20-runtime test, notarized build, app release, or updater archive was created.

## 2026-10-14 — Forum search results keep their topic; public Site v185

- A second-pass review found that a forum result could still fall back to main chat history when its chat had not been cached as a forum. App-source commit `7683cc6bace702b3376a08a9a2aaf4aaf881a691` adds a typed `SearchResultNavigationPlan` and marks a forum chat before `openChat` selects its history request.
- Focused `searchResultNavigationKeepsForumTypeAnchorAndAccountIdentity` passed 1/1; local serial Swift suite passed 172/172 in 0.471s. Exact-source macOS CI [38531844985](https://github.com/AffPapa/NeTelegram/actions/runs/38531844985) passed. The test covers typed topic classification, the matched-message anchor, and equal chat IDs isolated by account. It does not exercise AppKit against a real Telegram account.
- An elevated process check confirms the single canonical Dev.app is still running as PID 79726 from source `87c0c06560ac0986f7e004d6578b1e3b034c9244`. No second app bundle was opened or built. Rebuild the canonical bundle only after normal quit and positive process absence.
- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf` deployed v185 (`appgdep_6acf3695e7ac8191afa6d7c4e08fa650`) from source `06b0328911292a281e0f0e9dffd38c9982084c8b` at https://netelegram.iryadom.chatgpt.site. Archive SHA-256 `17e320005bb09f534294503466ba253a1eedc6cfb875f32056e8c106713cbab9`, 197486 local bytes; saved archive hash `sha256:b420c00d5125c46968b2d62d592b97333cff16a413f7f4f3653a8f29196697c6`, 14 files.
- Static validation passed all 8 routes. Anonymous checks returned 200 `text/html` for `/devlog/` and `/downloads/`, and 200 `text/xml` for `/updates/stable.xml` and `/updates/alpha.xml`. The devlog links exact source and CI; downloads still has no binary.
- No authorized account search/login, 20-runtime certification, notarization, Gatekeeper or app release was performed.


## 2026-10-14 — Release preflight refreshed without reading credentials

- Fresh local signing check reported four valid code-signing identities, including two `Developer ID Application` identities for team `H6VGU2M6JD`. This confirms signing identities are available in this macOS account; it does not prove that a particular app bundle is correctly signed. No binary was signed.
- Xcode is selected from `/Applications/Xcode-beta.app/Contents/Developer`; `notarytool` 1.1.3 (42) is installed and Gatekeeper assessment is enabled. A non-secret Keychain-item existence check for `com.apple.gke.notary.tool` returned absent or inaccessible. No credential value/profile secret was read and no notarization submission was attempted.
- The canonical Dev.app remains running as PID 79726 from `87c0c06560ac0986f7e004d6578b1e3b034c9244`; current source `7683cc6bace702b3376a08a9a2aaf4aaf881a691` still awaits normal quit and positive process absence before in-place rebuild.
- No app source changed, so no Swift tests, app build, Site deployment, or app release was repeated.

## 2026-10-14 — Reject stale pending native candidate pointers

- A checkpoint review found that `ACCEPTANCE.current_evidence.local_dev_app.pending_source_commit` still named `fc4485b` while APP26 and `PROJECT-STATE.pending_native_candidate` named `7683cc6`. The existing checkpoint validator did not compare that duplicate pointer.
- `Scripts/validate_checkpoint.py` now requires both current checkpoint records to name the same pending app-source SHA whenever the canonical Dev.app is behind. Updated the stale APP26 pointer and the process-state sentence; the canonical bundle itself was not touched.
- Added `test_pending_native_source_must_match_both_checkpoint_records`. Targeted checkpoint-validator tests passed 6/6, `Scripts/validate_checkpoint.py` passed, and `git diff --check` passed. No Swift build/tests, app launch, Site deployment, or release were needed.

## 2026-10-14 — One-pass public status refresh and duplicate-CI guard

- Updated only the homepage and `/features/` current-status blocks to APP26 `7683cc6`, focused test 1/1, serial suite 172/172, and exact-source macOS CI `38531844985`. Removed obsolete `4d6820d`/`752f684` and old local Dev.app claims. Kept real-account search, 20 real runtimes, current native rebuild, signing/notarization, and downloads explicitly unverified/unavailable.
- Built and validated all 8 static Site routes once in the official source helper flow. Pushed Site source `85306a1f88eb6a021a663ab0bb76e00a11caef27`, saved public Site v186, then deployed successfully as `appgdep_6acf3b400b208191bf01b0c5b62a0ced`. Anonymous HTTPS returned 200 `text/html` for `/`, `/features/`, `/devlog/`, `/downloads/`, and 200 `text/xml` for both update feeds. No application binary was added.
- Reconciled the duplicated `source.latest_exact_commit_ci` pointer with current APP26 exact-source evidence, Site receipts across both checkpoint files with v186, and added a validator guard plus regression test so the stale duplicate fails validation instead of misleading the next resume.
- Targeted checkpoint tests passed 7/7; `Scripts/validate_checkpoint.py` and `git diff --check` passed. No Swift suite, TDLib build, Dev.app rebuild, or app CI rerun was needed because app-source inputs did not change.
- Next: after the one running stale Dev.app exits normally and absence is positively checked, rebuild that same bundle from `7683cc6` and run the narrowly scoped native lifecycle/search smoke. Real login remains deferred; no credentials were entered. Site v186 and current source checkpoints are separate identities.


## 2026-10-14 — Remove ambiguous native build pointers from resume checkpoint

- The single current Dev.app pointer remains `local_development_candidate`; six duplicated `verification` entries referred to older builds while their keys implied `current`, `latest`, or `last`. Renamed those receipts with explicit `historical_*` keys. Their detailed evidence remains in this append-only run log.
- `Scripts/validate_checkpoint.py` now rejects those ambiguous key names, with a focused regression test, so an old bundle cannot silently look current during resume. No source, app bundle, release asset, or Site was changed.
- Targeted checkpoint validation and the Python metadata test are the only required checks for this metadata/tooling slice; no Swift suite, app rebuild, app launch, or Site deployment is needed.
- Publication attempt: the Git transport failed before authentication because `github.com` DNS resolution failed. The connected GitHub integration could read the repository but returned 403 `Resource not accessible by integration` for Git blob creation. No remote ref changed; local commit remains pending. `gh auth status` reported the cached `mrdumay-source` and `AffPapa` sessions invalid. No new token was created and no browser flow was opened.

## 2026-10-14 — Keep one actionable resume pointer

- Removed superseded nested `next_action` strings from milestone receipts in PROJECT-STATE and ACCEPTANCE. Each file now has one root action, and `Scripts/validate_checkpoint.py` rejects a nested duplicate so resume instructions cannot quietly diverge.
- Updated the stored GitHub access diagnosis to the observed state: GitHub connector reads work, its blob write is denied, Git transport DNS fails, and cached `gh` sessions are invalid. No credentials were created and no remote ref was changed.
- Revalidated the current Site independently: public Site v186 and its pages/feeds remain live and factual for APP26; no Site change is needed for this checkpoint-only cleanup.


## 2026-10-14 — APP26 canonical Dev.app and lifecycle smoke

- Resolved the stale resume pointer: the canonical `/private/tmp/NeTelegram-Dev.app` is now built from exact app-source `7683cc6bace702b3376a08a9a2aaf4aaf881a691` (APP26), arm64, macOS 14 baseline, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Build completed in 26.74s. `codesign --verify --deep --strict` passed for ad-hoc development signing. BuildInfo SHA-256 `1c707665774882ec185dc0019e83c0dd0be4bf78c6088500272a73279dbd2292`; executable SHA-256 `339f7dad934f4cd658573dcb26b291b19ad4cc781853a365ef5ffc4cb4735f0e`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1.
- CUA showed the accountless welcome and phone/QR authorization UI. No phone, OTP, API hash, profile selection, or Telegram session was entered.
- Accountless lifecycle smoke passed: close-last-window left the process alive; LaunchServices/Dock reopen restored one window with the same PID; Cmd+Q exited; elevated process guard then confirmed absence. Receipt: `/private/tmp/netelegram-app26-lifecycle-0f71d8b.json`. A broad diagnostic screenshot exists locally but contains unrelated desktop content and is not suitable for publication.
- The exact checkpoint commit `0f71d8bd2bf25b432b2bd2a1ddf81fa711cf5ced` was pushed and metadata CI run `38537039886` passed. This new checkpoint replaces the obsolete claim that the old app/PID was still running.
- Updated the canonical `local_development_candidate` and APP26 acceptance evidence; removed the stale pending-native-candidate pointer. Real login/search, 20 authorized runtimes/resource measurements, Developer ID release signing, notarization, Gatekeeper, updater and public downloads remain open.


## 2026-10-14 — Site v187 publishes APP26 native lifecycle evidence

- Existing public Site project `appgprj_6acba85192e08191acdf7011928848cf` reused; no second Site created. Official Sites source helper opened the returned checkout, committed/pushed source `b676e0f33ef66fe6a9b5ebd279e6f1ee50666e17`, built all 8 static routes, and passed `validate_site.py`.
- Saved Site version 187 from the pushed source and exact 14-file archive (`sha256:9ba2889113b0283f7e93ceeb5c975bdf04378b6d2d1e85f55c985f8dc01824b`; stored 481280 bytes). Deployment `appgdep_6acf42e795b4819198da2c7ee7bf0de2` succeeded at https://netelegram.iryadom.chatgpt.site.
- Anonymous macOS system-curl verification: `/devlog/` 200 `text/html`, 256336 bytes with APP26 RU/EN lifecycle entry; `/downloads/` 200 `text/html`, 5722 bytes; `/updates/stable.xml` 200 `text/xml`, 421 bytes and states no stable release. No download button or appcast asset was invented.
- A Python urllib check failed because its bundled CA store rejected the chain; system curl using macOS trust passed.
- Site archive local SHA-256 `af5ca21c0b015a58804562b6263c9a8828fe47a2164aa491f3b5feff890e26af`, 197516 bytes. Site source, Site version/deployment, app-source SHA, and app bundle remain separate identities.


## 2026-10-14 — APP15 reports quit-barrier rejection cause; Site v188

- App-source commit `cb44d07206fdcc9a9a8a2de2dbe33f4fd5559006` adds `RuntimeShutdownRejection` and `beginReportingRejection`: duplicate quit during an active shutdown and an already-finished barrier produce distinct user-visible status. AppKit retains existing draft/close safety barriers and does not send duplicate close commands. It does not establish the cause of the earlier AppleScript `-128`.
- `terminationCancellationReportsCauseAndPreservesBarrier` passed 1/1; the full serial suite passed 173/173 in 0.446s; exact-source macOS CI `38539001790` succeeded. Canonical arm64 Dev.app rebuilt once in 5.13s; ad-hoc strict codesign passed. CUA showed phone/QR login with no account inputs. Lifecycle smoke passed last-window close, same-PID LaunchServices reopen, normal Cmd+Q and positive process absence. Receipt: `/private/tmp/netelegram-app27-quit-cancel.json`.
- Existing public Site project reused; Site v188 source `501c593c57a22a48edc066904af6d21fbba50af1`, deployment `appgdep_6acf4550326081919cec7377782b451a` succeeded. Home, features and devlog now agree on APP15 `cb44d07`, 173/173 and CI `38539001790`. Anonymous routes `/`, `/features/`, `/devlog/`, `/downloads/` returned 200 `text/html`; stable feed returned 200 `text/xml` and has no update item. No installer link was added. Saved Site archive hash `sha256:c4410d2210b1836b5a79e7d95946c35ade0d612d135e6ba07d8032de55299cf6`, 481280 stored bytes; local archive SHA-256 `def952ac0eeb14a556ae07d0d335558051a85ee47f27755809f9903f1da197ed`, 198296 bytes.
- Checkpoint validator and its 10 focused tests pass. Real-account auth and 20-account lifecycle/resource coverage remain unverified; this slice stays partial.


## 2026-10-14 — AUTH03 native authorization layout preview; Site v189; workflow error guards

- App source `0ab1fecb60b5beaa40c4bd2655735725927edc8a` adds a DEBUG-only local preview for phone, code, 2FA, QR, and registration. CUA on the canonical `/private/tmp/NeTelegram-Dev.app` at 900×700 showed all fields, status, help, and actions visible on all five states. The synthetic preview blocks TDLib requests and bypasses profile restoration. This verifies layout only; no real Telegram account or VoiceOver/IME/RTL coverage. The app was quit and process absence confirmed.
- Standard serial Swift suite passed 173/173; exact-source macOS CI run `38541341263` succeeded. A prior default-parallel run produced two timing failures in stress tests; the declared serial command is the validation path. No tests were edited.
- The Site source helper first failed before changing source because sandbox DNS could not resolve its configured Git host. Re-running the same official helper with authorized network access opened the existing source checkout; no origin was changed and no direct Git workaround was used. Static build rendered 8 routes and `validate_site.py` passed. Site source `5556c2b7a84d61d60fc4ff6619eaefa60bcca973` was saved as public v189 and deployment `appgdep_6acf4a14c09c8191a779f5ce9b418218` succeeded at https://netelegram.iryadom.chatgpt.site. Anonymous checks: `/devlog/` 200 `text/html`, exact app SHA and CI present; `/downloads/` 200 and no release URL; `/updates/stable.xml` 200 `text/xml` with no update item. Site archive `/private/tmp/netelegram-site-auth03.tar`, SHA-256 `0d808dd8c6941009b8d12258115c990ade7a388302e9b4ecc417c203318247a6`, 198,892 bytes; provider content hash `sha256:75d32fc175bdb7306400805feeabc58d7c20a5d72c2a2a42c08002e0518f6d35`, 14 files / 481,280 bytes. No app download was added.
- Updated current acceptance/project checkpoints to app SHA `0ab1fec`, Dev.app hashes, Site v189/source/deployment, and next action. `Scripts/validate_checkpoint.py` passed; all 10 `Tests.release.test_validate_checkpoint` unittest cases passed. An initial attempted `pytest` command was unavailable; the test file declares `unittest`, which passed.
- Added secret-free durable workflow safeguards: use serial tests; LaunchServices/CUA for GUI launch; one canonical Dev.app; official Sites helper with one authorized-network retry after sandbox DNS failure; narrow tool metadata queries; and no repeated tests/builds when exact inputs are unchanged. Real login remains deferred, 20-runtime evidence is open, and no public app release exists.

## 2026-10-14 — AUTH04 adds static VoiceOver announcements for auth failures

- App source `0666ff8cb7a40ed5203847f9cfdea088cb4480fe` maps only eligible phone/code/2FA/email/registration submission errors to fixed localized announcements. The AppKit auth window posts `NSAccessibility.announcementRequested` at medium priority; no raw TDLib failure or entered value is included. Generic network/status churn remains silent. The test `authenticationFailureAnnouncementsAreStaticAndLimitedToSubmittableSteps` passed 1/1; the standard serial Swift suite passed 174/174; exact-source macOS CI `38543010984` succeeded.
- Canonical arm64 `/private/tmp/NeTelegram-Dev.app` was built once from the exact clean app source. BuildInfo SHA-256 `e2336961de941fe4a83b07a20c544d26d81df346045c96083142a3ea5e9f2f50`; executable SHA-256 `0fc24ea776b9a9472c46f64242383d668f3a5833368ddaeb577cbf2c34c53148`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; source fingerprint `13919d6b57172a026a05eef4029c8d2556b575a6b4a7f555d287be7da8bde307`. Ad-hoc development build only.
- CUA showed the accountless native login window and accessibility tree; no credentials were entered. A later quit attempt returned a LaunchServices `procNotFound`; fresh CUA inventory no longer listed NeTelegram Dev, while the process guard returned `unable-to-prove` due restricted process visibility. Therefore quit/process absence is not promoted to PASS. Actual VoiceOver speech/error interaction remains untested. No real login or 20-runtime evidence.
- Site remains public v189 until the AUTH04 factual devlog deployment succeeds. No downloads or update feed content were added.

## 2026-10-14 — Site v190 publishes AUTH04 devlog

- Reused the existing public Site project `appgprj_6acba85192e08191acdf7011928848cf`. Official Sites helper source commit `a9c4bd892b048e177704a217b73150811f42158a` rendered 8 static routes; `validate_site.py` passed. Saved version 190 as `appgprj_6acba85192e08191acdf7011928848cf~appgver_5c5e79aa9ae88191bd1d2944b6799084`; deployment `appgdep_6acf4d260c0081918114116b74441ab2` succeeded.
- Anonymous public checks passed: `/devlog/` 200 `text/html` with exact AUTH04 source/CI and the VoiceOver verification limit; `/downloads/` 200 `text/html` with no application release; stable and alpha feeds 200 `text/xml` with zero update items. No download link or release was created.
- Local archive `/private/tmp/netelegram-site-auth04.tar`, SHA-256 `53af8780ec25d52bcd27396247a6cf8a8629aef5aeb3e08ec5f149bbb98ae2f1`, 199325 bytes. Provider saved content hash `sha256:e60251ece60ec6badd370c4886c8b1461c4ca3396689d92193e9854283792329`, 14 files / 481280 bytes. Site and app source identities remain separate.

## 2026-10-14 — Normalize milestone IDs to avoid acceptance-case collisions

- The previous checkpoint reused `AUTH04` and `AUTH05`, which are already identifiers for different acceptance cases. Renamed the AUTH04 VoiceOver error-announcement slice to `A11Y-ANNOUNCE-02` and the next action to `CORE-RUNTIME-01`; the underlying app evidence, Site v190 and release state are unchanged. `ACCEPTANCE.status` now names Site v190 accurately.
- This is a checkpoint clarity correction only; no app rebuild, Swift suite, or Site deployment was needed. Local checkpoint validator and 10 focused metadata tests are the required checks.

## 2026-10-14 — Repair Site version provenance and prevent checkpoint drift

- Independent read-only audit found four truncated `saved_version_id` copies for Site v190 in PROJECT-STATE and ACCEPTANCE; the exact opaque ID from the Sites save response and RUN-LOG was correct. Corrected all current copies. Also synchronized ACCEPTANCE.current_site_checkpoint and PROJECT-STATE.phase with the verified v190/A11Y-ANNOUNCE-02 state.
- `Scripts/validate_checkpoint.py` now requires every current saved version ID to equal its version ID, the ACCEPTANCE current Site receipt to equal its latest deployment, and PROJECT-STATE.phase to equal the current ACCEPTANCE status. Added three regressions for truncated Site version ID, stale Site checkpoint, and stale project phase.
- Checkpoint validation passed; `Tests.release.test_validate_checkpoint` passed 13/13; `git diff --check` passed. Metadata-only correction; no app build, Swift suite, or Site deployment was needed.

## 2026-10-14 — CORE-RUNTIME-01 fences status writes by client generation

- Independent read-only runtime review found that authorization updates were route-fenced, but `RuntimeCoordinator.setState(_:for:)` could blindly overwrite a newer client generation. Added `setState(_:from:)`, requiring the exact active route; account-level writes are now accepted only before a route owns the account. Migrated startup waiting, route-owned startup cleanup and identity-mismatch closing paths to the route-bound API.
- Regression `staleRuntimeStatusWriteCannotOverwriteNewGeneration` proves that a late old-generation failure is rejected after a replacement client registers, that a route-less error cannot overwrite the live state, and that current-generation state updates still apply. Focused test passed 1/1; full serial Swift suite passed 175/175; exact-source macOS CI `38544483927` succeeded.
- Canonical arm64 `/private/tmp/NeTelegram-Dev.app` was rebuilt once from clean exact source `8d47568a07bc327fc7c6999402002acfc136e4af`, strict ad-hoc codesign passed, and CUA showed the native accountless auth screen under title `NeTelegram · dev 8d47568a`. No profile or credential was used. Executable SHA-256 `34fbd71b8ddba3b18d9feb07ebf2c8cff600c8b2a800444aa21bab2b782e4e3c`; BuildInfo SHA-256 `1a360ace838787905eb6d214cec8802d4d92a10baf2c8d054a40bfb46f166f24`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; source fingerprint `bd4227bf6493eaac5bc600ebb036306120ff0518b271705b6f876b1f8b4ef108`.
- This closes only the status-write identity invariant. Tests use synthetic routes; all-active behavior across 20 real Telegram accounts remains unverified. Site v190 remains live and still documents the preceding A11Y slice pending the next devlog update.

## 2026-10-14 — Site v191 publishes CORE-RUNTIME-01

- Reused existing public Site project `appgprj_6acba85192e08191acdf7011928848cf`. Official source helper pushed Site source `e8ceab0aad040cf1b608aa4d69a38d76792a1a8f`; all 8 routes rendered and `validate_site.py` passed. Version 191 (`appgprj_6acba85192e08191acdf7011928848cf~appgver_7b9cd786af4c8191a82918174db5fb07`) deployed successfully as `appgdep_6acf4fafd0888191952adfafda2610be`.
- Anonymous live verification: `/devlog/` 200 `text/html` includes app SHA `8d47568`, CI `38544483927`, 175/175 and the synthetic/20-real-account coverage limit; `/downloads/` 200 `text/html` retains no-release copy; stable and alpha feeds 200 `text/xml`, zero update items. No application download was added.
- Local archive `/private/tmp/netelegram-site-core-runtime-01.tar`, SHA-256 `d40e31079ef7346944ce17a6aecd9ac282979c80534c8f71e0275bb1c691da45`, 199905 bytes. Provider saved content hash `sha256:997b9c572f685b02772c170ca76cd266d6dcecd15c3a545634eddb4645e19d3b`, 14 files / 491520 bytes.

## 2026-10-14 — CORE-RUNTIME-02 rechecks asynchronous update ownership; Site v192

- Targeted all-active audit found a P1 interleaving: the AppDelegate checked an update route before `await target.consume(object)`, but identity persistence can suspend; after a runtime closed during that await, the callback could continue into picker/status/notification handling before the later coordinator state reducer rejected the stale route. Added `RuntimeCoordinator.isCurrent(_:)` and a second exact-route plus AppDelegate runtime ownership check immediately after `consume` returns, before any downstream side effects. App-source commit: `cea98640b5a307451ba7f9c2fa7238af506d67a9`.
- Focused regression `asyncCallbackRouteOwnershipChangesAfterRuntimeReplacement` passed 1/1; full serial Swift suite passed 176/176. Exact-source macOS CI run `38545776110` succeeded for the same SHA. This test covers synthetic route ownership across close/reopen; it does not suspend real identity persistence or drive an AppDelegate/TDLib interleaving, and it does not certify real login or 20 real accounts.
- Rebuilt only the canonical `/private/tmp/NeTelegram-Dev.app` after CUA observed the prior app running. The user had previously authorized normal close. CUA showed the app closed after the menu Quit action; the elevated process guard returned exit 1 (positive absence) before the single build. Build used arm64, macOS 14 baseline, Swift 6.4, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`; ad-hoc strict codesign passed. Executable SHA-256 `40aa91fe23a0261cb7d8e5effbe95fef80f88c9d121d7d8332d15d5c800071bb`; BuildInfo SHA-256 `6e918d9f917eef40eae7ecd8cadef0cd575367ce6153cfd6cae8e1d867e9e0ad`; build record SHA-256 `a812e6dfa3017e0fcaf162166bdb8aca644253895f1744121cd85ff7793a1b07`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe5e4e172bfc55ab38abc3e68d7842efdc1`; source fingerprint `67a3db4d3f0d43807a589ff634f54b8d5e3f01a1385a37a39046568105e6846c`. CUA showed `NeTelegram · dev cea98640`, clean phone/country/QR auth. No account or credential was entered. The bundle remains open at this screen.
- Existing public Site project reused. Official Sites helper opened and pushed source `76730c47c3f235c03f901cf50fa4e7c64dc18936`; all 8 static routes were rendered and `validate_site.py` passed. Site v192 (`appgprj_6acba85192e08191acdf7011928848cf~appgver_c95f3ca88ce48191aefc67bfddee3338`) deployed as `appgdep_6acf525436508191882050f6f0034708` at the existing public URL. Anonymous GET: `/devlog/` and `/downloads/` 200 `text/html`; stable and alpha feeds 200 `text/xml`, valid RSS, zero items. The devlog records the exact implementation and testing limits; no app download was added. Local archive SHA-256 `61f795f2f9113aef2f414f8f368aeec6c98ddefea4261fb427f6d518af89c39d`, 200572 bytes; saved archive content hash `sha256:3344520149f91ce706292b7ec5900d93c7e8508e6efb0860796d84ebca047b25`, 14 files / 491520 bytes.
- Updated both resume checkpoints to app source `cea9864`, the one canonical current Dev.app, exact CI, and Site v192. Historical smoke pointers were renamed as historical to avoid implying they refer to the current bundle. `Scripts/validate_checkpoint.py` passed; `Tests.release.test_validate_checkpoint` passed 13/13; `git diff --check` passed. Real Telegram login, 20 authorized runtime coverage, resource matrix, Developer ID release signing/notarization, Gatekeeper, updater, and public app downloads remain open.

## 2026-10-14 — Reconcile CORE-RUNTIME-03 checkpoint and retain error guards

- Exact app source `477404afd89378affb9cc21eb6c0e32745cb5091` fixes a real stale-route window: after awaiting `RuntimeCoordinator.isCurrent`, the MainActor callback rechecks both the target route and AppDelegate's client map before side effects. Focused test passed 1/1; exact-source GitHub macOS test job completed successfully in run `38547546152`, while the top-level workflow API still reported `in_progress` at last check.
- Rebuilt and launched the single canonical `/private/tmp/NeTelegram-Dev.app` once from `477404a`; strict ad-hoc signature verification and accountless CUA smoke passed. No Telegram credentials entered. Native build evidence is recorded in `PROJECT-STATE.json` and `ACCEPTANCE.json`.
- Existing public Site v193 documents the fix; anonymous `/devlog/`, `/downloads/`, and both empty updater feeds returned the expected status/content. No app release or download was created.
- Updated all current app/Site/CI pointers in the two resume checkpoints. The first validation caught a truncated saved Site version ID and inconsistent phase labels; corrected both. `Scripts/validate_checkpoint.py` passed and `python3 -m unittest Tests.release.test_validate_checkpoint` passed 13/13. Generated Python cache files were removed.
- Process lesson: stale duplicated pointers caused repeated work; update them together and validate before resume. Shortened opaque provider IDs are unsafe even when visually similar. Do not repeat route tests, rebuild, or deploy without changed inputs. Full real-account and 20-runtime certification, Developer ID signing, notarization, and public app delivery remain open.

## 2026-10-14 — CORE-RUNTIME-04 privacy-bound send dispatch review

- Read-only review of `SendIntent` and `PrivacyDispatchBarrier`: text/photo dispatch rechecks lock state, captured privacy epoch, account namespace, verified Telegram user ID, and runtime generation while holding the same synchronous lock across TDLib send. Photo staging rechecks runtime registration, auth readiness, permissions, topic state, lock, and epoch after asynchronous ImageIO work and before manifest registration; final dispatch repeats the barrier checks.
- No concrete new race found in this scoped path. No code changed and no app tests/build/site deployment repeated. This does not prove real-account behavior or external TDLib completion semantics.
- Resume action moved to APP05 lock behavior across decode and accepted-send callbacks so this exact SendIntent review is not repeated.

## 2026-10-14 — APP05 locks out an in-flight photo decode

- Added test-only commit `b834969cd35c6c7591e92dfd75f51b706541095b`; app implementation and Dev.app binary are unchanged from app-source `477404afd89378affb9cc21eb6c0e32745cb5091`.
- Focused test `privacyLockInvalidatesInFlightPhotoDecodeAndAllowsFreshPreviewAfterUnlock` passed 1/1. It blocks the decoder, invokes the same `PhotoPipeline.cancelAllPreviews` and account-cache purge used by lock, then verifies no late callback/cache entry and a fresh preview after unlock. It does not prove AppKit lock integration, native photo-viewer behavior, or real account behavior.
- The first compile attempt exposed a test-call error (omitted required `chatID` in `hasCachedPreview`); fixed from the declared API signature and reran only the focused test. No app build, full test suite, or Site deploy was run.
- APP05 remains partial. Next action is APP06 reauthentication under lock and independent runtime progress.

## 2026-10-14 — APP06 reauth and APP07 notification route audit

- Read current app source `477404afd89378affb9cc21eb6c0e32745cb5091`. APP06: startup restoration and route-bound authorization-state reduction continue under lock; interactive auth presentation is gated until successful LocalAuthentication unlock. Other profile runtimes are not closed by a selected profile waiting for input. Real-profile reauth and multi-account operation remain unverified.
- APP07: each verified runtime configures the TDLib notification API; macOS permission is requested once per process; account-namespaced IDs/routes, snapshot reconciliation, stale-route checks and delivery serialization under the privacy barrier were traced. Existing synthetic tests cover route, cleanup, privacy redaction and lock serialization. No native Notification Center or 20-account delivery claim is made.
- No concrete source defect found; no code/tests/build/site deployment changed for this read-only review. APP06 and APP07 remain partial. Resume action advances to APP08 late-notification callback races.

## 2026-10-14 — APP08 late notification callback audit

- Read current app-source `477404afd89378affb9cc21eb6c0e32745cb5091`. The async system-permission callback checks runtime object identity, exact routed notification equality, and active ID under the shared PrivacyDispatchBarrier before scheduling. Click routing rechecks verified account identity and authorization; locked handoff validates route membership, runtime generation, Telegram user ID, and ready state after system unlock, and is cleared on account/message removal.
- No concrete new source race found. Existing synthetic barrier and handoff tests apply; native Notification Center completion ordering and real-account close/reconcile remain unverified. No code/tests/build/site deploy changed for this review. APP08 remains partial.
- Resume action moved to APP09 dirty-draft persistence under disk-full/storage failure.

## 2026-10-14 — APP09 accepted-send cleanup of locked dirty-draft recovery

- Found a concrete privacy-lock edge: after TDLib confirmed a send while an earlier draft flush had failed, the exact sent text could remain in `lockedDirtyDraftRecovery` and return as a draft after unlock. Added exact-value cleanup across visible and locked recovery maps; newer and unrelated unsaved text stay protected by the dirty-account barrier.
- App/test commit `62ee54349c8c63ada7d98981ec6d960b03e935e2`. Focused `acceptedSendRemovesOnlyMatchingDraftFromLockedDirtyRecovery` passed 1/1; full suite not rerun.
- Rebuilt the single canonical `/private/tmp/NeTelegram-Dev.app` from that clean SHA once; AppKit build and strict ad-hoc signature verification passed. CUA confirmed `NeTelegram · dev 62ee5434` on the clean accountless entry screen. No credentials or Telegram account were used.
- This is synthetic recovery evidence plus accountless native smoke. OS-level disk-full and native quit-barrier behavior, real login, 20 authorized runtimes, Developer ID/notarization, and release remain open. No app release was created.
- Process lesson: sandboxed process enumeration returned “unable to prove absence” even after CUA showed the app closed. The release guard was kept intact; one escalated read-only process check proved exit, then the same canonical build ran once. Do not fake a negative process result or repeat the blocked check in the same sandbox.

## 2026-10-14 — UI-SHELL-01 adaptive AppKit chat shell

- Reviewed the official Telegram Desktop UI architecture at `mainwidget.cpp`, `dialogs_widget.cpp`, `dialogs_row.cpp`, `history_view_top_bar_widget.cpp`, `history_view_list_widget.cpp`, and `history_view_compose_controls.cpp`. Applied only the structural pattern: resizable two-pane navigation, distinct chat header/history/composer regions, compact search, and native typography/colors. No upstream code, assets, logo, or unsupported feature was copied.
- Replaced hard-coded chat-shell coordinates with an `NSSplitView`, constrained sidebar controls, a separate conversation header, a scrollable history viewport, and a bottom-anchored composer. Added DEBUG-only compact shell preview with an explicit “no accounts” label; it creates no profiles and starts no account restore.
- Fixed two issues found in the 760×600 visual check: the title was constrained by a hidden topic selector, and proportional split resizing reduced the sidebar below its minimum. The follow-up preview shows the full title and 258 pt sidebar; composer, search, scroll areas, and disabled actions remain visible.
- `Scripts/dev-app.sh --launch-chat-shell-preview-compact` built the canonical `/private/tmp/NeTelegram-Dev.app`, verified its ad-hoc signature, and launched the accountless preview. AppKit target build passed; no Core behavior changed, so no Swift unit suite was run. UI changes remain uncommitted and are not covered by CI run 38550170386, which validates only base commit `62ee543`.
- Reconciled the resume checkpoints against the live Sites provider: v194 is current, not v193. Its source is `664f3efdb8cd49952341fb0bdca03aaffdb1ba71`; it records app source `62ee543` and still has no application download. No Site publication was repeated. `Scripts/validate_checkpoint.py` passed after synchronizing the duplicated pointers.
- Process lesson: on macOS, `cua.getApp()` can relaunch the app after Cmd+Q. For canonical replacement, close once, perform the elevated read-only process guard immediately, and do not query/rebind the app between those steps. This preview uses no fake account identities.

## 2026-10-14 — UI-SHELL-01 adaptive AppKit chat shell

- Replaced the fixed-coordinate chat workspace with a resizable native split view, constrained header/history/composer, and compact window minimum. Used Telegram Desktop source only to study pane hierarchy and navigation patterns; no source or assets copied.
- Fixed title/topic overlap and sidebar compression after inspecting the 760×600 native preview. The preview explicitly states that no accounts are connected; no real account or profile was accessed.
- Published app source commit `990f97ae9d4f68e1f870e9e2023848e2abd44226`; exact-source macOS CI run [38552967052](https://github.com/AffPapa/NeTelegram/actions/runs/38552967052) passed. Rebuilt and relaunched the single canonical `/private/tmp/NeTelegram-Dev.app` from that exact clean SHA.
- The public Site remains at v194 and has no download asset. No Site deployment was needed for this app-only slice.
- Next: proceed with functional native chat slice. Authenticated account smoke remains deferred by the user; no real-account or 20-runtime claim is made.

## 2026-10-14 — AUTH03 compact authorization layout and Telegram Desktop design review

- Studied official `telegramdesktop/tdesktop` source at `d77f486228a98e15d6695514d5f2b28ce1c6a872`: adaptive pane hierarchy (`mainwidget.cpp`), compact dialog row layout (`dialogs_row.cpp`), separated header/history/composer responsibilities, viewport handling, and explicit list/search states. Applied only general UI structure; no upstream code, assets, logo, or excluded features were copied. The existing NeTelegram shell already uses an AppKit split view; a future row/empty-state slice must use real TDLib-backed data.
- Made the native authorization card vertically scrollable and added focus-following scroll for Tab navigation. Added accountless compact/dark DEBUG preview switches. Fixed `Scripts/dev-app.sh` launch argument handling so `set -u` no longer aborts when no preview args are given.
- CUA at 760x600 inspected phone, code, 2FA, QR placeholder, and registration in dark appearance; registration also in light appearance. AX exposed the fields and consent control; Tab focus scrolled the consent into view. Preview is local-only, with no real profiles or network login; QR text explicitly says it is not an invitation. Default-size, VoiceOver, IME/RTL, formal contrast, and real login remain unverified; AUTH03 remains partial.
- `bash -n Scripts/dev-app.sh`, `git diff --check`, `Scripts/validate_checkpoint.py`, AppKit build, and `codesign --verify --deep --strict /private/tmp/NeTelegram-Dev.app` passed. No local unit suite was rerun because no Core behavior changed.
- Source commit `9e47764561030c82ba3f2c1f475533f1fb85eefd` pushed to `AffPapa/NeTelegram` main. Exact-source macOS CI `38554499415` passed; pinned TDLib/arm64 Dev.app build `38554499473` passed and uploaded a development artifact. Neither is a signed release. The existing public Site is still v194 with no download; no Site change was appropriate.
- Current Dev.app was rebuilt after commit once to bind clean BuildInfo to exact SHA; executable SHA-256 `83d17a066ff949415cbeea44f107332da8b8b3a3a0bcd1632142f46b0b8275a4`; BuildInfo SHA-256 `49ba032bb6c06a344480dae540db45efbceaea25755a79f6a88999ec090587a0`; pinned TDJSON SHA-256 unchanged at `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. Ad-hoc dev signing only.

## 2026-10-14 — UI-CHATLIST-01 Telegram Desktop row-pattern adaptation

- Read-only design research checked official `telegramdesktop/tdesktop` at `d77f486228a98e15d6695514d5f2b28ce1c6a872`, especially `dialogs_row.cpp`, `dialogs_inner_widget_accessibility.cpp`, `dialogs_widget.cpp`, `mainwidget.cpp`, and history top bar/list/composer. Transferred only conversation-row hierarchy, explicit selection state, and accessible row labeling. No GPL code, artwork, avatars, counts, timestamps, or excluded Telegram features were copied or invented.
- App source commit `92b8ca3f0393d8dff6bf4d56ef90e2ab94bab82f` styles the existing title and last-message snippet separately, gives the selected row the system selection color across sidebar width, and exposes “Текущая переписка” in its accessibility label. Selection is read from existing account-scoped `selectedChatByAccount`; no extra runtime behavior was added.
- One clean-source arm64 build and canonical `/private/tmp/NeTelegram-Dev.app` launch passed. CUA confirmed the explicit compact accountless workspace and honest empty state; no fabricated account or chat fixtures were used. This empty preview cannot visually prove selected-row rendering, which remains pending real chat data. The app uses ad-hoc development signing only.
- Exact-source GitHub macOS CI [38555778654](https://github.com/AffPapa/NeTelegram/actions/runs/38555778654) passed. Executable SHA-256 `86b31cc13ed52ff13e2b72719ebacce24e6437f453e8bb47157d15f8acde1e0d`; BuildInfo SHA-256 `1e16b78a419b7dd8c95b12e6012c5ba5d69a70894387b44f8c8ad5ccf151a2e7`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- AUTH04 removal logic is implemented and its historical Core tests cover identity guard, restore exclusion, and retry barriers; native TDLib `Closed` flow remains unverified. The app-specific API-hash Keychain lookup returned absent. The protected in-app API-hash dialog is now open for the owner to enter the previously supplied app hash directly; no value was read, echoed, or written by this run. This does not request a phone number or start a Telegram account login.
- Public Site remains version 194 and its Downloads page still has no application asset. No Site publish or release occurred. Real user login remains user-driven; no real-account, 20-runtime, notarization, or download claim is made.

## 2026-10-14 — Release receipt ordering made executable

- Removed a release-order deadlock: the former single receipt validator required Site link and appcast checks even though the immutable published-asset receipt must be recorded before packaging and deploying the Site.
- Validator commit `a20cce0103006bedcd455499195998c127675dea` defines two linked stages. `--stage assets` checks GitHub public bytes, Gatekeeper/quarantine, and install/reopen without claiming Site results. `--stage delivery --asset-receipt ...` verifies all Site link/feed checks after deployment and binds the final receipt to the exact pre-Site receipt bytes and the same frozen manifest. `DEV-WORKFLOW.md` and `RELEASE.md` now state that order; the release manifest stays immutable.
- Targeted `python3 -m unittest Tests.release.test_validate_release -v` passed 19/19. Exact-source GitHub Metadata validation [38556741758](https://github.com/AffPapa/NeTelegram/actions/runs/38556741758) passed. The test verifies both stages and rejects a missing or mismatched prior receipt.
- REL05 remains `not_run`: no real release assets exist, no GitHub release was created, and no Site deployment or download button was published. This change fixes the validator's sequencing deadlock only.


## 2026-10-14 — AUTH03 responsive form constraints (local, visual check pending)

- Made the authentication card and its phone/email/code/2FA/registration/country/action controls shrink to their available AppKit container width while retaining their preferred widths on normal windows. This addresses the fixed-width layout risk without changing the Telegram authorization flow.
- `swift build --target NeTelegramApp` passed with the Swift scratch and module caches under `/private/tmp`; `git diff --check` and `Scripts/validate_checkpoint.py` passed. The first sandboxed SwiftPM attempt could not write the user cache; the temporary-cache build succeeded.
- The canonical `/private/tmp/NeTelegram-Dev.app` was left running and not replaced. The change is uncommitted and has not had a source-matched native visual review at default/compact sizes; AUTH03 remains partial.
- Corrected the resume action: the API hash exposed in chat is retired. Use an appropriate current app credential entered directly in the protected app UI. No secret values are stored in this log.


## 2026-10-14 — Correct API-hash recovery guidance

- Checked Telegram's primary API-id acquisition documentation. It describes obtaining `api_id`/`api_hash` through my.telegram.org and says one `api_id` is associated with a phone number. No supported self-service hash rotation/reissue procedure was found in the reviewed primary docs.
- Corrected the checkpoint so it no longer assumes a replacement credential can be generated. The owner enters the intended NeTelegram app value only in the protected in-app field; no value is copied into this log.
- This is documentation/evidence correction only. No credential was read, Keychain item changed, app relaunched, or release published.


## 2026-10-14 — Review false positives in changed-file secret scan

- A pattern-only scan of the four changed files found 198 exact 32-hex matches. Redacted prefix classification showed every match was a public Site project/deployment/version identifier (`appgprj_`, `appgdep_`, `appgver_`); no match occurred in the modified Swift source. No matched values were printed. This closes the initial false-positive alert; it is a targeted changed-file scan, not a whole-repository secret audit.


## 2026-10-14 — APP29 stale selection guard and scoped Telegram UI review

- Added a monotonically increasing account-selection revision. `authorizationStateClosed` still completes cleanup for the closed account, but post-await status and window presentation changes are now conditional on the same account/revision still being selected.
- Added `delayedClosedAccountCleanupCannotOverrideNewerSelection`; focused Swift test passed 1/1. SwiftPM compiled both `NeTelegramApp` and `NeTelegramCoreTests` (24.18s build; 0.001s test) on arm64e / Xcode beta / Swift 6.4. The test exercises the selection guard after a modeled suspension; it is not a full native TDLib cleanup integration test. Initial sandbox runs failed before compilation at SwiftPM sandbox setup; the same command succeeded through approved host execution with caches and scratch under `/private/tmp`.
- Canonical `/private/tmp/NeTelegram-Dev.app` remains open and was not replaced. No account login, full local suite, GitHub release, or Site deployment occurred. Source/test/checkpoint commit `5f98842dbb3b4c1dbd8ca5f3537db2f4b96cd637` was pushed to `AffPapa/NeTelegram/main`; GitHub connector fetched that exact commit and coordinator blob. The automatic exact-source CI has not returned status checks yet.
- Researched the official `telegramdesktop/tdesktop` source: [`mainwidget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/dev/Telegram/SourceFiles/mainwidget.cpp), [`dialogs_widget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/dev/Telegram/SourceFiles/dialogs/dialogs_widget.cpp), [`history_view_top_bar_widget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/dev/Telegram/SourceFiles/history/view/history_view_top_bar_widget.cpp), and the project-pinned prior review of `dialogs_row.cpp`, list accessibility, history list and composer. Applicable principles: adaptive two-pane navigation, clear title/preview/selection hierarchy, separate chat header/history/composer, and explicit empty/loading/search states. The existing NeTelegram shell already implements this structural direction; no broad redesign or upstream code/assets were copied. Real-chat row visuals remain pending owner-driven login.
- Delivery audit: repo and public Site exist, but no application release/download exists. `gh` credentials are invalid and current Git network lookup failed DNS; prior Git push/connector evidence is historical. Release review also observed zero valid local signing identities, conflicting with an earlier checkpoint inventory that was inconsistent; fresh identity/notary checks must precede any candidate. No release is asserted.


## 2026-10-14 — APP29b first auto-presented runtime logout guard

- Read-only audit found that first restored runtime presentation could leave `selectedAccountIntent` unset. The later `authorizationStateClosed` cleanup correctly required that intent/revision to still match, so logout of the sole auto-presented account could skip returning to the add-account flow.
- Added `adoptStartupPresentationIfUnselected` and call it only when startup actually becomes the visible runtime. It records the initial account while preserving any newer user selection. Extended `lateBackgroundStartupCannotStealNewerAccountSelection` to check both initial eligibility and invalidation after selecting another account.
- Focused local SwiftPM test passed 1/1 and compiled `NeTelegramApp` plus `NeTelegramCoreTests`; exact-source GitHub macOS CI [38560168478](https://github.com/AffPapa/NeTelegram/actions/runs/38560168478) passed 179/179 on macOS arm64. The job ran on Xcode 27 / Swift 6.4. First sandboxed invocation failed before compilation due SwiftPM sandbox setup; the identical command succeeded with approved host execution and caches under `/private/tmp`.
- Source commit `632bf5514ffa2851a55665e95db5d17dae8fa1b7` was pushed to `AffPapa/NeTelegram/main`. Canonical Dev.app remains running old source `92b8ca3` (PID 67677); it was not touched or rebuilt. No account auth or real TDLib close integration was tested.
- Fresh `security find-identity -v -p codesigning` returned 0 valid identities, superseding conflicting older checkpoint data. Notary credentials remain unverified. Public Site v194 remains unchanged with no app download.


## 2026-10-14 — Candidate rebuild preserved after app rejected quit

- After exact-source CI passed, read-only process check confirmed canonical Dev.app PID 67677 was still running source 92b8ca3. A graceful quit request returned `user-cancelled (-128)`; a second read-only check confirmed the process remains open.
- No repeat quit, force termination, replacement build, or second app copy was attempted. The candidate build is deferred until the owner closes the app. Source `632bf5514ffa2851a55665e95db5d17dae8fa1b7` and CI run 38560168478 remain the fixed candidate inputs.
- No API hash was read from chat, process state, files, or Keychain. Site v194 and GitHub releases were not changed.


## 2026-10-14 — Protected API hash dialog blocks safe app close

- Fresh CUA inventory shows NeTelegram Dev is still running. A read-only accessibility snapshot identifies a protected API hash settings dialog with a secure text field focused. The value was not read or copied.
- This explains why the earlier graceful quit returned user-cancelled (-128). Do not dismiss the dialog, read the field, or retry quit. The owner must press Save to Keychain for the intended value or Cancel directly in the app.
- The app-source candidate remains `632bf5514ffa2851a55665e95db5d17dae8fa1b7`; CI 38560168478 passed 179/179. Rebuild remains deferred until the dialog is resolved and the same app is closed.


## 2026-10-14 — APP29c account-scoped logout failure status

- Guarded the pre-confirmation logout-close status with the selected account and captured selection revision, preventing a late close from account B from overwriting the global status after the user switches to A.
- Existing focused regression `delayedClosedAccountCleanupCannotOverrideNewerSelection` passed 1/1; SwiftPM compiled the AppKit and test targets. Exact-source macOS arm64 CI [38561302832](https://github.com/AffPapa/NeTelegram/actions/runs/38561302832) passed 179/179. This remains a policy/call-site check, not a native TDLib logout integration test.
- Source `41b33783fdd8db9db47ed13f79214c4ee95c9f7c` is pushed to main. Read-only CUA confirms the canonical Dev.app remains open at the protected API hash dialog. The field value was not read; no rebuild or quit retry was attempted.
- No signing identity or confirmed notary credentials; no app release or Site deployment.


## 2026-10-14 — Fresh candidate and signing preflight

- Rechecked canonical repo: clean `main` at `eff7c82`; app-source commit remains `41b3378`. GitHub connector confirmed `eff7c82` exists in `AffPapa/NeTelegram`.
- Fresh CUA confirms `/private/tmp/NeTelegram-Dev.app` is running from prior source `92b8ca3` on the protected API hash setup dialog. The secure value was not read or changed; no control was activated. The owner must resolve the dialog and close the app before the one in-place candidate build.
- Fresh `security find-identity -v -p codesigning` returned 0 valid identities, superseding the conflicting old checkpoint that reported 4. No signing/notarization/release occurred. `gh run list` could not reach the GitHub API; no new workflow status is inferred. Existing exact-source CI evidence for `41b3378` remains 179/179.

## 2026-10-14 — CHATLIST01 native conversation row design

- Studied Telegram Desktop’s dialog/navigation structure and its GPL-3.0-or-later license. Transferred only the information hierarchy to independent AppKit code; no Telegram code or visual assets were copied. Official source paths reviewed: `mainwidget.cpp`, `dialogs_widget.cpp`, `dialogs_main_list.cpp`, `dialogs_row.cpp`, and history header/list/composer modules.
- Source commit `44c999dee5c866f03272404e7d14965509fdefa6` is pushed to `AffPapa/NeTelegram:main`; a fresh `git ls-remote` matched the commit. Conversation rows now show an initial avatar, title, TDLib preview, localized time, selection/hover, unread badge and explicit mute indicator. The list keeps TDLib position ordering. Read-count and notification-setting events update row state. A missing TDLib last message is labeled unavailable rather than interpreted as “no new messages.”
- `swift build --target NeTelegramApp` passed with scratch/module caches under `/private/tmp`; `git diff --check` passed. No test suite was run for this presentation slice. The initial combined-status query returned no checks, so the public GitHub Actions API was queried once for the exact SHA. Exact-source macOS CI run [38563635904](https://github.com/AffPapa/NeTelegram/actions/runs/38563635904) completed successfully; the Apple Silicon Swift tests job passed. Prior run 38561302832 belongs to source `41b3378` and was not reused.
- CUA confirms the canonical `/private/tmp/NeTelegram-Dev.app` is still running prior source `92b8ca3` on the protected API-hash setup dialog. Cmd+Q did not close it. The secure field was not read or changed, and neither Save nor Cancel was clicked. No app rebuild or visual smoke is claimed. No accounts were used. Developer ID inventory remains 0; no app release/download and no Site deployment.
- Next: inspect exact-source Actions once; when the protected setup dialog is safely resolved and app exits, replace the one canonical Dev.app from `44c999d` once and perform one named native UI smoke. Site remains v194 until a signed, verified application release exists.

## 2026-10-14 — CHATLIST01 canonical Dev.app smoke

- The prior Dev.app setup dialog was cancelled only after the user had authorized closing the app; no secure field contents were read, saved, or copied. The old process then exited, confirmed by CUA app inventory.
- Revalidated canonical checkout `main` at `ea8113ca7d95ee027123a3192ccffb5b13c8582b`, clean source, origin `AffPapa/NeTelegram`, source commit `44c999dee5c866f03272404e7d14965509fdefa6`. Ran `Scripts/dev-app.sh --launch-chat-shell-preview` once. The one canonical `/private/tmp/NeTelegram-Dev.app` now embeds source `44c999d`, clean fingerprint `5e3e098c…f8f4e51`, arm64/macOS 14, and pinned TDLib `c15d3f5a`; ad-hoc `codesign --verify --deep --strict` passed. Executable SHA-256: `14621340b55e2b7fb66b1072a9cb6962be18c94923647f4179c6c7bb64592d35`; bundled TDJSON SHA-256: `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- CUA verified the live accountless preview and explicit “no accounts connected” state. No synthetic profile or Telegram account was loaded. This validates native startup and empty state only; the redesigned conversation row is not visible until real chat data is loaded. No real login/read/send, 20-runtime, performance, Developer ID, notarization, release asset, or public download was verified.
- Next: user operates API setup and real one-account login in this canonical app; verify a real conversation row and basic read/send/close/reopen flow, then continue the remaining required slices. No site change while downloads remain absent.

## 2026-10-14 — CHATLIST01 phone-login visual check

- Without rebuilding the exact-source canonical bundle, CUA showed the native login window titled `NeTelegram · dev 44c999de`: welcome text, country search, selected country/code, phone-number field, Continue and QR-login actions, with an explicit independent-client disclosure. No phone, API hash, OTP or other credential was read or entered.
- Together with the previous accountless chat-shell preview, this verifies two truthful no-account UI states on source 44c999d. It still does not demonstrate a completed login or render the conversation list rows. The app is left open on the login screen for user-operated setup/testing.

## 2026-10-14 — CORE-RUNTIME-04 post-authorization callback ownership

- A read-only runtime review found one additional stale-update window after `await runtimeCoordinator.applyAuthorizationState(...)`. Added a coordinator-generation plus local-runtime identity recheck before further callback side effects in `Sources/NeTelegramApp/main.swift`.
- Focused test `callbackAfterSuspendedIdentityPersistenceCannotApplyToReplacementRuntime` passed 1/1; SwiftPM compiled `NeTelegramApp` and `NeTelegramCore`. Exact-source GitHub Actions run [38566830872](https://github.com/AffPapa/NeTelegram/actions/runs/38566830872) passed for source `c9516a27a5bc3b0c9d124bd82878af2a60a1fcc9`.
- After the owner-authorized graceful quit and a definitive process-absence check, rebuilt only `/private/tmp/NeTelegram-Dev.app` once from that SHA. `BuildInfo.json`, Info.plist, `codesign --verify --deep --strict`, and CUA title agree; executable SHA-256 is `b25cd4372ad2c585292706ccc81e816a583b94605965eef75cf12591daf086b7`; TDLib library SHA-256 remains `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. App is running on the accountless login screen; no phone or OTP was entered.
- Telegram Desktop source research confirms an adaptive two-pane shell, dialog rows with stable title/preview/metadata hierarchy, and separate chat header/history/composer. NeTelegram should reuse only the information hierarchy via native AppKit; no Telegram code or visual assets were copied. Current empty-auth UI has no fabricated profiles; real chat-row UX remains unobserved until owner-operated login.
- Efficiency correction: run independent read-only source/runtime/design/release audits before freezing a native candidate; run one targeted test and exact-SHA CI; only then replace the one canonical Dev.app. The first candidate build in this turn preceded one reviewer finding, so it was superseded before claiming the candidate stable. Future checkpoints must distinguish source SHA, CI SHA, bundle SHA and Site version, and must not rerun already-passing CI for identical inputs.
- No account login/read/send, 20 real runtimes, Developer ID signing, notarization, GitHub application release, or Site deployment occurred. Fresh checkpoint gates still record zero valid Developer ID identities and Site v194 without downloads. No release claim is made.

## 2026-10-14 — Fresh public release gate reconciliation

- Rechecked the host with `security find-identity -v -p codesigning`: 0 valid identities. No Developer ID signing can run. Notary Keychain metadata remains unverified in this continuation; no secret was read and no submission attempted.
- Rechecked the public Site `/downloads/` anonymously. It returns the existing development page with the explicit “Приложение для скачивания отсутствует” state and no link to a nonexistent artifact. Site remains v194 and was not changed.
- Re-read the current primary Telegram API Terms: §2.3 conflicts with the requested public app title `NeTelegram`; §1.3/§1.4 basic compatibility remains open. §3.3 requires sponsored messages in channels; the pinned TDLib sponsored-media guide describes a separate fullscreen video-ad flow. The user declined the scoped video player and deferred channels/stable release if required. These gates remain unresolved; no stable compatibility is claimed.
- Read-only restore-path audit found the 20-profile synthetic test already composes the same `AccountRestorePlanner` methods that production `restoreProfiles()` calls. No new test seam was added because it would duplicate coverage without exercising real Keychain/TDLib/20-account behavior. Owner-operated first login remains required; do not reuse the API hash previously pasted into chat.

## 2026-10-14 — API configuration source check

- Read `Sources/NeTelegramCore/TelegramApplicationIdentity.swift`: the compiled `api_id` is `37110989`, matching the owner-supplied ID. The hash is not in source; runtime loads it from the designated Keychain item. No Keychain item was read or queried in this check. The previously chat-exposed hash remains retired; if absent, enter a current value only through the app's secure settings UI.
- No code or runtime behavior changed. Checkpoint JSON and diff validators only; no rebuild or app CI required.


## 2026-10-14 — CORE-RUNTIME-05 production startup registration fanout

- Source `819071d40371bbc5ae14f372454162dcfdac3f9a` is current on `main` and `origin/main`. `AppDelegate.scheduleProfileStartup()` now calls the registry+scheduler overload, so production uses the same startup-permit composition exercised by `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges`.
- Focused local test passed 1/1 and compiled `NeTelegramCore`, `NeTelegramApp`, and the test target. Exact-source macOS CI [38570078255](https://github.com/AffPapa/NeTelegram/actions/runs/38570078255) passed for the same SHA. This is synthetic fanout coverage; APP01 remains partial because real 20-account TDLib restore and same-Mac measurements have not run.
- Refreshed `PROJECT-STATE.json` and `ACCEPTANCE.json` to distinguish current source `819071d` from the one canonical running Dev.app source `c9516a27`. CUA confirms the existing app remains open on accountless phone auth (Thailand +66; empty phone field). No credentials were read or entered; no rebuild or second launch was attempted.
- Telegram Desktop research already completed at pinned source commit `d77f486228a98e15d6695514d5f2b28ce1c6a872`: retain adaptive pane hierarchy, dialog row scan order, and separate header/history/composer responsibilities in native AppKit; do not copy GPL source/assets or excluded feature surfaces. No new design code was needed for this runtime slice.
- Site remains public v194 with no app download. No signed app asset or GitHub app release exists. Latest recorded signing inventory has zero Developer ID identities; notary credentials and compatibility gates remain unresolved.
- Next acceptance action: owner-operated first-account smoke in the already-open canonical app. Do not ask for credentials in chat, rebuild unchanged source, or update Site downloads before release validation.


## 2026-10-14 — CORE-RUNTIME-05 exact-source Dev.app candidate

- The owner-authorized quit was performed with the NeTelegram menu command. CUA inventory confirmed the app exited; the normal sandbox process guard still could not prove absence, so the standard build script ran with the system process-check permission. It built the single canonical `/private/tmp/NeTelegram-Dev.app` from clean source `819071d40371bbc5ae14f372454162dcfdac3f9a` once in 5.71s. No alternate bundle was created.
- `BuildInfo.json` and the build record agree on source SHA, fingerprint `a047da8b…62bd52c`, arm64, macOS 14.0, and TDLib pin `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Strict ad-hoc `codesign --verify --deep --strict` passed. Executable SHA-256 `321365aedaada20e6a71dd2afb53d6c642ba06f92a12b3b7e538361fe529a183`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- The script's `open` returned LaunchServices `kLSNoExecutableErr`; no repeated `open`, direct executable launch, or alternate app copy was attempted. One CUA launch by the exact canonical bundle path succeeded. CUA title `NeTelegram · dev 819071d4`, accessibility state, and screenshot match the expected accountless phone-login screen. No phone, code, API hash, account, or profile was entered.
- Updated current app/bundle evidence in `PROJECT-STATE.json` and `ACCEPTANCE.json`; source, app build and Site identifiers remain separate. The real authenticated chat/read/send scenario is still pending owner-operated login. Site v194 remains unchanged and has no download.


## 2026-10-14 — AUTH-DESIGN-01 compact login and launch-root provenance

- Reviewed Telegram Desktop source paths for adaptive pane composition (`mainwidget.cpp`), dialog navigation/rows (`dialogs_widget.cpp`, `dialogs_row.cpp`), history/header/composer (`history_widget.cpp`, `history_view_top_bar_widget.cpp`, `history_view_compose_controls.cpp`), and intro phone/QR flow (`intro_widget.cpp`, `intro_phone.cpp`). Upstream is GPL-3.0-or-later; only interaction hierarchy was adapted, without copying source or assets.
- Added `AccountStorageRoot.developmentOverride`: argument > environment > embedded BuildInfo. Direct LaunchServices debug launches now use the isolated support root recorded in the bundle. Focused regression passed 1/1 and compiled AppKit/test targets.
- Auth screen now uses a 920×660 initial window, 480-wide form, narrower controls, smaller N mark/spacing, short non-affiliation note, and no contrasting card background. Existing country/phone/Continue/QR actions remain. CUA screenshot and AX verified the clean accountless login screen.
- Source `2eadea7efad0b2ac83f9f2af3059c03dd7f846a6` pushed to `AffPapa/NeTelegram:main`. Exact-source macOS CI [38572666648](https://github.com/AffPapa/NeTelegram/actions/runs/38572666648) passed 181/181. Canonical Dev.app was built from this clean SHA; BuildInfo and support root match; strict ad-hoc signature passed.
- Workflow correction: one dirty preview was produced before commit for visual review, then replaced in the same bundle by the clean exact-SHA build. Future slices must review/commit before one canonical build; no parallel app paths.
- No real auth/read/send, real 20-account lifecycle/performance, Developer ID, notarization, app release, or Site deployment. Site remains v194 with no download. Next action is owner-operated login in the open canonical app; credentials stay out of chat.


## 2026-10-14 — AUTH-QR-01 accurate QR authorization failure feedback

- Auth-path review found QR request failures were stored as phone-number failures and announced misleadingly. QR requests now carry `authorizationStateWaitOtherDeviceConfirmation`; static failure copy gives a QR-specific recovery path.
- Focused Swift test `authenticationFailureAnnouncementsAreStaticAndLimitedToSubmittableSteps PASS 1/1; covers QR-specific rejection copy.` passed. App and test targets compiled; compiler emitted only existing macOS Keychain deprecation warnings.
- Source `af72c458ef90200f0bbf9f7f6cd3772fe5aeb29c` committed and pushed once to `AffPapa/NeTelegram:main`. Exact-source macOS CI run [38574131216](https://github.com/AffPapa/NeTelegram/actions/runs/38574131216) completed successfully.
- CUA confirms the single canonical `NeTelegram Dev` process is still running the prior bundle source `2eadea7efad0b2ac83f9f2af3059c03dd7f846a6`. No second bundle was started and no user credentials/account data were accessed. The new source awaits one canonical rebuild after process exit.
- Site remains public v194 without downloads. No app release, real login, 20-account coverage, Developer ID signing, or notarization is claimed.


## 2026-10-14 — AUTH-QR-01 canonical bundle refresh and process-check lesson

- Closed the old `/private/tmp/NeTelegram-Dev.app` through its native **Выйти** menu. CUA confirmed its app entry disappeared. The default sandbox process guard then returned “unable to prove process absence”; the existing build script correctly refused to replace the app.
- Resolved the mismatch without bypassing the guard: a narrow elevated `pgrep -fl '^NeTelegram$'` returned exit 1 (no matching app process). Ran `Scripts/dev-app.sh --launch` once from clean `main` at exact app-source SHA `af72c458ef90200f0bbf9f7f6cd3772fe5aeb29c`. Build completed in 5.84s; pinned TDLib commit `c15d3f5a5de6e3ba5839822c451152e5e18bb700`; ad-hoc `codesign --verify --deep --strict` passed.
- CUA confirmed the running canonical window title `NeTelegram · dev af72c458`, empty phone field, country selector/search, Continue, QR action and independent-client disclosure. No credentials, account, or Telegram data were entered. This is native first-run UI evidence only; it does not verify a QR network response or real account workflow.
- Process lesson: a failed sandbox process query is **unknown**, not running or absent. Quit through the UI, use a narrowly scoped authorized liveness check, then rerun the canonical script; never force-kill or create a second app bundle.
- Product/UI design review was already present in the prior checkpoint; the current source retains the AppKit split navigation, searchable conversation rows, distinct chat header/history/composer and explicit content states. Official TDesktop structures were reviewed as concepts only; no source or assets copied. The next meaningful visible refinement depends on a real conversation from owner-operated login.

## 2026-10-14 — Startup Keychain stall boundary audit

- Read-only audit confirmed the existing synthetic regression oneStalledProfileKeychainPreparationDoesNotBlockTheOtherNineteen at Tests/NeTelegramCoreTests/RuntimeCoordinatorTests.swift:3668 exercises the current two-permit startup scheduler and two-worker Keychain executor. One stalled preparation leaves one permit and worker for the other profiles; no duplicate test or code change was needed.
- Boundary: two simultaneously wedged synchronous SecItem preparations can occupy both bounded workers and startup permits. No timeout/retry patch was added: releasing a waiter while its Keychain operation remains live could allow concurrent key creation or database ownership for the same account. Recovery from two permanently wedged OS Keychain calls would require an explicit saturation policy and resource decision, not a naive timeout.
- This remains synthetic evidence. It does not prove Keychain behavior under real macOS failure or real 20-account startup.

## 2026-10-14 — Remove conflicting native bundle checkpoint copies

- Removed three unused duplicate current/latest native bundle pointers from PROJECT-STATE.json; one pointed at an obsolete source SHA. The checkpoint validator and release workflow use local_development_candidate as the canonical bundle pointer, mirrored only where ACCEPTANCE requires it. Previous build receipts remain in RUN-LOG.md/Git history.
- No app source, binary, tests, or Site content changed.

## 2026-10-14 — Reconcile canonical app identity and guard duplicate pointers

- Resume audit found stale duplicate Dev.app fields in `ACCEPTANCE.json` claiming source `2eadea7` and a pending rebuild, while the canonical checkpoint and live app claimed `af72c45`.
- Reconciled against the actual `/private/tmp/NeTelegram-Dev.app`: `Info.plist` BuildInfo is `af72c458ef90200f0bbf9f7f6cd3772fe5aeb29c`; CUA reports the same `NeTelegram · dev af72c458` title and accountless phone/QR screen. No process replacement, rebuild, login, or credential entry was performed.
- Updated only current acceptance pointers; preserved old evidence in dated RUN-LOG/Git history. `Scripts/validate_checkpoint.py` now checks Acceptance's current local candidate, latest native smoke and latest local build against the one canonical Dev.app record. Added one regression test for a stale duplicate source pointer.
- Focused checkpoint suite: 14/14 passed; `Scripts/validate_checkpoint.py` passed. No app-source input changed, so the existing exact-source CI/build evidence was reused rather than rerun.
- UX research: upstream Telegram Desktop's adaptive one/two/three-column mode, independent searchable dialogs, dense identity/preview/unread rows, and persistent header/history/composer were confirmed. NeTelegram already has the right two-pane AppKit base and core row fields. Next visual refinement should tighten the account block and later add real account avatars/header identity; do not invent profile rows or add out-of-scope Telegram features. No upstream code/assets copied.
- Current blocker remains owner-operated login; real chat/read/send and all-20 authorized runtimes are therefore still unverified. No app release or download exists; Site remains v194 without a download button.

## 2026-10-14 — UX-ACCOUNT-01 clarify account and login labels

- Telegram Desktop UX review was applied narrowly to terminology in NeTelegram's account selector: an unverified local entry is labeled `Вход NeTelegram N`; a server-verified identity is labeled by its verified display name and `аккаунт N`. Accessibility/help copy now explains that entries are created by NeTelegram and that sessions from other apps are not imported. This prevents local storage IDs from being mistaken for discovered Telegram profiles.
- Focused Swift test `accountPickerUsesHumanLocalLabelsAndExplicitAuthorizationStatus` passed 1/1. Exact-source macOS CI [38577631851](https://github.com/AffPapa/NeTelegram/actions/runs/38577631851) passed for `ae21665fae9e3d72b3bd1a22ca437e8cd59b0137`.
- Canonical Dev.app was closed through its native Quit menu after explicit prior user authorization. A narrowly scoped `pgrep -fl '^NeTelegram$'` returned no process; the standard build guard still could not inspect processes in the sandbox, so the existing guarded build script ran once with system permissions. Exact source `ae21665` built in 5.59 seconds and launched; CUA window/AX title matches `ae21665f`. No credentials or account data were entered.
- Build record: arm64, macOS 14 baseline, TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`, source fingerprint `c6bb7d3f5a15758506f4f8b0ed37bf57a44c7fab4e6616bfc46b6d6396fd86f8`, executable SHA-256 `f6a031fc678291fbd6c352c51607c214408c43f458980f2afa35c75eed0e38c6`, TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; ad-hoc development signature only.
- This confirms accountless login presentation and bundle identity. Account picker wording was verified by the focused Core test, but a native account selection, real login/chat flow, and 20 real runtimes remain unverified. No public app release or download exists; Site remains v194 without a download button.

## 2026-10-14 — CORE-CLOSE-01 terminal TDLib close cleanup

- A read-only runtime audit found that `authorizationStateClosed` removes its coordinator route before the post-actor ownership check in `AppDelegate.receive`, so the handler returned before releasing the local runtime/storage lease and acknowledging shutdown. Added a terminal-close-only ownership path: the event may reach cleanup only while that exact local runtime still owns the route; stale callbacks and replacement generations remain rejected.
- Focused regression `terminalClosedUpdatePassesOnlyForItsStillOwnedLocalRuntime` passed 1/1. Exact-source macOS CI [38578966487](https://github.com/AffPapa/NeTelegram/actions/runs/38578966487) passed for source `b55f3e2a93b592b0ec977d518c1913889081e2f2`.
- Rebuilt the single canonical `/private/tmp/NeTelegram-Dev.app` once from clean `b55f3e2`; local build completed in 5.64s, BuildInfo/fingerprint and ad-hoc codesign verification passed. CUA confirms title `NeTelegram · dev b55f3e2a` and the empty phone/QR login screen. No phone, code, API hash, account, or profile data was entered.
- Telegram Desktop source/design review was not repeated wholesale: current NeTelegram still uses the adaptive two-pane foundation plus separate conversation header/history/composer. A read-only comparison found no reason for a redesign; the next bounded visual candidate is compact account/search presentation, but real chat rows cannot be visually accepted until owner-operated login. No upstream GPL code or assets copied.
- Site remains public v194 without an app download. Developer ID identity count remains zero in the latest preflight; notarization and real-account/all-20 runtime coverage remain open. No release or Site deployment occurred.


## 2026-10-14 — AUTH05 first-run country suggestion copy

- Fixed two first-run/empty-auth status paths in `Sources/NeTelegramApp/main.swift` to use the shared prompt. macOS region remains a suggestion; only explicit selection supplies the national dialing prefix. Source `ad530335eb805dfa0ae3253e74d2231453e3dec8` was pushed once to `AffPapa/NeTelegram main`.
- Exact-source macOS CI [38580883608](https://github.com/AffPapa/NeTelegram/actions/runs/38580883608) passed for the same SHA. The focused locale-selection regression was not rerun locally because this follow-up changes only AppKit status copy; its prior 1/1 run is recorded against parent `0885a9d8`.
- After confirming the old accountless Dev.app process exited, rebuilt the single canonical `/private/tmp/NeTelegram-Dev.app` once from clean source in 5.28s. Strict ad-hoc code-signature verification passed. Build fingerprint `fc6ceb24ce32b6d709ee0f750a9afff158097db884664da087a9803b4c83ceab`; executable SHA-256 `f039d55620849841a8fd0a4f5be913f815091c2581e2c244e6e6912e24f1e10f`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- CUA window title and AX confirm source `ad530335`, country placeholder remains unselected, Thailand +66 is only a macOS suggestion, phone field is blank, and QR login remains available. No credentials were entered.
- No other safe deterministic P0/P1 source issue was found in the parallel read-only triage. Real first-account login/chat flow and all-20 runtime coverage still need owner-operated account evidence. Site v194 remains without downloads; signing/notarization and policy compatibility gates remain open.


## 2026-10-14 — APP26 reentrant quit during receiver drain

- Read-only lifecycle audit found that a second macOS quit request could reach `.terminateNow` after clients closed but while `finishInputAndDrain()` was still pending. Added `RuntimeShutdownCoordinator.terminationRequestDisposition`; `applicationShouldTerminate` now cancels repeated requests during any pending shutdown and permits immediate exit only after the barrier is finished.
- Focused regression `runtimeShutdownCoordinatorWaitsForAllTwentyClientsAndReceiverDrain` passed 1/1. Initial SwiftPM invocation failed before test execution because the default user ModuleCache was inaccessible; the same single test then passed using project-approved temporary caches (16.81s build, 0.001s test). Exact-source macOS CI [38581958699](https://github.com/AffPapa/NeTelegram/actions/runs/38581958699) passed for `8689c0f1c152a4401b66a1b1b58577103ce19e6c`.
- After confirming the prior accountless app process had exited, rebuilt the single canonical `/private/tmp/NeTelegram-Dev.app` once from clean source in 5.63s. `codesign --verify --deep --strict` passed. Fingerprint `3540f8ff34fa99dd351f8c783c14ade001b588ac28f1e268cdbc4961a660e9a1`; executable SHA-256 `155d3f7cc0f9866c8e9086ff7b2841c6dd50e9b363072edc99ddcc30dcff3f1c`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. CUA title and AX state match; no credentials entered.
- Coverage limit: this proves the coordinator transition and app build, not a real TDLib close across 20 authorized profiles or an observed macOS reentrant-quit race. Site remains v194 without downloads; no app release.

## 2026-10-14 — UI02 message surfaces and Telegram Desktop design adaptation

- Read-only UX research inspected Telegram Desktop upstream source pinned at `fad667c6d71c5e965a9da71e48dc1ab82ba0568d`; the adapted layout principles and source links are recorded in `docs/TELEGRAM-DESKTOP-DESIGN-RESEARCH.md`. No upstream code/assets were copied.
- NeTelegram AppKit now presents text messages in compact directional rounded surfaces with semantic colors, measured width, accessibility text and message actions. The message presentation code and final layout constraint are in app source commit `1408ab50343325c7cf6949d8f030771761f49189`.
- Focused unsafe-link and UTF-16 entity checks each passed 1/1 on parent UI commit `15002cac`; exact-source macOS CI [38584832394](https://github.com/AffPapa/NeTelegram/actions/runs/38584832394) passed for final source `1408ab5`. The canonical arm64 `/private/tmp/NeTelegram-Dev.app` was built once (5.16s), strict ad-hoc codesign verification passed, and CUA confirmed title `NeTelegram · dev 1408ab50` plus blank accountless phone/QR screen. No credentials were entered.
- Limitation: no owner-authenticated chat was available, so visual incoming/outgoing message rendering is not claimed as PASS. Real login/read/send, 20 real runtimes, Developer ID/notarization, public release assets, and Site download link remain open. Site was not changed.

## 2026-10-14 — AUTH03 compact registration layout correction

- Fixed registration terms clipping in `Sources/NeTelegramApp/main.swift`: the text view now tracks the scroll viewport width and recomputes its wrapped height when the window lays out/resizes. The app was built once from clean app source `3f98f85f7869af0a8bd17eac641573c1f5b2a3c1` into the sole canonical `/private/tmp/NeTelegram-Dev.app` (arm64, macOS 14 baseline, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`). BuildInfo fingerprint `d57cb3a1faf5b4718b6a2557a9fe310ddd2060969d65be32417e38c631a601c3`; executable SHA-256 `ae6f9808cdab55fd1e186bd28ac464889bda20f6d2cf45697f0e63045e0c6a7d`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; strict ad-hoc codesign verification passed.
- CUA reviewed compact dark phone and registration preview. Terms wrap inside the available width; name, optional surname, consent and Continue remain reachable through the form/keyboard. This is a local preview, not an authenticated Telegram session. No phone, code, QR scan, password or account was used.
- Exact-source GitHub macOS Swift test job passed: [run 38586251707](https://github.com/AffPapa/NeTelegram/actions/runs/38586251707). No duplicate local full-suite rerun. AUTH03 remains partial pending actual auth steps, accessibility/IME/RTL and real user validation.
- Reconciled `PROJECT-STATE.json` and `ACCEPTANCE.json` to source `3f98f85`; checkpoint validator, JSON parsing and `git diff --check` passed. Site remains the same public v194 with no download. Next code/design work must use one pinned source and this single Dev.app; do not rebuild until app source changes.

- Metadata validation for checkpoint commit `8b61d62c7c4b32d876b98e2ecef5dc6fcb2d461f` passed in GitHub run [38586812417](https://github.com/AffPapa/NeTelegram/actions/runs/38586812417); app source and Dev.app were not rebuilt.

## 2026-10-14 — UX01 chat titles no longer expose TDLib IDs

- Centralized display-title normalization in `ChatDisplayTitlePolicy`. Chat-list updates, search results, and chat records now preserve trimmed server titles; a missing/blank title uses the explicit fallback `Чат без названия`, never a numeric TDLib chat ID. IDs remain internal routing keys.
- Focused `ChatDisplayTitlePolicyTests` passed 2/2. The first separate `swift build` attempt failed before compilation because the default ModuleCache was inaccessible; the corrected command with caches under `/private/tmp` passed. The executable target then built through `Scripts/dev-app.sh` once from clean app source `3dc8a11e49438cf8e4e79280a4f851c86834db2c` in 5.82s. BuildInfo fingerprint `456ca3cdaa5f599f5889adac72f2ad726337a4ba4ac0bc9a27ba7b4c85595ad9`; executable SHA-256 `60431bd9703bf729244ab1a609590dd6167ad2a9f90d3e721de7c2a820b200cd`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; strict ad-hoc codesign passed.
- The process guard initially could not prove the app was stopped. CUA showed only the local AUTH03 registration preview; Cmd+Q reported no eligible process and a fresh app inventory confirmed NeTelegram was no longer running. A narrowly scoped read-only `pgrep -fl '^NeTelegram$'` returned no process. The standard guarded build then succeeded. `Scripts/dev-app.sh --launch` returned `kLSNoExecutableErr` for this valid bundle; no repeated open or direct-executable launch was attempted. Binding the exact canonical path once through CUA succeeded; AX title `NeTelegram · dev 3dc8a11e` and blank accountless phone/QR form matched BuildInfo. No credentials entered.
- Exact-source macOS CI [38587526545](https://github.com/AffPapa/NeTelegram/actions/runs/38587526545) passed. Checkpoint validator, JSON parsing and `git diff --check` passed. This proves title policy and compilation, not real chat rendering, login, or account coverage. The existing public Site remains v194 without a download.

## 2026-10-14 — PHOTO-SLOT-01 release photo slots on terminal completion

- The photo audit found a concrete app bug: `presentDownloadedPhoto` checked privacy lock and selected chat before releasing the process admission slot. A transfer completing in the background could therefore occupy one of four slots indefinitely. `clearStack(messageList)` also discarded TDLib request correlation before success/error, leaving late failures unable to release slots.
- Added the pure Core `PhotoDownloadSlotPolicy` to release all matching account/file slots across chats/topics while preserving other accounts. AppKit now reconciles completed transport independently from presentation, retains request correlation until a terminal response or explicit cancellation, and still applies lock/current-chat/view checks before exposing content.
- Focused local `PhotoDownloadSlotPolicyTests` passed 2/2. The first SwiftPM manifest load hit the environment's `sandbox_apply: Operation not permitted`; one retry with approved system permissions built and passed. Existing deprecation warnings were from unrelated Keychain test lines. `git diff --check` passed.
- App source commit `352a293ccb93d7f74799d1852ca98065e32193ab` pushed once to `AffPapa/NeTelegram main`; exact-source macOS CI [38588737959](https://github.com/AffPapa/NeTelegram/actions/runs/38588737959) passed.
- The previous empty login window was inspected before close; phone was blank, no credentials were entered. One canonical arm64 `/private/tmp/NeTelegram-Dev.app` rebuild completed in 5.85s from clean source. BuildInfo fingerprint `bfc08d16c7f082864bc208495fe1f51d1f037ac1c6921d4346a3fce773afd357`; executable SHA-256 `3191233eb5026ed2c73697a57ef4b20a7ad2f8688a2a690ab76d1a9459401ead`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; strict ad-hoc codesign passed. CUA opened the exact path and confirms title `NeTelegram · dev 352a293c` and empty phone/QR login form.
- APP20 remains partial: no real Telegram account or photo content exercised. Site remains public v194 without a download. Release gates and account coverage remain unchanged.

## 2026-10-14 — Reconcile design research pin and stop duplicate UI research

- Audited the current design evidence against `PROJECT-STATE.json`: the checkpoint and detailed prior research pin Telegram Desktop at `d77f486228a98e15d6695514d5f2b28ce1c6a872`, while the standalone design document and UI02 criterion still named the older `fad667c` snapshot. Fetched the referenced upstream files through the GitHub connector at `d77f486` and verified their paths; updated the design document and UI02 evidence to one canonical pin.
- Expanded the concise design rationale around adaptive panes, dialog scan order, viewport-aware history, reply context and honest empty/loading/error states. Kept the AppKit implementation and GPL boundary explicit. No upstream source/artwork copied, no app source changed, no build or app tests repeated.
- Fresh local check: the only canonical app process shown by CUA is `NeTelegram Dev`, title `NeTelegram · dev 352a293c`; its phone field is blank and it shows the independent-client notice. No imported profiles or credentials were used. Repository was clean at `5f2f4c6` before this documentation-only change.
- This resolves research-version drift, not the missing real-account visual review. Next useful app validation remains owner-operated login in this exact Dev.app; then exercise real chat list/read/send/photo once. Do not rebuild until app source changes.

## 2026-10-14 — CHAT-LIST-01 asynchronous list and pagination

- Found a concrete bug: `loadMainChats` previously marked the list loaded immediately after enqueueing `loadChats`; TDLib replies are asynchronous, chat-list pages were never requested on scroll, and empty/failure states were not represented.
- Added request `@extra` plus monotonically increasing request IDs, stale-response rejection, 404 exhaustion, retryable failures, queued reload after an in-flight request, a guarded one-page-per-bottom-arrival scroll trigger, and explicit loading/empty/error states. This keeps the initial N=100 as request page size only; it does not evict background runtimes.
- Focused tests passed 2/2: `chatListSnapshotCanReloadAfterPrivacyLockAndAfterRequestFailure` and `staleChatListPageResponseCannotCompleteReplacementSnapshot`. Command: `CLANG_MODULE_CACHE_PATH=/private/tmp/netelegram-dev-swift-modules swift test --disable-sandbox --scratch-path .build/canonical-dev-build/swift-test --filter 'chatListSnapshotCanReloadAfterPrivacyLockAndAfterRequestFailure|staleChatListPageResponseCannotCompleteReplacementSnapshot'`. First default SwiftPM attempt failed before compilation because the user module cache was inaccessible; the corrected invocation redirected caches/scratch to `/private/tmp`. First compile surfaced an optional scroller/Float mismatch and mutating calls inside Swift Testing `#expect` autoclosures; both were corrected before the passing run.
- Commit `50445df3c19dc13f11dab65ec1385c12b9e431a4` pushed once to `AffPapa/NeTelegram main`. Exact-source macOS run [38592440642](https://github.com/AffPapa/NeTelegram/actions/runs/38592440642) is queued; no PASS claimed yet.
- Canonical arm64 `/private/tmp/NeTelegram-Dev.app` built once from the clean commit in 5.27s. Fingerprint `857fa0b57ad57928b4b82f098593614369ea5ed3bfc22bb5db62611d0272de31`, executable SHA-256 `2cf127e245cf41e507f1a56c9afdc5b52d43ee440d78acc87e3627592bbefd7a`, TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; `codesign --verify --deep --strict` passed. CUA confirms title `NeTelegram · dev 50445df3`, exact blank phone/QR login form, and no entered account data. This does not test real TDLib chat rows or pagination.
- Release/Site state is unchanged: public Site v194, no download asset/button, no app release. Real account login, Developer ID/notarization, Telegram policy gates and twenty-runtime coverage remain open.

## 2026-10-14 — CHAT-LIST-01 pagination retry and identity-safe placeholder

- Read-only parallel review of the current chat-list slice found a P2 app defect: one global end-of-list latch was set even while the initial `loadChats` request was still pending. If no later scroll event arrived, pagination could remain stopped; switching accounts also shared the latch. The UX review separately found that chat-ID-derived colors and initials could be mistaken for actual identity data.
- Added `ChatListPaginationPolicy`, keyed by `AccountUUID`. It only latches when a page is `.loaded`, keeps triggers independent between accounts, and clears/re-evaluates the current viewport after a terminal page response. Replaced deterministic colored initials with a neutral SF Symbol placeholder; real avatar data remains future work.
- Focused local regressions passed 3/3: `chatListPaginationWaitsForLoadedPageAndDoesNotLeakAcrossAccounts`, `chatListSnapshotCanReloadAfterPrivacyLockAndAfterRequestFailure`, and `staleChatListPageResponseCannotCompleteReplacementSnapshot`. The first test compile caught mutating calls inside Swift Testing `#expect` autoclosures; results were assigned before assertions and the same focused set passed. SwiftPM's per-user cache is read-only in this environment, so the verified command used `/private/tmp` module/scratch paths.
- App-source commit `97228153bf8c77bca42efbde9b54fe0f0d452c96` was pushed once to `AffPapa/NeTelegram/main`. The ordinary push attempt was blocked by sandbox DNS; the identical push using the already configured credential helper and approved network route succeeded. No token or new credential was created. Exact-source GitHub macOS CI [38593702149](https://github.com/AffPapa/NeTelegram/actions/runs/38593702149) passed 185/185 on macOS 15 arm64.
- The old canonical Dev.app showed only the blank login form; no hash dialog or entered phone was present. Cmd+Q closed it. Fresh CUA inventory removed NeTelegram; narrow `pgrep -fl '^NeTelegram$'` returned no process. The regular build guard could not prove absence in sandbox and correctly refused; the guarded `Scripts/dev-app.sh --launch` ran once with approved system access, built the clean SHA in 6.54s, and opened the exact canonical path. Strict ad-hoc signature passed; CUA title is `NeTelegram · dev 97228153`. No account or credentials were entered.
- Public Site remains v194 with no app download button/asset; no app release was created. This was a development milestone, not release evidence. Real chat pagination/avatar rendering, owner-operated login/read/send, all-20 runtime coverage, Developer ID/notarization, Telegram compatibility gates, and updater validation remain open.

## 2026-10-14 — CHAT-LIST-01 background completion correction

- Final route review found one remaining integration gap after commit `9722815`: the policy supported independent accounts, but AppDelegate cleared a completion latch only when that runtime was selected and unlocked. If A's page completed after switching to B or while locked, A could keep a stale latch.
- Moved gate cleanup to the exact runtime's terminal chat-list response, independent of selection/lock. UI refresh and same-viewport pagination reevaluation remain restricted to the selected, unlocked account. Source commit `4e54ce8d7c03ac92905de498b45f0bfc9b57cc52` is pushed to `AffPapa/NeTelegram/main`.
- The same focused set passed 3/3 locally; exact-source GitHub macOS CI [38594415814](https://github.com/AffPapa/NeTelegram/actions/runs/38594415814) passed 185/185. One final canonical arm64 Dev.app build from clean source completed in 5.62s; strict ad-hoc signature passed and CUA confirmed title `NeTelegram · dev 4e54ce8d`. No credentials/account were entered.
- `PROJECT-STATE.json`, `ACCEPTANCE.json`, and this design evidence now point to the same app source; checkpoint validator passes. This correction has no live-account proof: chat loading, A/B switching during actual TDLib pagination, login/read/send, all-20 runtimes, Developer ID/notarization, policy compatibility and a release download remain open. Site stays v194 with no download.

## 2026-10-14 — AUTH01 code prompt survives account switching

- Fixed the account-switch presentation path: `authPresentationInfo` now keeps a display-ready TDLib delivery prompt with only the phone's final two digits masked; returning to an account no longer falls back to generic code instructions. The full number is not retained in this presentation cache.
- Focused `AuthenticationCodePrompt` tests passed 2/2. Exact-source GitHub macOS CI [38595571377](https://github.com/AffPapa/NeTelegram/actions/runs/38595571377) passed for `66128ef445a1bc4edd3db20d57a01495be18112f`. The single canonical arm64 `/private/tmp/NeTelegram-Dev.app` was rebuilt once in 5.52s; `codesign --verify --deep --strict` passed. Fingerprint `aeca3055a76d27491cc5a8f88869d4814cc0a2da5050809ee74db738e18b6179`, executable SHA-256 `ca9e32eab9b14c50ca8e4063fad8241e5af172c8a271e4302873856814356862`, TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. CUA title `NeTelegram · dev 66128ef4` matches the bundle.
- The app is still on a blank phone/QR login form. The user said they will save the app API hash, but no success status is visible; Codex did not inspect Keychain or handle credentials. No account was used, so AUTH01 remains partial pending an actual code step. No GitHub release or Site change.
- Read-only schema check against pinned TDLib `c15d3f5` confirmed `registerUser` takes only first name, last name and notification preference; it has no terms-of-service ID field. No registration patch is needed.

## 2026-10-14 — PHOTO-FAILURE-01 decode error recovery

- Evidence: `PhotoPipeline` previously returned silently when preview decoding produced no data, leaving the UI in a loading state. A focused regression now verifies that the current request receives a nil completion, the bounded decode slot is released, and a retry can succeed. Cancellation/deletion/Privacy Lock regression checks still pass.
- Local verification: 3 focused Swift tests passed.
- Source: `5f414650a139bb62bdf12fd198495faf4b246f10` pushed once to `AffPapa/NeTelegram` main. Exact-source macOS CI run `38596948225` passed (https://github.com/AffPapa/NeTelegram/actions/runs/38596948225).
- Native verification: one canonical arm64 Dev.app built from the clean source SHA; strict ad-hoc `codesign --verify --deep --strict` passed. CUA confirmed title `NeTelegram · dev 5f414650` and blank phone/QR form. No account credentials were used.
- Limits: this is synthetic decoder coverage plus accountless UI smoke. Real Telegram photo behavior, one-account login/read/send, all-20 runtime, Developer ID/notarization, policy gates and public downloads remain unverified. Site unchanged.

## 2026-10-14 — AUTH-UI-01 native login layout

- Research: Apple HIG guidance reviewed for macOS ergonomics, window sizing, layout, color/accessibility, keyboard focus, and text fields. Official Telegram Desktop's Qt UI and Telegram iOS source were inspected as flow references only; no third-party UI code or assets copied.
- Change: reduce the initial native window to 760×600 pt; use a single 360 pt control column with shared alignment, adjust spacing by hierarchy, align the phone field and status to the form edge, shorten the country-entry instruction, and use secondary semantic text color for the independence disclosure. Auth states and TDLib commands are unchanged.
- Local verification: focused country-picker and phone-input tests passed 2/2. Focused country-picker and phone-input tests passed 2/2; exact-source macOS CI run 38597901537 passed for `ae169ecf0e619eb27e7e8767266baacb6dbe2091`. One canonical arm64 Dev.app was rebuilt once and passed strict ad-hoc codesign verification. CUA confirmed the exact title/SHA and visibly aligned compact auth screen with updated AX text. No credentials or account were used; the Site was unchanged.
- Sources: Apple HIG https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/ and https://developer.apple.com/design/human-interface-guidelines/layout ; Apple accessibility https://developer.apple.com/design/human-interface-guidelines/accessibility ; official Telegram Desktop https://github.com/telegramdesktop/tdesktop and Telegram iOS https://github.com/TelegramMessenger/Telegram-iOS.

## 2026-10-14 — AUTH-IME-01 prevents premature login submission

- Finding: the first-run auth text-field delegate submitted on Return without checking AppKit marked text, so Return could submit an unfinished IME candidate. The message composer already had this guard.
- Change: added `AuthTextFieldKeyboardPolicy` and applied it to auth-field Return handling; non-Return commands and marked-text composition are left to AppKit. TDLib requests and the rest of the auth flow are unchanged.
- Local verification: focused `authReturnDoesNotSubmitDuringMarkedIMEComposition` passed 1/1 using an isolated `/private/tmp` SwiftPM scratch/cache after the sandbox's default module cache was denied. Exact-source macOS CI and the canonical app smoke are pending.
- Coverage: pure policy regression only; actual CJK IME interaction is not yet verified. No phone number, code, API hash, or account was used.

## 2026-10-14 — AUTH-VOICEOVER-QR-01 announces QR confirmation

- Finding: TDLib's `authorizationStateWaitOtherDeviceConfirmation` update uses a dedicated QR presentation branch that bypassed the shared authorization-step announcer. The QR image had an AX label, but the transition could be silent to VoiceOver.
- Change: invoke the existing account/generation-deduplicated announcement after the QR screen is presented; add an explicit assertion for the TDLib QR-state mapping and static announcement.
- Verification: focused authorization-announcement test passed 1/1; exact-source macOS CI run 38599873729 passed; one canonical arm64 Dev.app rebuilt in 5.68s and strict ad-hoc signature verification passed. CUA confirmed title `NeTelegram · dev 681b1622` and the accountless AX tree. The authenticated QR transition and actual spoken announcement with VoiceOver enabled remain unverified.
- No account or credentials used; source and Site identities remain separate.


## 2026-10-14 — AUTH-UI-DESIGN-02 Apple HIG layout correction

- Research: rechecked Apple HIG macOS/window/layout/color/focus guidance and GitHub-hosted Telegram Desktop structure. Applied native AppKit/system appearance, Auto Layout, one task-aligned control grid and concise status copy. Telegram Desktop was a flow reference only; no upstream code or art was copied. Research notes: `docs/TELEGRAM-DESKTOP-DESIGN-RESEARCH.md`.
- Finding: country search and country menu consumed separate full-width rows, and status text repeated the subtitle. Changed the two controls to one 360 pt row (132 pt search + 8 pt gap + 220 pt native country picker); kept the phone field aligned below and shortened dynamic status. Auth commands, selected-country policy and data handling are unchanged.
- Source `936c2cf2e09b00e3b0c8e5a8421de07544bdb2de` was pushed once to `AffPapa/NeTelegram/main`. Exact-source macOS CI [38600662118](https://github.com/AffPapa/NeTelegram/actions/runs/38600662118) passed.
- One canonical `/private/tmp/NeTelegram-Dev.app` built after CI in 5.50 s; BuildInfo records arm64/macOS 14, Swift 6.4 and pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Fingerprint `0384f03bc5cd0d2a6fb1c61315b5d7b17db18f0e658e8b638d73446a7aa95f6d`; executable SHA-256 `7bd24cc0380d9cf0901e33320475ae1b4650b356f2c6dc58dedba3902d02ccc0`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. Strict ad-hoc `codesign --verify --deep --strict` passed. CUA title `NeTelegram · dev 936c2cf2`; screenshot and AX show the new layout; Tab order search → country picker → phone passed. No account or credentials used.
- Limits: visual review covers only the accountless phone-entry screen. Authenticated message screens, native VoiceOver speech, RTL/IME interaction and live login remain unverified. Public Site stays at v194 and has no download; no release gates changed.

## 2026-10-14 — AUTH-UI-DESIGN-03: Apple HIG auth refinement

- Reviewed Apple HIG for macOS windows/layout, text fields, buttons, typography, semantic color, Dark Mode and accessibility; Telegram Desktop source reviewed for flow hierarchy only. No upstream implementation/assets copied.
- Removed duplicate instructional text from authorization code/2FA screens by hiding status only when it exactly equals the current subtitle; independent phone guidance, progress/errors and fake-QR preview status remain. Updated `docs/TELEGRAM-DESKTOP-DESIGN-RESEARCH.md`.
- Added `Sources/**` trigger to the pinned TDLib/Dev.app workflow so AppKit source edits get a native bundle build.
- Source `45a5451cb614202989ccc3a3981f539eadf0d7fb` pushed to `main`; exact macOS CI 38602110387 passed 187/187; pinned native build 38602110256 passed. One canonical arm64 Dev.app rebuilt (5.48s), strict ad-hoc signature verification passed; CUA inspected phone/code/2FA/QR/registration with no credentials or account.
- Local `swift test` could not enter compilation because the sandbox rejected `sandbox_apply`; exact hosted suite is the test evidence. Real auth, authenticated UI, VoiceOver speech, RTL/IME and all-20 runtime remain unverified. Site/release unchanged.
- Metadata validation run 38602612320 initially failed because `test_native_workflow_scope.py` encoded the former exclusion of `Sources/**`; updated the test to match the new trigger and focused scope tests pass 2/2. Re-run metadata CI after this correction.
- Metadata validation rerun 38602838474 passed for checkpoint commit `e0a1c09`; the earlier test-contract failure is resolved.
## 2026-10-15 — APP25 installed-bundle boundary

- Read-only native UI check against the existing canonical `/private/tmp/NeTelegram-Dev.app` (`org.affpapa.netelegram.dev`, app source `45a5451cb614202989ccc3a3981f539eadf0d7fb`): opened NeTelegram Dev → “Запускать при входе в macOS…”. macOS returned “macOS не нашла службу автозапуска NeTelegram” and instructed to open an installed package.
- No checkbox was changed, no Login Items entry was registered/unregistered, and the existing Dev.app was left open at the accountless phone screen.
- This confirms the previous APP25 gap is an environment/package boundary: the temporary ad-hoc development bundle is not eligible for `SMAppService.mainApp`; policy tests and CI cannot certify installed-app persistence/removal. APP25 remains `partial`. Complete it only against a disposable installation of the real app bundle, then verify both registration and removal without leaving startup enabled.
- No source code/build changed. Checkpoint validation and current branch/commit verification follow this entry.

## 2026-10-15 — API credential presence preflight

- Read-only Keychain lookup used only the app's fixed service/account attributes (`org.affpapa.netelegram.telegram-api` / `api-hash`); command omitted `-w`, did not return secret data, and reported item not found.
- This confirms that selecting the Save action in an earlier UI prompt did not result in a stored item. The API hash previously exposed in chat remains retired; do not copy it back into Keychain or ask for it in chat. The protected in-app API-hash field is the only approved entry path once the owner provisions a replacement credential.
- No authentication request, Telegram account data, app source, build, user preference, or Site state changed. Fresh checkpoint validation follows.

## 2026-10-15 — AUTH-UI-DESIGN-04: first-run auth layout

- Reviewed Apple macOS HIG guidance and official Telegram authorization UI source as layout references. Kept the native AppKit controls and semantic system styling; the form now uses the available scroll viewport, consistent widths, a concise country-search prompt, and one explicit locale suggestion. The macOS region remains unselected until the user chooses it.
- Refined after the first native screenshot showed a clipped country placeholder and duplicate locale guidance; the second screenshot/AX tree confirms both are fixed.
- Local targeted tests: 5/5. Exact-source GitHub macOS CI: PASS ({run_url}). Pinned TDLib app workflow: PASS ({native_url}).
- Canonical Dev.app: 291cd0a7fb27b07be13fdd9e2d4e2ef8f3b4311b; arm64; macOS 14 baseline; ad-hoc development signature verified; executable SHA-256 `d2f8cdbdcde62145d9445d750c0fdcb87d198d7a4ed9cb9b3f5d5a023b0c09c8`. No login or account was used.
- Public app name is AffPapa Chat; NeTelegram is the repository codename. No signed release or download was created.
- Remaining coverage: light appearance, VoiceOver speech, real auth, authenticated UI, IME/RTL, real chats and all-active account behavior remain unverified.

## 2026-10-15 — AUTH-UI-DESIGN-04 and Site v195 verified
- App source commit `291cd0a7fb27b07be13fdd9e2d4e2ef8f3b4311b` improves the AppKit authorization window: one aligned form column, a scrollable layout, window-size adaptation, and clear country-selection guidance. Focused local tests passed 5/5; exact-source CI `38607088774` and pinned TDLib build `38607088681` passed. One canonical arm64 Dev.app was rebuilt once and visually checked without signing in or using an account.
- Reused the existing public Site. Source helper commit `1adba5a1410ed186c389dc701ce8e9ad9d37b26f` was saved as Site version 195 (`appgprj_6acba85192e08191acdf7011928848cf~appgver_8c62e28f8a788191b04e2cd6e2fbd0e0`) and deployed successfully as `appgdep_6acfbddce1d48191bf095654b4586a4e`. The Site project title was updated to “AffPapa Chat — независимый клиент для macOS”; public URL remains https://netelegram.iryadom.chatgpt.site.
- Anonymous browser verified fresh `/` and `/downloads/`: homepage names AffPapa Chat, links exact source/CI and records the AUTH UI milestone; downloads explicitly has no release/installer and links to source. A preexisting tab with `?v=195` initially showed cached v194; only the fresh cache-busted navigation was counted as live evidence.
- Site archive SHA-256 `0b31cc62a46f7abb052dc53ea82fbe48c57e1c2f989bcc9283f379f557a88e4e`, 501760 bytes, 14 files. Checkpoints now distinguish app source, Site source/version/deployment, bundle and live URL. No app release/download was created.
- Remaining: real owner-operated login/read/send, all-20 authorized runtime/resource coverage, Developer ID/notarization/Gatekeeper/updater, and Telegram compatibility policy gates. These are not implied by the accountless screen smoke or Site publication.

## 2026-10-15 — Correct stale pointers and Site archive evidence
- Reconciled current slice, latest source CI, native workflow, release preflight, and latest Git push pointers to app source `291cd0a` / docs-only remote HEAD `4f9f083`. The currently running Dev.app is accountless; no new build or source tests were needed.
- Sites `get_site_version` independently reconfirmed v195 source `1adba5a1410ed186c389dc701ce8e9ad9d37b26f`, deployment `appgdep_6acfbddce1d48191bf095654b4586a4e`, and saved server-side archive metadata: hash `sha256:0b31cc62a46f7abb052dc53ea82fbe48c57e1c2f989bcc9283f379f557a88e4e`, 501760 bytes, 14 files. The old local export path now contains different bytes (SHA-256 `52f729f5b71ebbf0de7f793694e6e0d601f48fc2d9d3d12776c93ae62f44c16d`, 202367 bytes); removed it as local-byte evidence. No v196 repackage/redeploy was made.
- Current read-only release audit: repo main synced at docs-only `4f9f083`; app CI/native bundle workflows pass on `291cd0a`; valid Developer ID identities 0; no signed candidate or release assets. Non-value Keychain lookup reports app API hash not_found; the hash pasted in chat remains retired. No Keychain value was read or changed.
- `Scripts/validate_checkpoint.py` passes after reconciliation; exact public URL, cache-busted anonymous home/download routes, and no-download state remain verified.


## 2026-10-15 — CHAT-LIST-RECONCILE-01: preserve native conversation rows across TDLib updates

- Finding: ordinary chat-list refresh cleared and recreated every AppKit row, even for a single unread, mute, message-preview or position update. This added avoidable view churn and could discard view identity/focus state.
- Change: `ConversationListRowButton` now updates its data/accessibility label in place. `refreshChatList(changedChatIDs:)` retains keyed row views, updates only the affected row for single-chat TDLib events, inserts/removes changed IDs, and reorders existing views to match the server snapshot. Search, empty/loading, revoked-profile and privacy clear paths still discard view caches.
- Local verification: isolated `swift build --target NeTelegramApp --scratch-path /private/tmp/netelegram-spm-chatrows-3eabf4b` passed in 10.05 s. The canonical Dev.app process guard returned “unable to prove process absence”; no local bundle replacement or UI smoke was attempted.
- Exact-source hosted checks passed on `9e0af7a46c1904600cdfc8eeb1e3716239b7cb95`: [macOS serial Swift CI](https://github.com/AffPapa/NeTelegram/actions/runs/38611394780) and [pinned TDLib/Dev.app workflow](https://github.com/AffPapa/NeTelegram/actions/runs/38611394887). Hosted development bundle does not count as local UX evidence.
- Coverage limit: no measured 1k/10k chat benchmark, no local visual/AX check, no real account smoke. Current local Dev.app remains on `291cd0a`; only one canonical bundle is allowed.


## 2026-10-15 — Canonical Dev.app process and Keychain recheck

- Read-only `pgrep` positively found PID `81742` running the single canonical `/private/tmp/NeTelegram-Dev.app` with compact auth-preview flags. The process guard refusal is therefore expected; no app window was closed, no process was terminated, and the canonical bundle was not replaced.
- Non-value Keychain lookup (`security find-generic-password -s org.affpapa.netelegram.telegram-api -a api-hash`, with no `-w`) returned `not_found`; no credential value was read. Leave the app open until the owner confirms the protected entry is saved or intentionally cancelled.
- Exact-source app code, isolated build, Swift CI and pinned TDLib workflow remain verified at `9e0af7a`; the active local bundle is still the prior `291cd0a`. Local visual smoke for this source remains pending.


## 2026-10-15 — DEV-PREVIEW-GUARD-01: prevent offline preview reuse as a login client

- Finding: the only local NeTelegram process was running with `--ci-auth-layout-preview`. That mode skips profile restoration/connection observers and intentionally disables network login and QR. `open --args` cannot convert an already running macOS process into normal mode; the earlier run path did not detect this distinction.
- Change: `Scripts/dev-app.sh` now compares requested preview flags to the active process before reusing an exact-source canonical bundle. It refuses a mode mismatch or unreadable process arguments. `DEV-WORKFLOW.md` now says preview screenshots cannot count as real login evidence.
- Local verification: launch-mode tests passed 5/5; `bash -n Scripts/dev-app.sh` and Python compile passed. No process or app bundle was changed.
- Hosted verification on `6160d1a8ecc344955b6dadc9351723ec458a7879`: [metadata tests](https://github.com/AffPapa/NeTelegram/actions/runs/38612755032) and [pinned TDLib/Dev.app workflow](https://github.com/AffPapa/NeTelegram/actions/runs/38612755038) passed.
- Current boundary: local PID `81742` and app source `291cd0a` remain in auth preview; source `9e0af7a` is not installed locally. The app-specific Keychain item is `not_found`. No login, account data or secret was read.

## 2026-10-15 — AUTH-LAYOUT-RHYTHM-05

- Source: `115716ad1bd5e3fb3d87d64ede00851afc4139f4` pushed to `AffPapa/NeTelegram` main. App-facing identity now reads NeTelegram; the non-affiliation note uses 13 pt system text.
- Layout: auth stack is centered as a group in tall windows; the scroll document grows for long auth steps instead of distributing spare height across controls. Native AppKit chrome, controls, semantic colors and Auto Layout retained.
- Verification: exact-source tests [run 38614052499](https://github.com/AffPapa/NeTelegram/actions/runs/38614052499) and pinned native assembly [run 38614052536](https://github.com/AffPapa/NeTelegram/actions/runs/38614052536) passed. Local Swift invocation was blocked by sandbox `sandbox_apply: Operation not permitted`; not a test failure.
- Visual status: no current-source local screenshot. The single canonical Dev.app still runs source `291cd0a` with its protected API-hash setup dialog open; its value was not read and the app was not replaced. Screenshot `dev 5f414650` is historical.
- Next action: owner saves or cancels the protected dialog, quits that same app normally, then rebuild one canonical bundle and inspect the real resized screen. No release or Site download change.

## 2026-10-15 — AUTH-LAYOUT-RHYTHM-06

- Source `78763f3165bef89e98584b6ca6f43c84ebdd3258` aligns the sign-in N mark, UI/accessibility copy and generated development bundle name with the latest user instruction: NeTelegram. Dev bundle uses `CFBundleName` and `CFBundleDisplayName` `NeTelegram Dev`.
- Apple HIG layout change keeps the form grouped as the window grows; no custom window chrome or fixed palette. Non-affiliation note is 13 pt with semantic secondary-label color.
- Focused Python regressions passed 3/3. Exact-source CI [38615081039](https://github.com/AffPapa/NeTelegram/actions/runs/38615081039) and pinned native workflow [38615081338](https://github.com/AffPapa/NeTelegram/actions/runs/38615081338) passed. Metadata validation [38614774693](https://github.com/AffPapa/NeTelegram/actions/runs/38614774693) passed.
- No current-source local screenshot: the only canonical Dev.app is still old source 291cd0a, with the protected API-hash dialog open. Its field was not read and its app was not replaced. Image `dev 5f414650` is historical.
- Public title compatibility remains unresolved under Telegram API Terms §2.3; no public release or Site download was created. Real login, 20-runtime, signing/notarization and other compatibility gates remain open.
- Next: owner saves or cancels the protected dialog and quits the same app; rebuild the single canonical bundle and inspect default/resized visual states.


## 2026-10-15 — AUTH-FORM-ALIGN-07

- Source `f56cc73fa71dc4f7570a2265d3c3bf328ea19d2f` aligns country search and selection controls vertically at a consistent width, following Apple HIG guidance for scanning form fields. No login behavior changed.
- Exact-source macOS tests passed: [run 38616087277](https://github.com/AffPapa/NeTelegram/actions/runs/38616087277). Pinned TDLib arm64 Dev.app build and strict verification passed: [run 38616086721](https://github.com/AffPapa/NeTelegram/actions/runs/38616086721).
- Local GUI review remains pending: the single canonical Dev.app still has its protected API-hash setup dialog open. The field was not read or changed; no local bundle was replaced.
- Next: owner saves or cancels that protected dialog and normally quits the same app; then rebuild the one canonical Dev.app from this source SHA and inspect default/resized and light/dark presentation. No release or Site download changed.

## 2026-10-15 — AUTH-PHONE-GATE-08

- Apple HIG-guided native sign-in refinement: preserve AppKit/system styling and aligned form layout, and disable Continue until the phone policy accepts input. Local numbers additionally require the user to choose a country; complete international `+` input can proceed without a loaded country catalogue.
- Focused local Swift regression passed 1/1. Exact-source serial macOS CI `38617200776` and pinned TDLib/Dev.app workflow `38617200741` passed for source `d1e3c73628d8f8e4840cd443aa7ba5c610159a92`.
- Rebuilt the sole canonical `/private/tmp/NeTelegram-Dev.app` once after the prior process was confirmed closed. BuildInfo matches source, arm64, macOS 14 baseline and pinned TDLib; strict ad-hoc code-signature verification passed. CUA/AX dark offline preview confirmed disabled state for empty/incomplete input and enabled state after choosing Thailand for synthetic local digits. The Continue button was not activated; no account credentials or network requests were used.
- Coverage remains limited to accountless phone-entry UI. Real auth, authenticated views, resized/light appearance, VoiceOver speech, IME/RTL and all-20 runtime behavior remain unverified. No Site deployment or app release was made.

## 2026-10-15 — AUTH-PHONE-RECOVERY-09 and Apple HIG review

- Source `6c16eb1b02603a627d168baa6a83d909641814fc` adds a same-profile “Изменить номер телефона” action only at TDLib `WaitCode`; it returns to phone entry without resetting the profile or sending a request. Unsupported, locked, and in-flight states fail closed.
- Apple HIG review: retain standard AppKit window chrome, semantic system colors, native focus/disabled states, one aligned form column, and a compact resizable sign-in window. Current source forces the auth window to 640×680. The user-provided `5f414650` screenshot is from an older build and is not current visual evidence. CUA/AX inspection confirms the canonical app title `NeTelegram · dev 6c16eb1b` and a single accountless form with country search, country picker, phone entry, disabled Continue, and QR action. No new visual redesign was justified by the stale screenshot.
- Official references: [Apple macOS design](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/), [windows](https://developer.apple.com/design/human-interface-guidelines/windows), [layout](https://developer.apple.com/design/human-interface-guidelines/layout), and [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility). TelegramSwift was reviewed for structure only; it is GPL-2.0 and its source, assets, and styling are not copied into this MIT app.
- Focused regression passed 1/1; exact-source CI `38620021813` and pinned TDLib workflow `38620021706` passed. One canonical local Dev.app build was verified and reused; no duplicate bundle or app release was created.
- Coverage remains accountless login and offline code-step navigation only. Real authentication, authenticated chat visual review, accessibility speech/IME/RTL, all-20 runtime, Developer ID/notarization, and release remain open. Public Site remains at version 195 without downloads.

## 2026-10-15 — AUTH-API-HASH-PROMPT-10

- Change: on an explicit first-login attempt, a confirmed missing NeTelegram API hash now opens the existing protected Keychain entry dialog directly. The profile is created only after the credential lookup succeeds; after saving, the user must explicitly press Continue again. No chat-pasted credential is reused.
- Focused verification: `swift test --no-parallel --filter telegramAPIHashAcceptsOnlyThirtyTwoAsciiHexCharacters` passed 1/1; SwiftPM compiled `NeTelegramApp`. Exact-source macOS CI [38621219679](https://github.com/AffPapa/NeTelegram/actions/runs/38621219679) and pinned TDLib app workflow [38621219596](https://github.com/AffPapa/NeTelegram/actions/runs/38621219596) passed for source `533c358dc6a7958275dd9a39d2b1d13d38a99b66`.
- Native check: rebuilt only `/private/tmp/NeTelegram-Dev.app` from clean SHA `533c358`, arm64, macOS 14 baseline, pinned TDLib `c15d3f5a`; strict ad-hoc signature verification passed. CUA confirmed the window title and accountless phone-entry form. A synthetic number was used to exercise explicit Continue, then cleared. The Keychain read timed out after 10 seconds, so the `.missing` setup-dialog branch was not reached; no profile/login was started and no API hash value was read.
- Current blocker/evidence: a separate `SecItemCopyMatching` query for attributes only (same service/account, noninteractive LAContext, no `kSecReturnData`) returned `errSecSuccess` in 3 ms. The legacy `security find-generic-password` command did not find the item, while the canonical app's data-return query timed out. The item therefore is not confirmed missing; the secret value was not requested by the diagnostic or read, printed, copied, or deleted. Diagnose the Security/keychain-context discrepancy before another login attempt. User-owned login remains deferred; no real account or Telegram data was accessed. Site remains at version 195 without downloads; real-account, 20-runtime, Developer ID/notarization, and compatibility gates remain open.

## 2026-10-15 — checkpoint correction: Keychain lookup timeout

- Correction to AUTH-API-HASH-PROMPT-10 wording: the standalone attributes-only diagnostic did not request or print the secret. The application did issue a Keychain data-return query; its readiness caller timed out at 10 seconds, but the underlying synchronous Security operation is not canceled and may still complete or populate the in-memory readiness cache later. We have no evidence that the value was observed or printed. Do not describe this as “the application never read the value.”
- The UI smoke returned before profile creation or a Telegram request, so no account/login started. Preserve the Keychain item and diagnose the data-query timeout before another attempt.

## 2026-10-15 — AUTH-FORM-APPLE-HIG-11

- Reviewed the current native auth screen against Apple macOS HIG for window behavior, layout, fields, accessibility, and writing; separately reviewed Telegram Desktop's official phone-entry flow as an interaction-structure reference only. No GPL code, assets, or styling were copied.
- The current 640×680 pt accountless sign-in window uses standard AppKit chrome, semantic system colors, native controls, one aligned form column, explicit country selection, and a compact centered stack. The Mac region appears only as a suggestion; country code applies after explicit selection. Continue is disabled for empty input. The non-affiliation note follows the actions and uses secondary system text.
- Inspected the actual canonical Dev.app screenshot and accessibility tree at source `1e6a77d6234835462de02a01624ec12e0fbaaabd`; no concrete defect justified another design iteration. `codesign --verify --deep --strict` passed; screenshot is accountless only.
- Updated current checkpoint pointers from stale `533c358` build data to the exact embedded source `1e6a77d`. Exact-source macOS CI [38622881807](https://github.com/AffPapa/NeTelegram/actions/runs/38622881807) and pinned native app workflow [38622881849](https://github.com/AffPapa/NeTelegram/actions/runs/38622881849) both passed for that SHA. No new tests were added or rerun because this pass made no app code changes. No Site deployment or app release.
- Remaining UI coverage: authenticated chat window, resize and light appearance, VoiceOver speech, IME/RTL. Remaining product gates include real login, all-20 runtime, Developer ID/notarization, Telegram compatibility decisions, and release.

## 2026-10-15 — AUTH-FORM-APPLE-HIG-12

- User screenshot overturned the previous AUTH-FORM-APPLE-HIG-11 conclusion that the screen needed no redesign. The earlier review had accepted a large, flat auth window without a compact-size check; the current screenshot made the excess vertical space visible. This iteration records that miss and its cause so future UI reviews must inspect the exact active source, compare the user screenshot, and check a compact window before claiming visual acceptance.
- Apple HIG research: macOS apps should use system window behavior and controls, comfortable density, resize-adaptive layouts, aligned and consistently sized fields, keyboard access, and semantic colors that adapt to system appearance. Telegram Desktop's official repo was inspected only for interaction structure; no GPL source, styling, or assets were copied.
- `Sources/NeTelegramApp/main.swift`: changed the sign-in default from 640×680 to 620×600 pt; the compact preview now checks the 560×520 pt minimum. Root and privacy-lock backgrounds now draw `NSColor.windowBackgroundColor` at render time and request redraw after effective-appearance changes instead of retaining a resolved `CGColor` snapshot.
- Finished the already-started unsupported-message context slice: safe caption, document filename, audio metadata, poll question, and date may be shown; raw IDs and local paths are never rendered. Added two synthetic presentation tests.
- Verification: `swift test --no-parallel --filter unsupportedMessageCards` passed 2/2 and compiled NeTelegramApp. Canonical `Scripts/dev-app.sh --launch` built and opened `/private/tmp/NeTelegram-Dev.app`, BuildInfo matches clean source `4ccc4821cde94eb7b4fe2ccfda26ce8b2d038544`, and `codesign --verify --deep --strict` passed (ad-hoc development signing only). CUA screenshot/AX inspection passed at 620×600 pt; the same bundle's offline compact preview at 560×520 pt kept all controls and the non-affiliation note visible, then normal mode was restored. This check used dark appearance; light appearance, VoiceOver speech, IME/RTL, login, authenticated chat, and 20-runtime behavior remain unverified.
- Exact-source GitHub macOS CI passed: [38624958152](https://github.com/AffPapa/NeTelegram/actions/runs/38624958152). Pinned TDLib/Dev.app workflow passed: [38624958184](https://github.com/AffPapa/NeTelegram/actions/runs/38624958184). No Site deployment or app release.
- Current app source is `4ccc4821cde94eb7b4fe2ccfda26ce8b2d038544`; current normal Dev.app remains open with no account data or credentials entered. Next project action remains the scoped Keychain data-query timeout diagnosis, then user-operated one-account login/read/send/logout. Real 20-account validation, compatibility gates, release signing/notarization, and public download remain open.


## 2026-10-15 — AUTH-FORM-APPLE-HIG-17

- Research: current Apple HIG for macOS windows, layout, text fields, accessibility, and keyboard behavior; current Telegram Desktop `Telegram/SourceFiles/intro/intro_phone.cpp` and `intro.style` reviewed for flow only. Telegram Desktop is GPL-3.0; no code, styles, assets, or branding were copied.
- Change in `Sources/NeTelegramApp/main.swift`: country selector now has a visible “Страна” field label; the visible macOS-region hint is shorter while its accessible description retains the explicit-selection rule. Initial keyboard focus goes to country search until the user selects a country, then to phone entry. Country is not preselected from macOS locale.
- Verification: existing focused country-picker test passed 1/1; `git diff --check` passed. Canonical `/private/tmp/NeTelegram-Dev.app` built from `344396f6ed19dddcb397cc6c5eb3c1113853ae44`, strict ad-hoc signature verified. CUA/AX checked the normal accountless window, 560×520 pt offline preview, search/select of Thailand, and focus moving to phone. A first compact run exposed the helper text pushing the disclaimer; shortened the hint, rebuilt once from the final source, and confirmed the full disclaimer fits. Restored the same bundle to normal dev mode.
- Exact-source macOS CI [38626873547](https://github.com/AffPapa/NeTelegram/actions/runs/38626873547) and pinned TDLib/native app workflow [38626873636](https://github.com/AffPapa/NeTelegram/actions/runs/38626873636) passed for the exact source SHA. No login, profile creation, Keychain value read, or Telegram request. No app release or Site deployment.
- Limits: dark appearance only; authenticated chat, light appearance, VoiceOver speech, IME/RTL, real-account flows, all-20 runtime coverage, Developer ID/notarization, and public downloads remain open.

## 2026-10-15 — KEYCHAIN-API-HASH-VALIDATION-14

- Read-only audit found `telegramAPIHash()` accepted any nonempty UTF-8 value although the explicit save path already required exactly 32 ASCII hex characters. It now rejects malformed stored values as `invalidTelegramAPIHash`; `errSecItemNotFound` remains a distinct missing-item result, and other Security errors remain fail-closed. No credential fallback or account identity was added.
- Added `telegramAPIHashReadUsesOnlyTheConfiguredItemAndRejectsInvalidStoredValues`, which uses only an injected fake backend and checks valid configured scope, unrelated service not found, interaction-not-allowed propagation, empty/malformed/non-UTF-8 values. Focused test passed 1/1. No real Keychain item was accessed.
- Source commit `380428973eb3d17041768e47a1e7fe08a4d7b91e` was pushed to `AffPapa/NeTelegram` main. Exact-source macOS CI [38627826560](https://github.com/AffPapa/NeTelegram/actions/runs/38627826560) passed; pinned TDLib/Dev.app workflow [38627822050](https://github.com/AffPapa/NeTelegram/actions/runs/38627822050) passed. No duplicate workflow dispatch.
- Rebuilt and opened the one canonical `/private/tmp/NeTelegram-Dev.app` from clean source 3804289. CUA confirms ordinary accountless sign-in view and AX identity; strict ad-hoc codesign verification passed. No login, profile creation, real Keychain query, or Telegram request.
- The earlier real data-return Keychain timeout's cause remains unproven; a prior non-value presence check recorded no configured item. This turn did not inspect real Keychain state. The user must enter a fresh/current API hash in NeTelegram secure settings before login. No Site deployment or app release.


## 2026-10-15 — AUTH-FORM-APPLE-HIG-14

- Research: current Apple macOS HIG guidance for layout, windows, text fields, accessibility, and keyboard input; inspected the official Telegram Desktop intro flow and style for interaction structure only. Its Qt/GPL implementation is not copied into the AppKit app.
- Changed `Sources/NeTelegramApp/main.swift`: reduced default auth window height to 560 pt; put country search and the native country menu on one aligned row; replaced the macOS-region disclosure with a short neutral format hint; focused the phone input first because a complete number can be entered without choosing a country. No auth/network/storage behavior changed.
- Verification: `git diff --check` passed. The one canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt from clean source `6a0b7bf96d821771df0e7045b8a7ccd635ef5581`; strict ad-hoc signature passed. CUA screenshot and AX confirm the compact alignment, no locale disclosure, phone-field initial focus, empty Continue disabled, and full non-affiliation note visible. No credentials, Keychain value, account or Telegram request was used.
- Exact-source macOS CI [38629446608](https://github.com/AffPapa/NeTelegram/actions/runs/38629446608) and pinned TDLib/native app workflow [38629446622](https://github.com/AffPapa/NeTelegram/actions/runs/38629446622) passed. Source commit is pushed to `AffPapa/NeTelegram` main. No release or Site deployment.
- Limits: dark accountless auth view only; VoiceOver speech, light appearance, IME/RTL, real login, authenticated chats and twenty-runtime behavior remain unverified.

## 2026-10-15 — APP28-PROD-CALLBACK-01

- Source: `468ab74ec4f9c16d4f22df99aac17c3a4326a5a9` pushed to `AffPapa/NeTelegram:main`. Added the production-used `RuntimeUpdateOwnership.consumeThenCheck` seam: await the account update reducer, check the coordinator route, then check MainActor-local runtime ownership before AppDelegate applies side effects. `AppDelegate.receive` and the gated replacement-generation regression both use this exact sequence.
- Verification: local `swift test --disable-sandbox --scratch-path /private/tmp/netelegram-app28-scratch --no-parallel --filter callbackAfterSuspendedIdentityPersistenceCannotApplyToReplacementRuntime` passed 1/1 and compiled NeTelegramApp; `git diff --check` passed. The first sandboxed SwiftPM invocation failed before compilation with `sandbox_apply: Operation not permitted`; retry with the repository-compatible `--disable-sandbox` flag passed. Exact-source macOS CI [38630779359](https://github.com/AffPapa/NeTelegram/actions/runs/38630779359) and pinned TDLib/hosted Dev.app workflow [38630779299](https://github.com/AffPapa/NeTelegram/actions/runs/38630779299) passed.
- Local bundle boundary: the read-only process guard confirmed PID `49828` is still running the sole canonical `/private/tmp/NeTelegram-Dev.app` from source `6a0b7bf`. It was not replaced; no local screenshot or current-source local bundle smoke is claimed. Checkpoint marks source `468ab74` pending while that exact bundle runs. No login, Keychain value, account or Telegram request was accessed. APP28 remains partial; APP01 and real-account/resource coverage remain open.

## 2026-10-15 — APP01-PIPELINE-20-01

- Test-only source commit `63fc2923d0e3a3ef5c68f8cbb06a9254c6db8fc9`; app source remains `468ab74ec4f9c16d4f22df99aac17c3a4326a5a9`. Extended the 20-profile restore composition test to exercise one injected `TDLibGateway` and the production `TDLibUpdatePipeline` after all twenty routes are registered. The test sends two updates per client; a delayed client 1 lane does not prevent clients 2–20 from completing both while selected UI account changes. After release, all clients preserve per-client `[1,2]` order.
- Local focused test passed 1/1 with Swift 6.4 / arm64. Exact test-only full serial macOS CI [38631444134](https://github.com/AffPapa/NeTelegram/actions/runs/38631444134) passed. No application source, binary, Site, credential, account or Telegram network request changed.
- APP01 remains partial: this synthetic composition does not invoke AppDelegate's runtime map retention or TDLib, authorize accounts, or measure 1/5/10/20 resources. The sole local Dev.app is still running PID `49828` at app source `6a0b7bf`; candidate app source `468ab74` remains pending local rebuild/smoke until normal quit.

## 2026-10-15 — AUTH-FORM-APPLE-HIG-15

- Research: reviewed current Apple HIG guidance for macOS windows, layout, text fields, keyboard input and accessibility; inspected official Telegram Desktop `intro_phone.cpp` for flow only. No upstream code, styles, assets or branding copied.
- Evidence/cause: the live form is a readable fixed-width AppKit column, but its `NSWindow` had no maximum. macOS Zoom could expand the window past the form and expose large empty margins; the chat workspace still needs resizing.
- Change: source `709b7552a0198d04b496c1b983dc980855d04de8` caps only authentication at 720x640 pt, retains 560x520 minimum and 620x560 initial size, and restores a generous maximum when the chat workspace appears. Longer auth states keep their scroll view. No auth/storage behavior changed.
- Verification: `git diff --check`; focused country-picker test passed 1/1 and compiled the app. Canonical `/private/tmp/NeTelegram-Dev.app` rebuilt once in place, CUA/AX confirmed current source identity, empty phone field, disabled Continue and disclaimer; native Window > Fill stayed within 720x640 pt and Restore returned to compact size. Strict ad-hoc code signature verified. Exact-source CI [38632656079](https://github.com/AffPapa/NeTelegram/actions/runs/38632656079) and pinned TDLib/native workflow [38632656062](https://github.com/AffPapa/NeTelegram/actions/runs/38632656062) passed.
- No login, Keychain value read, account/session creation, Telegram request, release or Site deployment. Light appearance, VoiceOver speech, IME/RTL, real login/chat and twenty real-account coverage remain unverified.
- Checkpoint metadata validation passed on commit `988d20784475a3acfd2a320d85589e5627b823df`: [38633083575](https://github.com/AffPapa/NeTelegram/actions/runs/38633083575). The later receipt-only metadata commit does not change app source or Dev.app bytes.

## 2026-10-15 — APP01-RUNTIME-OWNERSHIP / AUTH-HIG-COMPACT (working tree)

- Research: reviewed Apple macOS HIG for windows, layout, text fields, buttons, labels, color, accessibility and data entry; inspected Telegram Desktop `intro_phone.cpp`/`intro.style` structure for flow only. Telegram Desktop is Qt-based; no upstream UI code, styles or assets were copied.
- Screenshot comparison: the supplied image title is `dev 5f414650`; the actually open canonical app reports `dev 709b7552`. Current AX/screenshot shows native one-column AppKit controls, country label and aligned country search/picker, semantic system colors, phone initial focus and the independent-client disclosure. The attachment is stale relative to the open app.
- Working-tree changes: production runtime ownership is now centralized in `RuntimeOwnershipRegistry`; added an exact-generation 20-runtime retention/release test. Reduced the first-run auth content size to 600x520 pt while keeping the window resizable and longer auth states scrollable.
- Verification: focused ownership test passed 1/1 and compiled the app target; `git diff --check` passed. The open app was not replaced. Its normal Quit menu item was selected after prior user authorization, but the app remains visible and the process guard cannot prove absence; no force-kill or duplicate app was used.
- Status: uncommitted working tree on base `380c98c8258ef5be9fd09e043ee2dcfa85cf85d9`, matching `origin/main` at the last successful fetch. No exact-source hosted CI, current-source canonical visual smoke, public release or Site update yet.

## 2026-10-15 — AUTH-FORM-APPLE-HIG-16

- Research: checked current Apple HIG for macOS design, windows, layout, labels, text fields, and accessibility; checked AppKit `NSComboBox` documentation; reviewed Telegram Desktop phone and QR login flow as interaction reference only (Qt source; no code, assets, or styling copied). The supplied screenshot had inactive-window traffic lights, so its subdued controls were not treated as a contrast defect. Sources: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/ ; https://developer.apple.com/design/human-interface-guidelines/windows ; https://developer.apple.com/design/human-interface-guidelines/text-fields ; https://developer.apple.com/documentation/appkit/nscombobox ; https://github.com/telegramdesktop/tdesktop/blob/dev/Telegram/SourceFiles/intro/intro_phone.cpp .
- Change at exact source commit `9a3f4e7d8c412cffa3607c3a3133bbe67e6e40cf`: visible persistent “Номер телефона” label, normal first-run window 600×560 pt, system AppKit controls/colors/focus preserved; runtime ownership registry pairs AccountUUID and ClientID and releases only exact generation, with a 20-runtime retention regression. Auth’s longer states remain scrollable; chat window behavior unchanged.
- Local verification: focused country search test passed 1/1 and compiled app; runtime ownership test passed 1/1 earlier in the candidate. `git diff --check` passed. The canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt once from the exact clean source, strict ad-hoc signature passed, and active-window CUA/AX confirmed the new field label, phone focus, disabled Continue, country controls, and non-affiliation notice. No login, Telegram request, Keychain value, or account was used.
- GitHub: exact-source macOS CI passed [38635457080](https://github.com/AffPapa/NeTelegram/actions/runs/38635457080); pinned TDLib/native workflow passed [38635457154](https://github.com/AffPapa/NeTelegram/actions/runs/38635457154). Commit pushed to `AffPapa/NeTelegram:main`.
- Limits: accountless auth view only. Light appearance, spoken VoiceOver, IME/RTL, real login/chat, twenty real authorized runtimes and measurements, Developer ID/notarization, compatibility gates and public download remain unverified.

## 2026-10-15 — KEYCHAIN-DATA-READ-DIAGNOSTIC

- Reproduced the configured API-hash `SecItemCopyMatching` data-read stall in a separate, bounded 12-second probe using the app's service/account and noninteractive LAContext. A second variant with explicit UI-fail also timed out. Neither probe printed, copied, compared, or persisted the value; the existing Keychain item was not modified.
- Control: the same query shape for a deliberately nonexistent service/account returned `errSecItemNotFound` (-25300) in 11 ms. Prior attributes-only lookup of the configured item returned `errSecSuccess` in 3 ms.
- Interpretation: the delay is specific to retrieving data for the existing item, not a general slow Keychain lookup. Root cause is still unproven; this does not establish whether the canonical app can read the item. Do not delete/reset it or claim the value is missing. Owner-side recovery/authorization in the app is still needed before login.

## 2026-10-15 — AUTH-COUNTRY-EXPLICIT-CHOICE-01

- Design review: current Apple HIG on macOS windows, layout, text fields, keyboard access and accessibility; official Telegram for macOS (`overtake/TelegramSwift`, GPL-2.0) and Telegram Desktop (`telegramdesktop/tdesktop`, GPL-3.0) inspected read-only for interaction patterns. NeTelegram remains native AppKit; no upstream code, styles or assets copied.
- Observed defect in the canonical `1606fac8` screen: the country combo displayed Thailand +66 although `PhoneCountrySelectionState` had no explicit selection. A person could reasonably think the country was chosen while Continue remained disabled. This was caused by AppKit selection events during combo repopulation.
- Fix in `Sources/NeTelegramApp/main.swift`: suppress selection callbacks while rebuilding the combo and clear the visual row selection when no country was explicitly chosen. The placeholder now remains visible; local-number guidance says to select a country, while full international numbers remain supported.
- Verification: focused `macOSCountrySuggestionDoesNotSelectCallingCodeForPhoneLogin` passed 1/1; `git diff --check` passed. Canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt once from exact clean commit `f7afa4b6f92d58f624e5c368dc6892dd1db5506a`, ad-hoc signature verified, and CUA/AX/screenshot confirmed blank country placeholder, explicit-choice guidance, empty phone field, disabled Continue and non-affiliation notice. No login, Keychain data read, profile creation or Telegram request.
- Exact-source macOS CI [38648192535](https://github.com/AffPapa/NeTelegram/actions/runs/38648192535) and pinned TDLib/native workflow [38648192560](https://github.com/AffPapa/NeTelegram/actions/runs/38648192560) passed. Commit pushed to `AffPapa/NeTelegram:main`.
- Limits: accountless auth flow in dark appearance only. Full keyboard country selection after the fix, VoiceOver speech, light/high-contrast appearance, IME/RTL, real login/chats, twenty authorized runtimes and resource measurements remain unverified. No release or download was created.


## 2026-10-15 — AUTH-FORM-APPLE-HIG-17

- Replaced the phone field’s duplicate placeholder with `Введите номер`; the separate visible label remains. This was a narrow HIG refinement, not a redesign or release.
- Exact-source macOS CI 38637208931 and pinned TDLib/Dev.app workflow 38637208825 passed for app commit `47247149939e825c23b5816573e42ff5101c7b94`. One canonical arm64 Dev.app was rebuilt, strict ad-hoc signature verified, and active-window CUA/AX plus screenshot confirmed the label, placeholder, disabled Continue, country controls, and no profile UUIDs.
- Site version 196 deployed publicly from Site source `4d2bb028425fba0936e6b01f1536e22d8d71a90a`; anonymous devlog route showed this bilingual entry. Downloads still has no installer. Site archive SHA-256: `3ffc12d8c33ab5447c64a7c6d149bd41dd143749f860cc9b1e7b708301bc1c1c`.
- Limits: no real login or credentials; light appearance, spoken VoiceOver, IME/RTL, 20 authorized runtimes, Developer ID/notarization, and release readiness remain unverified.

## 2026-10-15 — APP02-RESTORE-STALL-DEDUP-01

- Added and pushed test-only commit `72fbbf70eafc90f4e87f6c7a1103b07e84e27fc0` to `AffPapa/NeTelegram:main`. The regression composes restore planning, startup registry, parallelism=2 and injected Keychain preparation over 20 synthetic profiles; one stalls, one fails, the other 18 finish, duplicate scheduling is suppressed, existing DB/draft marker bytes remain unchanged, then 19 finish after releasing the stall.
- Verification: focused Swift 6.4 test passed 1/1; [full serial macOS CI](https://github.com/AffPapa/NeTelegram/actions/runs/38638917609) passed 195 tests on the exact test commit. App source remains `47247149939e825c23b5816573e42ff5101c7b94`; canonical Dev.app was not rebuilt.
- Limits: synthetic coordination only. Does not prove production AppDelegate restore, real Keychain, TDLib sessions, authorized accounts, or resource measurements. No login, Telegram request, or secret access.

## 2026-10-15 — APP03-AUTH-COUNTRY-LAYOUT-HIG-01 / Site v197

- Prompt/roles used: Apple macOS HIG reviewer (research and critique); senior AppKit engineer (source review and implementation); parent retained implementation, build, tests, publication, and synthesis. No external AI service.
- Research: current Apple HIG for [macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/), [windows](https://developer.apple.com/design/human-interface-guidelines/windows), [layout](https://developer.apple.com/design/human-interface-guidelines/layout), and [keyboard/focus](https://developer.apple.com/design/human-interface-guidelines/keyboards/) plus Telegram Desktop's [phone-login source](https://github.com/telegramdesktop/tdesktop/blob/dev/Telegram/SourceFiles/intro/intro_phone.cpp). Adopted the interaction sequence and spacing/alignment principles only; did not copy Qt code, assets, styles, or branding. macOS-specific guidance favors fluid window layouts, readable content density, system-native window controls and keyboard navigation.
- Diagnosis: the prior search field was substantially narrower than the country picker; visual group read as unrelated controls. Change: AppKit search and picker now use equal widths and stack in one country section. Auth logic is unchanged. The wide-window empty space remains controlled by the existing authentication window sizing policy; the main chat workspace remains resizable.
- Local evidence: app source `c78cc2d1dc8396b535da7b3ed0ea737a36cc891c`; canonical `/private/tmp/NeTelegram-Dev.app`, arm64, macOS 14 baseline, Swift 6.4, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`, ad-hoc development signing. Source fingerprint `c30a10cbe91fb1505efeccba2d7f7dd7fad91243d0da00f52ad959bedb175cbf`; executable SHA-256 `b687b30c46d103240e0598937590bbcefa4d8b485c2363cba39989c2547368aa`. AX/screenshot visual check: `/var/folders/tq/cx6qnzks0nd8_c0y80rf3j300000gp/T/codex-shot-2026-10-15_04-24-25.png`. Focused country picker test 1/1 and exact-source macOS CI (195 tests) passed. No dedicated layout-geometry assertion. Pinned native workflow passed: [38639702835](https://github.com/AffPapa/NeTelegram/actions/runs/38639702835); source suite: [38639702753](https://github.com/AffPapa/NeTelegram/actions/runs/38639702753).
- Site: corrected product title and stale UI claims; factual bilingual devlog and Site source mirror pushed at `5ccf76520ee40da2d5e9117b3ef9c7875c351da7`. Official helper source commit `1837384f6d060a5140403fc8311f5b6975b1465c`; archive `/private/tmp/netelegram-site-v197-20261015.tar.gz`, SHA-256 `3871f94a81463a0b19dfd5ce29478490e5b54b97efc3dc546d1df2f89a3286d3`. Site API confirms public version 197, source/archive provenance, and deployment `appgdep_6acff49f1a008191be167f5d85e7d34b` succeeded. Live route check: HTML routes and empty alpha/stable XML feeds returned 200; no ZIP/DMG links.
- Checkpoint: `PROJECT-STATE.json` and `ACCEPTANCE.json` now point to app source `c78cc2d`, repository checkpoint `5ccf765`, canonical Dev.app fingerprint/executable digest, and Site v197. `python3 Scripts/validate_checkpoint.py` and `git diff --check` passed. The separate legacy checkout remains untouched.
- Limits: no login/Telegram account used; no native VoiceOver speech, light/high-contrast appearance, RTL/IME, real chat, or twenty-account measurement. Developer ID/notarization, API Terms gates, signed distribution, and application download remain open. Site v197 is a development publication, not an application release.

## 2026-10-15 — APP04-AUTH-SEARCHABLE-COUNTRY-COMBO-02 / Site v199

- Research basis: Apple HIG for macOS windows, text fields, combo boxes, keyboard navigation, and accessibility. The native form keeps system controls/chrome, Auto Layout, semantic colors, explicit labels, and keyboard selection. Telegram Desktop was used only as an interaction reference; no code/styles/assets copied.
- Final source: `1606fac85dcae324b60fc6b86296e25bde4d4a31`. Fixes after native smoke found two actual AppKit integration defects: field-editor typing did not filter the combo, and choosing a row did not update sign-in state. The focused country test passed 1/1. Exact-source macOS CI [38644591432](https://github.com/AffPapa/NeTelegram/actions/runs/38644591432) and pinned TDLib/Dev.app workflow [38644591410](https://github.com/AffPapa/NeTelegram/actions/runs/38644591410) passed.
- One canonical arm64 `/private/tmp/NeTelegram-Dev.app` was rebuilt from clean exact source `1606fac`; source fingerprint `79ca53b8eb2271abc162c41d36d8e68e5c97bac6826f8b83433b31ebd9609a53`, executable SHA-256 `bb6594930d0a4e413bca658d5409f08813152f8709c2f8b006ea57114e5819ea`, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Strict ad-hoc signature passed. Native accountless smoke: `66` filtered results; keyboard selection applied Thailand +66; label updated; empty phone and disabled Continue verified. No credentials, profile, or Telegram request.
- Site source entry is bilingual. Official helper commit `7efb8fb56007891e667f3561afaf5c1d5fe1b3b9`; saved Site v199 `appgver_603c6fe1a3f48191ac7d0186346f0966`, deployment `appgdep_6acffc91b6a88191b0565bcef22d2c30`, public URL https://netelegram.iryadom.chatgpt.site/devlog/. Anonymous AX verification found the new article and its exact CI links. Platform archive hash `sha256:3ca1e414204765b787d3e792427f00f3e207368a57f0f38f2fe0f8a3398a541d`, 512000 bytes, 14 files.
- Limits: accountless dark-appearance auth only. No real login, VoiceOver speech, light appearance, IME/RTL, chat, or 20 real-account test. No Developer ID/notarized release or application download. Existing API-hash Keychain retrieval stall remains unresolved; preserve the item and do not reset it.

### AUTH05-COUNTRY-SELECT-NATIVE-01 — native filtered country selection

- Canonical checkout: `/private/tmp/netelegram-cli-work`; app source `f7afa4b6f92d58f624e5c368dc6892dd1db5506a`; canonical bundle `/private/tmp/NeTelegram-Dev.app`, window title `NeTelegram · dev f7afa4b6`.
- On the already-running arm64 Dev.app, set the native country combo query to `Canada`, opened its native results, then used Down/Return to select the filtered result. AX reported `🇨🇦 Canada +1`; the country row closed, the phone label appeared, the phone field remained empty and Continue remained disabled. Screenshot visually confirmed the selected country and form hierarchy.
- No phone number, auth code, API hash, profile, session, or Telegram request was used. No build/relaunch was needed because the exact canonical app source was already running. Existing exact-source CI remains run 38648192535; pinned TDLib/Dev.app workflow remains 38648192560.
- Limitation: this was a credential-free native interaction smoke, not a Telegram login, VoiceOver speech test, light-mode/RTL/IME test, or real-account check. The combo search value was set via the accessibility value setter before opening the native results; selection itself was confirmed with keyboard navigation.


## 2026-10-15 — AUTH-FORM-APPLE-HIG-18

- Research: reviewed current Apple HIG for macOS windows/layout, color, text fields, buttons, keyboard access and accessibility; checked AppKit `NSComboBox` behavior and Telegram Desktop phone-login interaction as a reference only. No Telegram source, style or asset was copied.
- Changes: system preferred text styles for auth heading/help; left-aligned email/password input; compact aligned Continue/QR actions; decorative N omitted from VoiceOver; independent-client disclosure label now matches its visible text. Native keyboard testing found Tab skipped the country combo. Commit `29480aad9abdcb24e2864124b62e93700d900737` routes Tab from blank/local phone entry to country search; a leading `+` keeps direct international-number flow. Country selection returns focus to phone.
- Verification: `swift build --disable-sandbox --target NeTelegramApp` passed; `git diff --check` passed. One canonical `/private/tmp/NeTelegram-Dev.app` rebuilt, exact source identity `29480aad`, arm64, Swift 6.4, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`; strict ad-hoc signature passed. CUA/AX verified Tab focus on country combo, filtered Canada result selected by Down/Return, then empty phone focus and disabled Continue. No account, phone, code, API hash or Telegram request. Exact-source macOS CI [38650138609](https://github.com/AffPapa/NeTelegram/actions/runs/38650138609) and pinned TDLib/native workflow [38650138657](https://github.com/AffPapa/NeTelegram/actions/runs/38650138657) passed.
- Limits: no real login, spoken VoiceOver, light/high-contrast, IME/RTL, or real 20-account test. Dev.app is ad-hoc signed; Developer ID/notarization, compatibility gates, signed release and application download remain open. The public Site remains at v201 and has not yet recorded this entry.

## 2026-10-15 — AUTH-FORM-APPLE-HIG-18 / Site v202 checkpoint reconciliation

- Public verification: anonymous browser tab 5 loaded `https://netelegram.iryadom.chatgpt.site/devlog/`; screenshot showed the bilingual Apple HIG entry for app source `29480aa`, the HIG links, and CI runs `38650138609` / `38650138657`.
- Site v202 exact state: project `appgprj_6acba85192e08191acdf7011928848cf`, saved version `appgver_68a54ed1506081919209d2dec2d8f11d`, source commit `8808f6a9b8ccf6b93d2eff2c87c5f25b83275ac0`, deployment `appgdep_6ad00803945881918cc7062c53c2c10c`, archive content hash `sha256:bbb7f6b05bd853e680df6c613334920cd6d3a1b839aa9d9ab6e83ad4fdda1aab` (522240 bytes; 14 files). Public downloads remain absent because no signed/notarized app release exists.
- Reconciled `PROJECT-STATE.json` and `ACCEPTANCE.json` to the exact app source `29480aad9abdcb24e2864124b62e93700d900737` and Site v202. Removed the stale next action to add a devlog entry; remaining next step is the preserved Keychain data-read diagnosis, followed by owner-operated single-account acceptance.
- No account, profile, auth credential, API hash or Telegram request was used in this verification. Checkpoint metadata validation and commit/push are pending.


## 2026-10-15 — APPLE-HIG-CURRENT-AUTH-AUDIT-01 / Site v205

- Research: reviewed Apple's macOS guidance for windows, layout, fields, appearance and accessibility. Inspected official Telegram iOS and Telegram Desktop repositories only for product constraints and broad interaction context; Telegram Desktop is Qt, so its custom visual style was not copied. Sources: Apple [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields), [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS), [Telegram Desktop](https://github.com/TelegramOrg/Telegram-desktop).
- Evidence: user's attached screenshot title is `NeTelegram · dev 5f414650`, but the running canonical window is `NeTelegram · dev b6851921`. Captured current window at `/var/folders/tq/cxqnzks0nd8_c0y80rf3j300000gp/T/codex-shot-2026-10-15_06-07-38.png`; AX confirmed the native AppKit form. Current layout has native controls/frame, system colors, explicit labels, consistent field widths, disabled Continue until valid input, QR path, non-affiliation disclosure and scroll support. No concrete defect remains in this exact current screenshot, so no arbitrary redesign or rebuild was made.
- Exact current bundle: `/private/tmp/NeTelegram-Dev.app`, arm64, source `b6851921778867fc5d0233236e59bd6c40b61af8`, fingerprint `52d15f878a7e4666bc94e5c8a8dda6d58280a5ffcef6a973300786d7315fe48b`, executable SHA-256 `c9c39cfee31a58a108b7b2baaf1ad7e73b0f9724a9d402bd7b54fd38f9448d54`, strict ad-hoc signature check passed. No account or Telegram request. Existing APIHash tests 6/6; exact macOS CI [38651617037](https://github.com/AffPapa/NeTelegram/actions/runs/38651617037) and pinned TDLib/Dev.app workflow [38651617028](https://github.com/AffPapa/NeTelegram/actions/runs/38651617028) passed.
- Site corrections: shared header mark changed from `A` to `N`; footer now says NeTelegram is an independent macOS app based on Telegram API and has no direct relationship to Telegram Messenger LLP. Refreshed current homepage/features pointers to `b685192` and its exact CI; historical journal entries were preserved. Local build/validation passed for all 8 routes. Sites helper could not resolve `git.chatgpt-team.site` in sandbox; the same official helper succeeded with the permitted network route. Site v205 (`source 9806d3cfe7c884b9d99f8b212cf37cc5b129a6ad`, saved `appgver_cc9fb89692fc819196753d8a9769bbb4`, deployment `appgdep_6ad00cf339f881919e812292ccee668e`) is public. Archive: `sha256:3548cfebfd6665b6926942190986e5ff62a7dd4b20977b2d1862598373dfa1a6`, 522240 bytes, 14 files; local archive SHA-256 `36e1411001337ecfe21624f6c5efd22c3e5a870f1ec8f93f7e668151767d5ae4`. Anonymous homepage and `/features/` confirmed current source, exact runs, truthful no-download status, and NeTelegram brand.
- Limits: no real login, spoken VoiceOver, high-contrast, fresh dark appearance, IME/RTL, or 20-account run. No Developer ID/notarization or app release. The existing Keychain data-read stall remains undiagnosed; do not replace or reset the item.

## 2026-10-15 — NeTelegram identity and current auth-window HIG audit

- Apple HIG research used official macOS guidance for [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields), [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data), and [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos). These support system window controls, compact and content-appropriate sizing, aligned labeled fields, adaptive layouts, and keyboard/accessibility behavior. The current AppKit source already sets the auth window to 600×560 with a bounded resizable range and native controls; no additional visual change or rebuild was justified from the older attached screenshot.
- Current runtime identity was checked through CUA: `NeTelegram · dev b6851921`, bundle `org.affpapa.netelegram.dev`. Attached screenshot title was `dev 5f414650`, so it does not show the current build. The current AX tree confirms the country combobox, visible field labels, disabled Continue, QR action, and non-affiliation note. No login or secret was entered.
- Restored NeTelegram as the public product name in bilingual README, release gates, architecture header, and current checkpoint. Telegram API Terms §2.3 remains explicitly unresolved; no stable/API-compatibility pass is claimed. Historical RUN-LOG entries are not rewritten.
- Live anonymous Site `/downloads/` currently has title/footer “AffPapa Chat” despite Site metadata saying NeTelegram. The Site helper did not open its remote checkout after the documented input and empty-checkout corrections; helper output remained the generic `Unable to prepare the Site.` No Site push, save, or deploy occurred. The checkpoint now records this route-level conflict and does not claim Site-wide coherence.
- Focused checks: `python3 Scripts/validate_checkpoint.py` passed; `git diff --check` passed. App source, canonical Dev.app, and release candidate were not changed. Product remains partial; app downloads remain absent.


## 2026-10-15 — SITE-205-CANONICAL-ROUTE-VERIFIED-01

- Current external state: `sites_get_site` confirmed the existing Site is public, owned by this account, active, and latest version 205. In the already-open browser tab, the old URL `https://netelegram.iryadom.chatgpt.site/downloads/?verify=291cd0a7` showed stale “AffPapa Chat” content. Navigating the same tab to the canonical `https://netelegram.iryadom.chatgpt.site/downloads/` produced title “Загрузки и установка — NeTelegram”; AX confirmed NeTelegram in header/footer, no verified app download, and the current release-blocker text. No Site mutation was needed.
- Site source identity was verified in the dedicated existing checkout `/private/tmp/netelegram-site-open-20261015.u3sEzt`; the official Sites helper fetched the current remote source commit `9806d3cfe7c884b9d99f8b212cf37cc5b129a6ad`. `python3 build_site.py` rendered 8 routes and `python3 validate_site.py` passed all 8 routes, shared shell, active navigation, canonical metadata, local links, and assets. No push, save, or deploy occurred in this step.
- The visible mismatch came from the stale query URL, so the prior “repair all Site routes” next action is retired. Next: production profile-start injection/coverage, then owner-entered fresh API hash and one real-account acceptance. The chat-pasted hash remains retired; no secret value was read or used. Product/release acceptance remains partial.

## 2026-10-15 — CORE-RUNTIME-06 production profile startup sequence

- Added `ProfileRuntimeStartupSequence` as the shared ordering boundary and connected the production `AppDelegate` profile opener to it. The 20-synthetic-profile stall/failure/retry regression now executes the same helper used by production. Route registration precedes runtime retention; receive pipeline and waiting state precede the first TDLib initialization request. Cancellation before retention removes the coordinator route without starting the pipeline or queuing work.
- Local Swift 6.4 startup-filter suite passed 12/12, including the exact 20-profile synthetic scenario and two focused sequence/cancellation tests. Pushed app commit `28316749de929865f253d7c999cb7ddd04bb79ce` to `AffPapa/NeTelegram:main`; exact-source macOS CI run [38655539405](https://github.com/AffPapa/NeTelegram/actions/runs/38655539405) succeeded. Pinned TDLib/Dev.app workflow [38655539350](https://github.com/AffPapa/NeTelegram/actions/runs/38655539350) succeeded for the exact source after initial checkpoint recording.
- Rebuilt the one canonical `/private/tmp/NeTelegram-Dev.app` from the exact clean commit using `Scripts/dev-app.sh --launch`. Build record: source fingerprint `7845e763045f0c64656e95f782f0fc35d2212be9d9cf8f4c24c86c2b67eb7d81`, executable SHA-256 `dd552505b81f963514cf9d88103d2b21115c1659cc68d241a24aaa2f11063f03`, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`; ad-hoc strict signature verification passed. CUA/AX title is `NeTelegram · dev 28316749`; accountless auth screen only, no Telegram request or credential use.
- Corrected the current Site checkpoint copy: public canonical `/downloads/` is NeTelegram, the old AffPapa Chat display came from a stale query URL, and no app download exists. Site v205 was not modified or redeployed.
- Scope remains synthetic: zero real Telegram logins and zero certification of 20 live TDLib runtimes or their resource use. Developer ID/notarization, policy compatibility, updater, public app release/download, and real-account acceptance remain open. Next gate is one owner-operated login/read/send/logout using a fresh API hash entered only in the app; the value pasted in chat remains retired.
- `Scripts/validate_checkpoint.py` and `git diff --check` passed after current app/bundle/Site pointers were reconciled.


## 2026-10-15 — AUTH-FORM-APPLE-HIG-19

- Research: current Apple macOS HIG for windows, layout, text entry, buttons and accessibility; GitHub AppKit `NSStackView` examples were reviewed as implementation references only. No UI framework, styles or source were copied.
- Diagnosis: screenshot `dev 5f414650` was stale. In the current canonical app before the change (`dev 28316749`), the phone input column was 400 pt while the primary Continue button was 240 pt.
- Change: aligned the primary button to the form's 400 pt width. Native AppKit styling, QR secondary action, keyboard behavior, accessibility, disabled-until-valid policy and auth logic remain unchanged. Source commit `e8bd672a8888b654f615cdc17d8c78523a9368c6`, pushed to `AffPapa/NeTelegram:main`.
- Verification: Swift 6.4 `NeTelegramApp` target build and `git diff --check` passed. Exact-source macOS CI [38656376840](https://github.com/AffPapa/NeTelegram/actions/runs/38656376840) passed; pinned TDLib/Dev.app workflow [38656376900](https://github.com/AffPapa/NeTelegram/actions/runs/38656376900) passed. Rebuilt once at `/private/tmp/NeTelegram-Dev.app`; CUA screenshot confirms matching input/button widths and AX confirms empty phone, disabled Continue and unchanged auth options. Strict ad-hoc signature passed.
- Limits: current native smoke was light appearance/accountless only. No login, Keychain value read, Telegram request, VoiceOver speech, IME/RTL, 20-real-account test, Developer ID or notarization. No app release. Public Site remains v205 and was not changed in this slice.

## 2026-10-15 — AUTH-FORM-APPLE-HIG-19 site journal published

- The existing public NeTelegram Site source commit `882571a64ae9faf1d04e2ba484a341de03f4bc73` was packaged and saved as Site version 206 (14 files; provider content hash `sha256:f9aed986b53c165b9adadec0b987d000bed7655f545ee9f3d5b06e4d1a83f8ff`; local source archive SHA-256 `ced0bb759587ac4030df1930ae0222210e6eff8108eb5384ea05c12b2eeb6677`). Production deployment `appgdep_6ad0163f6f008191a654828ba11788f3` succeeded at the existing public URL.
- Anonymous CUA opened `/devlog/` and confirmed the bilingual `auth-form-primary-action-hig-19` entry, the exact app-source link `e8bd672`, and links to the successful exact-source workflows. `/downloads/` remains honest: no verified binary is available. This Site update did not publish or imply an app release.
- Reconciled all current Site pointers in `PROJECT-STATE.json` and `ACCEPTANCE.json`; the `Sites get_site` response, saved version provenance, deployment status, and public route agree on version 206. No credentials were used or retained in the checkpoint.

## 2026-10-15 — AUTH03 appearance follow-up on exact Dev.app

- Read-only native review used the already-running canonical `/private/tmp/NeTelegram-Dev.app`, identified by window title `NeTelegram · dev e8bd672a`; no rebuild or account data access occurred. The login form was visually checked in both light and dark macOS appearance. Labels, country control, empty-input disabled action, QR action, affiliation note, and the matching field/action widths remained visible and legible.
- macOS Appearance was restored to the pre-check Automatic setting and System Settings returned to its original General pane. A pointer-based attempt to resize the app did not reach the NeTelegram window; no resize result is claimed. The source minimum is 560×520 pt, but visual minimum-size coverage remains open, as do formal contrast measurement, high-contrast mode, VoiceOver speech, IME/RTL, later auth steps, and real login. AUTH03 stays partial.
