# Contributing / Участие в разработке

## English

NeTelegram is an early development project. Read `PRODUCT-ARCHITECTURE.txt`, `ACCEPTANCE.json`, and `CHANGE-OF-REQUIREMENTS.txt` before proposing behavior changes. Preserve the all-authorized-accounts-active requirement; never add a hidden resident-account cap or silently switch identity.

For a change:

1. Keep the patch focused on one user-visible or runtime behavior.
2. Add or update synthetic tests for deterministic core logic. Clearly label anything that still needs a real Telegram account or native UI verification.
3. Run `swift test` on macOS and include the Swift/Xcode versions in the report.
4. Do not include Telegram sessions, profile databases/files, Keychain exports, login codes, phone numbers, API hashes, signing keys, or personal logs.
5. Preserve dependency pins and license notices. Do not copy code or artwork from GPL Telegram clients into this MIT-licensed project.

No real-account session may be obtained from another Telegram client. Account testing must use the app's normal user-entered login flow.

## Русский

NeTelegram находится на ранней стадии разработки. Перед изменением поведения прочитайте `PRODUCT-ARCHITECTURE.txt`, `ACCEPTANCE.json` и `CHANGE-OF-REQUIREMENTS.txt`. Требование: все авторизованные аккаунты остаются активными; нельзя вводить скрытый лимит фоновых профилей или незаметно менять identity.

Для изменения:

1. Ограничьте патч одним понятным поведением интерфейса или runtime.
2. Добавьте или обновите синтетические тесты для детерминированной логики. Отдельно укажите сценарии, которым ещё нужна нативная проверка или реальный тестовый аккаунт.
3. На macOS выполните `swift test` и укажите версии Swift/Xcode.
4. Не добавляйте Telegram-сессии, базы и файлы профилей, выгрузки Keychain, коды входа, номера телефонов, API hash, ключи подписи и личные логи.
5. Сохраняйте закреплённые зависимости и их лицензии. Не переносите код или графику GPL-клиентов Telegram в MIT-код проекта.

Реальную сессию нельзя получать из другого клиента Telegram. Проверка аккаунта выполняется только стандартным входом в само приложение, с данными, введёнными пользователем.
