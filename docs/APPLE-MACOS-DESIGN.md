# NeTelegram macOS interface standards

Reviewed 2026-10-15 against Apple's current Human Interface Guidelines and
public Telegram macOS/Desktop source repositories. This is the project's
design contract, not a claim of Apple endorsement or a substitute for native
visual and accessibility checks.

## Product decisions

- Use AppKit controls, standard window chrome, system focus rings, menu
  commands, and Auto Layout. Do not replace the title bar or draw a web-style
  application shell.
- Use semantic `NSColor` values and preferred system text styles. Avoid a
  fixed light/dark palette; test increased contrast and both appearances.
- Let standard controls keep their intrinsic height. Set a shared
  `NSControl.ControlSize` when adjacent controls must align; constrain width
  and spacing, not arbitrary height, unless the control is a deliberate
  custom component.
- Lay out forms with persistent labels, consistent leading/trailing edges,
  readable helper text, and one obvious primary action. Place field-specific
  errors beside the field. Preserve keyboard focus and VoiceOver names.
- Keep windows useful when resized: define minimums from content, keep short
  forms grouped rather than stretching gaps, and scroll longer authorization
  steps instead of clipping them.
- Follow Telegram's interaction hierarchy selectively (identity, dialogs,
  active conversation, composer). Do not copy its source, assets, logo, or
  GPL implementation. Keep NeTelegram's mark and native macOS behavior.
- Never show invented account identities or sample conversations. A
  development screenshot proves only the exact build and state shown.

## First-run sign-in

The phone-entry form uses a centered, measured column inside the native
window. Country and phone controls share `.regular` sizing and intrinsic
height; the form constrains their common width and keeps their labels and
primary action aligned. The system-region suggestion remains explicit and
does not silently select a calling code. Continue stays disabled until valid
input exists. The non-affiliation disclosure remains secondary text.

Do not change account routing, phone normalization, or authorization requests
as a side effect of visual refinements. Check the accountless first-run state
and a longer authorization state separately; the latter needs owner-entered
credentials and must not be simulated as a real login.

## Primary references

- [Apple HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Apple HIG: macOS windows](https://developer.apple.com/design/human-interface-guidelines/windows)
- [Apple HIG: Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)
- [Apple HIG: Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [Apple HIG: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Telegram for macOS source](https://github.com/TelegramOrg/Telegram-macos-Swift)
- [Telegram Desktop source](https://github.com/TelegramOrg/Telegram-desktop)

The Telegram for macOS README asks forks to obtain their own API ID, avoid
reusing Telegram's standard logo, follow the applicable terms, and identifies
its source as GPL-2.0. Telegram Desktop identifies its source as GPL-3.0 with
an OpenSSL exception. Those repositories inform interaction structure only;
their code and assets are not imported into this MIT-licensed project.

## Verification boundary

For each UI change, build the exact clean source once, launch only the
canonical Dev.app, and capture its title, accessibility tree, and screenshot.
Run only focused tests for behavior touched by the change. A successful build
does not prove resize behavior, VoiceOver speech, increased-contrast rendering,
right-to-left layout, real authentication, or authenticated chat appearance;
record those separately when they are actually checked.
