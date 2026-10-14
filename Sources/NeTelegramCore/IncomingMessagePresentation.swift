import Foundation

/// Human-facing descriptions for message content NeTelegram deliberately does
/// not render. The TDLib constructor name stays out of UI text while the message
/// itself remains present in the conversation and chat preview.
public enum IncomingMessagePresentation {
    /// Returns safe human-readable details that TDLib supplied for a message
    /// whose media renderer is intentionally out of scope. Never expose raw
    /// constructor names, identifiers, local paths, or serialized JSON.
    public static func contextLines(for message: [String: Any]) -> [String] {
        guard let content = message["content"] as? [String: Any] else { return [] }
        var lines: [String] = []

        if let caption = content["caption"] as? [String: Any],
           let text = caption["text"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { lines.append(trimmed) }
        }

        let contentType = content["@type"] as? String ?? ""
        if contentType == "messageDocument",
           let document = content["document"] as? [String: Any],
           let fileName = document["file_name"] as? String {
            appendDistinct(fileName, to: &lines)
        } else if contentType == "messageAudio",
                  let audio = content["audio"] as? [String: Any] {
            let title = audio["title"] as? String
            let performer = audio["performer"] as? String
            let track = [performer, title]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " — ")
            appendDistinct(track, to: &lines)
        } else if contentType == "messagePoll",
                  let poll = content["poll"] as? [String: Any],
                  let question = poll["question"] as? String {
            appendDistinct(question, to: &lines)
        }

        if let rawDate = message["date"] as? NSNumber, rawDate.int64Value > 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(rawDate.int64Value))
            let formatted = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
            if !formatted.isEmpty { lines.append("Дата сообщения: \(formatted)") }
        }

        return lines
    }

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
            "Платный контент · \(ProductIdentity.displayName) не выполняет оплату"
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

    private static func appendDistinct(_ candidate: String, to lines: inout [String]) {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !lines.contains(trimmed) else { return }
        lines.append(trimmed)
    }
}
