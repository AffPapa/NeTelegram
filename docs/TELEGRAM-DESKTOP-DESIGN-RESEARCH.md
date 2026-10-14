# Telegram Desktop UI research for NeTelegram

Research snapshot: 2026-10-14. The upstream `dev` branch resolved to commit
`d77f486228a98e15d6695514d5f2b28ce1c6a872`. This matches the project
checkpoint. Source files were fetched through the GitHub connector at this
exact commit; links below are pinned and do not follow a moving branch. This is
a source-structure review, not pixel parity. NeTelegram remains a native
AppKit client and does not copy Telegram Desktop's implementation or feature
surface.

## Apple platform review

Reviewed Apple's current guidance for [designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/), [windows](https://developer.apple.com/design/human-interface-guidelines/windows), [layout](https://developer.apple.com/design/human-interface-guidelines/layout), [text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields), [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [typography](https://developer.apple.com/design/human-interface-guidelines/typography), [color](https://developer.apple.com/design/human-interface-guidelines/color), [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode), and [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility). For this AppKit client, the applied rules are:

- Keep normal window chrome and native controls so active/inactive, light/dark,
  focus-ring, keyboard, and system accessibility appearances remain platform
  owned. Use semantic colors instead of fixed gray values.
- Build resizable content from Auto Layout relationships and a small number of
  consistent widths. Keep the first-run sign-in form compact and centered;
  avoid a decorative card that competes with the native window surface.
- Order the sign-in task as country lookup/selection, phone number, one concise
  status or validation line, primary action, then the alternate QR action.
  Avoid duplicating the same instruction in the subtitle, control placeholder,
  and status text.
- Use system font styles and labels, preserve keyboard focus and full keyboard
  access, and make controls understandable without color. Screen-reader speech
  and real IME interaction still require native-user verification.
- Keep helper text in a readable system text size and semantic color; do not
  lower contrast with fixed gray values. Give each step one clear instruction,
  retain a separate status line only when it communicates new progress or an
  error, and keep secure input in `NSSecureTextField`.

### Sign-in vertical rhythm update

Apple's current [layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout)
calls for layouts that adapt across window sizes; its [macOS window guidance](https://developer.apple.com/design/human-interface-guidelines/windows)
also recommends system window behavior and fluid resizing. The sign-in stack
now remains a compact centered group when the window grows. Its scroll document
keeps at least the visible viewport height and expands only when a longer
authorization step needs scrolling, instead of stretching the stack between
the document's top and bottom edges. This keeps the country row, phone input,
status, primary action and QR action at stable relative spacing. The legal
non-affiliation note uses a 13 pt system font and semantic secondary label
color. No fixed dark palette or custom title bar was added; disabled controls
remain AppKit's native disabled state.

The authentication hierarchy was cross-checked against Telegram's public
[iOS phone-entry controller](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift)
as a structural reference only: explicit country selection, number entry,
validation and a deliberate continue action. Its UIKit implementation, assets,
and styling are not copied into this native AppKit client.

The exact-source macOS test workflow and pinned TDLib/Dev.app assembly passed
for source `78763f3`. The generated development bundle now uses `NeTelegram Dev`
for both `CFBundleName` and `CFBundleDisplayName`, and the sign-in mark is N. A native visual PASS is
still pending: the one canonical local Dev.app is running an older build with
the protected API-hash setup dialog open. The screenshot tagged `dev 5f414650`
is historical and is not evidence for the current source. The screenshot's
gray primary button looks disabled; that old image does not establish why it
was disabled. The active source keeps AppKit's native control state and
semantic system colors. Keep the native
smoke pending until that same canonical process is safely closed and rebuilt.

Review of the current accountless screen found that country search and the
country menu each consumed a full row, and the code/2FA preview repeated the
subtitle's instruction as a second status line. The login form now places the
searchable country field and native country menu side by side on the same 360 pt
grid, with the phone field below; the status identifies the selected/suggested
region briefly. Authorization status is hidden only when it exactly repeats
the visible subtitle; distinct progress and error messages remain visible. The
phone value, TDLib request, and country-selection policy are unchanged. This is
a focused layout correction, not a claim that authenticated conversation
screens have passed visual review.

## Useful interaction structure

- **Workspace:** Telegram Desktop separates main navigation, dialogs and the
  active history, adapting composition to available width. For NeTelegram on
  macOS, retain the simpler two-pane split: one searchable dialog list and one
  active conversation. Do not imitate its full three-column/power-user shell.
  See [`mainwidget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/mainwidget.cpp)
  and [`dialogs_widget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/dialogs/dialogs_widget.cpp).
- **Conversation list:** Treat a row as a compact scan unit: identity, latest
  message, recency, unread/mute state. Selection should remain visually,
  keyboard and VoiceOver distinct. Transfer only states backed by NeTelegram's
  own data model. See [`dialogs_row.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/dialogs/dialogs_row.cpp)
  and [`dialogs_inner_widget_accessibility.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/dialogs/dialogs_inner_widget_accessibility.cpp).
- **Conversation header:** Keep chat identity, relevant status/context and the
  typed forum topic together. Include only actions that NeTelegram actually
  implements. See [`history_view_top_bar_widget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/history/view/history_view_top_bar_widget.cpp).
- **Message history:** Keep chronological order and distinguish message
  bodies, service events, replies and unsupported content. Telegram Desktop's
  history tracks the visible range and unloads off-screen user pictures; this
  supports NeTelegram's bounded image work and visible-chat policy. See
  [`history_view_list_widget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/history/view/history_view_list_widget.cpp)
  and [`history_view_element.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/history/view/history_view_element.cpp).
- **Composer:** Keep text entry anchored beneath history. Attach reply/edit
  context to the field in a separate, dismissible header; keep photo selection
  separate. NeTelegram excludes voice, sticker, animation and emoji-picker
  controls. See [`history_view_compose_controls.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/history/view/controls/history_view_compose_controls.cpp)
  and [`message_field.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/chat_helpers/message_field.cpp).
- **Accessibility:** Give list rows, messages, composer and primary actions
  names and predictable focus. Use a small macOS Command-key shortcut set
  rather than copying desktop shortcuts verbatim. See the accessibility file
  above and [`shortcuts.cpp`](https://github.com/telegramdesktop/tdesktop/blob/d77f486228a98e15d6695514d5f2b28ce1c6a872/Telegram/SourceFiles/core/shortcuts.cpp).

## NeTelegram design direction

Use a restrained AppKit workspace: a readable conversation list, flexible
history, compact chat/topic header and persistent composer. Keep macOS
typography, focus rings, menus, system appearance and window behavior. Rows
should answer “which chat, what happened last, when, and is anything unread?”
Use actual TDLib identity/avatar data where available; a fallback must read as
a placeholder, never as a discovered profile. Use semantic selection that
works in light/dark appearance and accessibility contrast settings. Message
direction derives from TDLib `is_outgoing`; account/chat/topic routing remains
independent of the selected interface.

Distinguish initial loading, an actually empty list, empty search results and
errors. Do not fill any state with sample profiles or invented conversations.
Only add empty/loading/error states alongside the real account data and request
state needed to make their wording truthful.

Telegram Desktop is GPL-3.0-or-later. This review transfers information
hierarchy and state ownership only. Do not copy its source, artwork, icons,
branding or licensed implementation into NeTelegram's MIT codebase. Do not
bring in calls, voice chats, recording, general video playback, animated GIFs,
stickers, emoji/reaction composers, Stories, Mini Apps, AI, payments or
controls whose actions are not implemented.

## Current implementation evidence and limits

At app source `15002caccc16953cd3fd093ab9fb7ddca205ca1e`, ordinary text
messages changed from generic sender-prefixed transcript lines to aligned,
rounded incoming/outgoing surfaces. The focused unsafe-link and UTF-16 entity
checks passed; exact-source macOS CI
[`38584832394`](https://github.com/AffPapa/NeTelegram/actions/runs/38584832394)
passed for final source `1408ab5`. This is implementation evidence, not live
visual parity.

At app source `9e0af7a46c1904600cdfc8eeb1e3716239b7cb95`, the AppKit shell
retains the two-pane hierarchy, separate header/history/composer, search,
selected chat and visible unsupported content. Conversation rows now have
stable view identity across TDLib refreshes: changed row presentation and its
accessibility label update in place; added/removed rows reconcile by chat ID;
existing views move only when the server ordering changes. Search, empty/loading,
revoked-account and privacy-clear paths still discard row caches. The isolated
`NeTelegramApp` build passed, exact-source macOS CI
[`38611394780`](https://github.com/AffPapa/NeTelegram/actions/runs/38611394780)
passed, and pinned TDLib/Dev.app workflow
[`38611394887`](https://github.com/AffPapa/NeTelegram/actions/runs/38611394887)
passed. These checks prove compile/test and bundle assembly, not a measured
large-list performance improvement or local visual behavior.

The canonical local Dev.app remains a separate artifact at source
`291cd0a7fb27b07be13fdd9e2d4e2ef8f3b4311b`. The old screenshot title
`5f414650` identifies an even earlier build. The current process is still open,
and the app-specific API-hash Keychain lookup returned `not_found`; no app
replacement or local smoke was attempted. Real chat rows/avatar rendering,
VoiceOver, IME, RTL and photo-bearing conversations still require visual review;
authenticated behavior requires an owner-operated login.
