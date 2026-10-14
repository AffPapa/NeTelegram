# Telegram Desktop UI research for NeTelegram

Research snapshot: 2026-10-14. The upstream `dev` branch resolved to commit
`d77f486228a98e15d6695514d5f2b28ce1c6a872`. This matches the project
checkpoint. Source files were fetched through the GitHub connector at this
exact commit; links below are pinned and do not follow a moving branch. This is
a source-structure review, not pixel parity. NeTelegram remains a native
AppKit client and does not copy Telegram Desktop's implementation or feature
surface.

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

At current app source `4e54ce8d7c03ac92905de498b45f0bfc9b57cc52`, the AppKit
shell still has the researched two-pane hierarchy, separate header/history/
composer, search, selected chat and visible unsupported content. The prior
chat-list pagination trigger could become stuck when the viewport reached the
end before the first TDLib page completed; it now gates per account, waits for
`.loaded`, and rechecks the same viewport after completion. A response also
clears the originating account's gate even if that account is now backgrounded
or the privacy lock is active; only the selected, unlocked account refreshes
visible UI. Deterministic regressions pass 3/3, and exact-source macOS CI passes
185/185. Synthetic
chat-ID-colored initials were removed in favor of a neutral system placeholder,
so the UI does not imply a discovered avatar or identity. The canonical Dev.app
is open on its accountless first-run screen. Real chat rows/avatar rendering,
VoiceOver, IME, RTL and photo-bearing conversations still require a
user-authorized account and visual review.
