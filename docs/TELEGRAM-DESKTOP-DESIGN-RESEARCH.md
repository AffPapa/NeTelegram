# Telegram Desktop UI research for NeTelegram

Research snapshot: 2026-10-14. The upstream `dev` branch resolved to commit
`fad667c6d71c5e965a9da71e48dc1ab82ba0568d`. The links below pin that commit.
This is a source-structure review, not a pixel comparison or a claim of visual
parity. Telegram Desktop is a large Qt application; NeTelegram remains a
native AppKit client and does not copy its implementation or feature surface.

## Useful interaction structure

- **Conversation list:** Each row communicates identity and recency through a
  compact avatar, title, one-line preview, timestamp, and unread state. Keep
  selection distinct, keyboard reachable, and accessible without relying on
  color alone. See [`dialogs_row.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/dialogs/dialogs_row.cpp)
  and [`dialogs_inner_widget_accessibility.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/dialogs/dialogs_inner_widget_accessibility.cpp).
- **Conversation header:** Keep chat identity, useful presence/context, and
  supported actions together. NeTelegram needs the chat name, status and typed
  forum topic; it does not need Telegram Desktop's many product-specific
  controls. See [`history_view_top_bar_widget.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/history/view/history_view_top_bar_widget.cpp).
- **Message history:** Present a chronological stream where message bodies,
  dates/service events, replies and unsupported media read as different kinds
  of content. Keep unsupported content visible with a clear explanation. See
  [`history_view_element.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/history/view/history_view_element.cpp)
  and [`history.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/history/history.cpp).
- **Composer:** Keep the text field anchored at the bottom, with reply/draft
  context attached and photo attachment separate. Exclude voice, sticker,
  animation and emoji-picker controls per NeTelegram's product scope. See
  [`history_view_compose_controls.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/history/view/controls/history_view_compose_controls.cpp)
  and [`message_field.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/chat_helpers/message_field.cpp).
- **Accessibility and shortcuts:** Give the chat list, message entries,
  composer and primary actions names and predictable keyboard focus. Adopt a
  small macOS Command-key shortcut set rather than copying desktop shortcuts
  verbatim. See the accessibility file above and
  [`shortcuts.cpp`](https://github.com/telegramdesktop/tdesktop/blob/fad667c6d71c5e965a9da71e48dc1ab82ba0568d/Telegram/SourceFiles/core/shortcuts.cpp).

## NeTelegram design direction

Use a restrained two-pane macOS workspace: a dense, readable conversation
list; a flexible history pane; a compact header; and a persistent composer.
Retain AppKit typography, focus rings, menus, system appearance and window
behavior. Use semantic colors and selection shapes that remain distinct in
light/dark mode and at accessibility contrast settings. Favor actual TDLib
identity/avatar metadata when available; never fabricate profile identities
from chat IDs. Message alignment and emphasis derive from TDLib's
`is_outgoing` flag, while account, chat and topic routing remains untouched.

Keep the interface small and direct. Do not add calls, voice chats, recording,
general video playback, animated GIFs, stickers, emoji/reaction composers,
Stories, Mini Apps, AI, payments or controls whose actions are not implemented.

## Current implementation evidence and limits

At app source `15002caccc16953cd3fd093ab9fb7ddca205ca1e`, ordinary text messages
are being changed from generic sender-prefixed transcript lines to aligned,
rounded incoming/outgoing message surfaces. A targeted build and text-entity
tests passed locally; exact-source macOS CI run
[`38583887319`](https://github.com/AffPapa/NeTelegram/actions/runs/38583887319)
passed for this source commit. Native real-account rendering, VoiceOver, RTL, IME,
photo-bearing bubbles and visual review with real chat data remain unverified.

The accountless chat-shell preview currently renders an empty shell. It is not
used as proof of message appearance, and no synthetic account or profile is
created to fill it. The next visual acceptance requires user-operated login
and review of actual authorized chat data, or a separate explicit fixture
renderer that is visibly labeled as demonstration data.
