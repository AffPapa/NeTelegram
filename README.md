# AffPapa Chat for macOS

[English](README.md) · [Русский](README.ru.md)

**AffPapa Chat** (repository codename **NeTelegram**) is a separate native macOS application in development, built with Swift and AppKit and designed for Telegram cloud chats through a pinned TDLib version. If you are looking for an unofficial Telegram client for macOS, a Telegram client for Mac, or an open-source macOS Telegram client, this repository publishes the source, current evidence, and product limitations.

> **Independent project.** AffPapa Chat is not an official Telegram app, is not developed by Telegram, and has no direct relationship or affiliation with, endorsement by, or connection to Telegram Messenger LLP. Telegram and TDLib names describe compatibility and belong to their respective owners. AffPapa Chat uses the Telegram API/TDLib; it is a separate client in the Telegram ecosystem, not a separate messaging network.

> **Status:** development continues. There is no signed installer to download. Real account login, account-based message sending, and twenty simultaneously authorized accounts have not been verified. See the [development site](https://netelegram.iryadom.chatgpt.site/) for downloads, changelog, development log, roadmap, privacy, and source links.

### Looking for an alternative Telegram client for Mac or a Telegram for Mac download?

AffPapa Chat is an independent native client project for macOS. It is not the official Telegram for Mac and it is not a separate messaging service. NeTelegram is the repository codename. The repository documents source, current verification status, and planned scope. There is no ready-to-download app yet because no signed, verified installer has been released. Current search-result wording includes “unofficial Telegram client for macOS”, “Telegram client for Mac”, “alternative Telegram client for Mac/macOS”, “native macOS Telegram client”, and “open-source Telegram client for Mac”. These phrases describe the project topic; they do not imply Telegram endorsement or measured search demand.

## Intended scope

The project uses Swift, AppKit, and TDLib 1.8.68 with pinned source and schema. The source includes account-scoped profiles and storage, standard Telegram authorization, multi-account runtime code, chat and message presentation, text, photo, local draft, notification, and UI privacy-lock paths. These are source-level implementation notes, not proof that user workflows are complete.

The target behavior is to keep connected accounts active while the app is running, the Mac is awake, and the network is available. The visible conversation view selects one account without unloading the others. A 1/5/10/20 real-account matrix, memory use, and performance have not been certified. Sessions from Telegram Desktop and other clients are not imported. Never post login secrets or verification codes in issues or source files.

Planned capabilities include cloud private and group chats, channel reading after compatibility gates are resolved, text and links, replies, topics, permission-aware edits and deletes, separate drafts, captioned photos and incoming albums, search, per-account notifications, reauthentication, logout, a local privacy lock, keyboard support, and VoiceOver. Unsupported incoming types should retain context in a clear card.

Version 1 excludes calls, voice chats, audio recording or playback, a general video player, animated GIFs, sticker packs and picker, emoji picker, reaction composer, Stories, Mini Apps runtime, AI/translation, wallet, payments, CRM, bulk messaging, auto-replies, universal document sending, and copied sessions. Channel support is read-only in the approved plan and is not currently enabled.

## Compatibility and naming

Observed search wording includes “unofficial Telegram client for macOS”, “Telegram alternative client for Mac”, “Telegram client for Mac”, “app for Telegram on Mac”, «неофициальный клиент Telegram для macOS», «клиент Telegram для Mac», «альтернативный клиент Telegram для Mac/macOS» and «приложение для Telegram на Mac». These are descriptive phrases, not claims of official status, rankings, or measured search demand. Search volumes and site rankings have not been measured.

Current [Telegram API Terms](https://core.telegram.org/api/terms) restrict the app title: §2.3 allows “Telegram” in the title only when it is preceded by “Unofficial”. The selected public title, AffPapa Chat, does not contain that word; final bundle and Site metadata still need verification. Section 2.2 also requires a prominent disclosure that the app uses the Telegram API and is part of the Telegram ecosystem. Channel access and stable release remain deferred because sponsored-message/video and basic-functionality requirements are unresolved. The name choice is not trademark clearance, and no API compatibility claim is made.

## Verification and downloads

Current commits, CI results, and evidence limits are recorded in [`ACCEPTANCE.json`](ACCEPTANCE.json); release gates are in [`RELEASE.md`](RELEASE.md). GitHub CI and an accountless Dev.app smoke verify compilation and synthetic checks, not login, real messages, twenty active accounts, Developer ID signing, or notarization. There are no app downloads until those checks are complete.

## Development

The project targets macOS 14+ and Apple Silicon. Xcode and a compatible Swift toolchain are required. Build the pinned TDLib, configure your own permitted Telegram API credentials through the protected Keychain flow, then run:

```sh
swift test
Scripts/dev-app.sh --launch
```

Do not reuse another app's API credentials or import another client's sessions. See [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md), [`PRODUCT-ARCHITECTURE.txt`](PRODUCT-ARCHITECTURE.txt), and [`NOTICE`](NOTICE). New project code is licensed under MIT after dependency review; third-party components are listed in NOTICE.

---

# AffPapa Chat для macOS

[English](README.md) · [Русский](README.ru.md)

**AffPapa Chat** (кодовое имя репозитория — **NeTelegram**) — отдельное нативное приложение для macOS на Swift и AppKit, разрабатываемое для облачных чатов Telegram через закреплённую версию TDLib. Здесь опубликованы исходники, фактический статус и ограничения для тех, кто ищет неофициальный клиент Telegram для macOS, альтернативный клиент Telegram для Mac или open-source клиент Telegram для Mac.

> **Независимый проект.** AffPapa Chat не является официальным приложением Telegram, не разработан Telegram и не имеет прямого отношения или аффилиации, одобрения либо связи с Telegram Messenger LLP. Названия Telegram и TDLib описывают совместимость и принадлежат правообладателям. AffPapa Chat использует Telegram API/TDLib и является отдельным клиентом экосистемы Telegram, а не самостоятельной сетью обмена сообщениями.

> **Статус:** разработка продолжается. Подписанной сборки для скачивания нет. Реальный вход в аккаунт, отправка сообщений и работа двадцати одновременно авторизованных аккаунтов не проверены. См. [сайт разработки](https://netelegram.iryadom.chatgpt.site/) — там находятся загрузки, changelog, журнал работ, roadmap, приватность и ссылки на исходники.

## Планируемые возможности и ограничения

В проекте используются Swift, AppKit и TDLib 1.8.68 с закреплёнными исходниками и схемой. Исходный код включает отдельные профили и хранилища аккаунтов, стандартную авторизацию Telegram, runtime нескольких аккаунтов, отображение чатов и сообщений, текстовый и фотопути, черновики, уведомления и блокировку интерфейса. Это описание кода, а не подтверждение полной готовности этих сценариев.

Цель — поддерживать подключённые аккаунты активными, пока приложение открыто, Mac не спит и сеть доступна. Выбранный интерфейс переписки показывает один аккаунт, не выгружая остальные. Матрица 1/5/10/20 реальных аккаунтов, память и производительность не сертифицированы. Сессии Telegram Desktop и других клиентов не импортируются.

Планируются облачные личные и групповые чаты, чтение каналов после закрытия compatibility gates, текст и ссылки, ответы, темы, редактирование/удаление в пределах прав, раздельные черновики, фотографии с подписями и входящие альбомы, поиск, уведомления каждого аккаунта, повторная авторизация, выход, локальная блокировка приватности, клавиатура и VoiceOver. Неизвестный входящий тип должен отображаться в понятной карточке с доступным контекстом.

В v1 не входят звонки, voice chats, запись или воспроизведение аудио, обычный видеоплеер, GIF-анимация, sticker packs/picker, emoji picker, composer реакций, Stories, Mini Apps runtime, AI/переводчик, кошелёк, платежи, CRM, массовые рассылки, автоответы, универсальная отправка документов и перенос чужих сессий. Каналы разрешены в плане только для чтения, но сейчас отключены.

## Совместимость и название

В поисковой выдаче встречаются формулировки «неофициальный клиент Telegram для macOS», «клиент Telegram для Mac», «альтернативный клиент Telegram для Mac/macOS», «приложение для Telegram на Mac», “unofficial Telegram client for macOS” и “alternative Telegram client for Mac”. Это описательные запросы, а не заявление об официальном статусе, позициях или объёме спроса. Поисковые объёмы и позиции сайта не измерялись.

Действующие [условия Telegram API](https://core.telegram.org/api/terms) ограничивают заголовок приложения: §2.3 допускает слово “Telegram” только если перед ним стоит “Unofficial”. Выбранное публичное название AffPapa Chat не содержит этого слова; bundle и Site metadata ещё нужно проверить. §2.2 отдельно требует заметно сообщать, что приложение использует Telegram API и является частью экосистемы Telegram. Чтение каналов и stable-релиз отложены из-за требований к sponsored messages/video и базовой функциональности. Выбор названия не является проверкой товарного знака; совместимость API не заявляется.

## Проверки и загрузки

Актуальные source-коммиты, CI и границы проверок записаны в [`ACCEPTANCE.json`](ACCEPTANCE.json); условия выпуска — в [`RELEASE.md`](RELEASE.md). GitHub CI и accountless smoke Dev.app проверяют сборку и синтетические сценарии, но не реальную авторизацию, сообщения, двадцать аккаунтов, подпись Developer ID или нотарификацию. Пока эти проверки не завершены, установщика нет.

## Сборка и разработка

Цель — macOS 14+ и Apple Silicon. Нужны Xcode и совместимый Swift toolchain. Соберите закреплённую TDLib, настройте собственные допустимые credentials через защищённый поток Keychain и выполните:

```sh
swift test
Scripts/dev-app.sh --launch
```

Не используйте API credentials другого приложения и не переносите сессии других клиентов. См. [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md), [`PRODUCT-ARCHITECTURE.txt`](PRODUCT-ARCHITECTURE.txt) и [`NOTICE`](NOTICE). Новый код проекта распространяется по MIT после аудита зависимостей; сторонние компоненты описаны в NOTICE.
