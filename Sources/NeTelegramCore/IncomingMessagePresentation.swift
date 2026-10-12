import Foundation

/// Human-facing descriptions for message content NeTelegram deliberately does
/// not render. The TDLib constructor name stays out of UI text while the message
/// itself remains present in the conversation and chat preview.
public enum IncomingMessagePresentation {
    public static func cardText(for contentType: String) -> String {
        switch contentType {
        case "messageAnimation":
            "GIF-анимация · просмотр не поддерживается"
        case "messageAudio":
            "Аудиофайл · прослушивание не поддерживается"
        case "messageVoiceNote":
            "Голосовое сообщение · воспроизведение не поддерживается"
        case "messageVideo", "messageVideoNote":
            "Видео · воспроизведение не поддерживается"
        case "messageDocument":
            "Документ · просмотр и отправка документов не поддерживаются"
        case "messageSticker", "messageAnimatedEmoji", "messageDice":
            "Стикер или анимационный объект · отображение не поддерживается"
        case "messageLocation", "messageVenue":
            "Геопозиция · карта не отображается"
        case "messageContact":
            "Карточка контакта · подробности не отображаются"
        case "messagePoll":
            "Опрос · интерактивный просмотр не поддерживается"
        case "messageInvoice", "messagePaidMedia":
            "Платный контент · NeTelegram не выполняет оплату"
        case "messageStory":
            "История · просмотр не поддерживается"
        default:
            "Вложение или новый тип сообщения · подробный просмотр не поддерживается"
        }
    }

    public static func chatPreview(for contentType: String) -> String {
        switch contentType {
        case "messageAnimation": "GIF-анимация"
        case "messageAudio": "Аудиофайл"
        case "messageVoiceNote": "Голосовое сообщение"
        case "messageVideo", "messageVideoNote": "Видео"
        case "messageDocument": "Документ"
        case "messageSticker", "messageAnimatedEmoji", "messageDice": "Стикер или анимация"
        case "messageLocation", "messageVenue": "Геопозиция"
        case "messageContact": "Контакт"
        case "messagePoll": "Опрос"
        case "messageInvoice", "messagePaidMedia": "Платный контент"
        case "messageStory": "История"
        default: "Вложение или новое сообщение"
        }
    }
}
