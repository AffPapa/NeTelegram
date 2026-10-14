import AppKit

/// Native, data-only conversation row. It deliberately owns no account or chat
/// state; AppDelegate supplies a snapshot derived from TDLib updates.
final class ConversationListRowButton: NSButton {
    private let conversationTitle: String
    private let preview: String
    private let time: String
    private let unreadCount: Int
    private let isMuted: Bool
    private let chatID: Int64
    private let isSelected: Bool
    private var isHovered = false

    init(
        conversationTitle: String,
        preview: String,
        time: String,
        unreadCount: Int,
        isMuted: Bool,
        chatID: Int64,
        isSelected: Bool,
        target: AnyObject?,
        action: Selector?
    ) {
        self.conversationTitle = conversationTitle
        self.preview = preview
        self.time = time
        self.unreadCount = max(0, unreadCount)
        self.isMuted = isMuted
        self.chatID = chatID
        self.isSelected = isSelected
        super.init(frame: .zero)
        self.target = target
        self.action = action
        isBordered = false
        title = ""
        setButtonType(.momentaryChange)
        focusRingType = .default
        setAccessibilityLabel(Self.accessibilityDescription(
            title: conversationTitle,
            preview: preview,
            time: time,
            unreadCount: unreadCount,
            isMuted: isMuted,
            isSelected: isSelected
        ))
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 68)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let row = bounds.insetBy(dx: 3, dy: 3)
        let selected = isSelected || isHighlighted
        if selected {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: row, xRadius: 8, yRadius: 8).fill()
        } else if isHovered {
            NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
            NSBezierPath(roundedRect: row, xRadius: 8, yRadius: 8).fill()
        }

        let primary = selected ? NSColor.selectedControlTextColor : NSColor.labelColor
        let secondary = selected ? NSColor.selectedControlTextColor.withAlphaComponent(0.78) : NSColor.secondaryLabelColor
        let avatarDiameter: CGFloat = 40
        let avatarRect = NSRect(x: row.minX + 10, y: row.midY - avatarDiameter / 2, width: avatarDiameter, height: avatarDiameter)
        let hue = CGFloat(UInt64(bitPattern: chatID) % 360) / 360
        let avatarColor = NSColor(calibratedHue: hue, saturation: 0.58, brightness: selected ? 0.88 : 0.82, alpha: 1)
        avatarColor.setFill()
        NSBezierPath(ovalIn: avatarRect).fill()

        let monogram = conversationTitle.first.map(String.init) ?? "•"
        draw(monogram, in: avatarRect, font: .systemFont(ofSize: 17, weight: .semibold), color: .white, alignment: .center)

        let contentX = avatarRect.maxX + 10
        let trailingInset: CGFloat = 10
        let badgeText = unreadCount > 99 ? "99+" : String(unreadCount)
        let badgeWidth: CGFloat = unreadCount > 0 ? max(20, CGFloat(badgeText.count) * 7 + 10) : 0
        let timeWidth: CGFloat = time.isEmpty ? 0 : min(58, CGFloat(time.count) * 7 + 4)
        let topTrailingWidth = max(timeWidth, badgeWidth)
        let rightEdge = row.maxX - trailingInset
        let textRight = rightEdge - (topTrailingWidth > 0 ? topTrailingWidth + 9 : 0)
        let textWidth = max(40, textRight - contentX)
        let titleRect = NSRect(x: contentX, y: row.midY + 4, width: textWidth, height: 18)
        let previewRect = NSRect(x: contentX, y: row.midY - 15, width: textWidth, height: 17)
        draw(conversationTitle, in: titleRect, font: .systemFont(ofSize: 13, weight: .semibold), color: primary)
        draw(preview, in: previewRect, font: .systemFont(ofSize: 12), color: secondary)

        if !time.isEmpty {
            let timeRect = NSRect(x: rightEdge - timeWidth, y: row.midY + 5, width: timeWidth, height: 15)
            draw(time, in: timeRect, font: .systemFont(ofSize: 10.5), color: secondary, alignment: .right)
        }
        if unreadCount > 0 {
            let badgeRect = NSRect(x: rightEdge - badgeWidth, y: row.midY - 15, width: badgeWidth, height: 18)
            (isMuted ? NSColor.tertiaryLabelColor : NSColor.systemBlue).setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: 9, yRadius: 9).fill()
            draw(badgeText, in: badgeRect, font: .systemFont(ofSize: 10, weight: .semibold), color: .white, alignment: .center)
        } else if isMuted {
            let muteRect = NSRect(x: rightEdge - 13, y: row.midY - 15, width: 13, height: 15)
            NSImage(systemSymbolName: "bell.slash.fill", accessibilityDescription: "Уведомления отключены")?
                .draw(in: muteRect, from: .zero, operation: .sourceOver, fraction: 0.72)
        }
    }

    private func draw(
        _ value: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        (value as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    private static func accessibilityDescription(
        title: String,
        preview: String,
        time: String,
        unreadCount: Int,
        isMuted: Bool,
        isSelected: Bool
    ) -> String {
        var parts = [isSelected ? "Текущая переписка" : "Открыть переписку", title]
        if !preview.isEmpty { parts.append("Последнее сообщение: \(preview)") }
        if !time.isEmpty { parts.append(time) }
        if unreadCount > 0 { parts.append("Непрочитанных: \(unreadCount)") }
        if isMuted { parts.append("Уведомления отключены") }
        return parts.joined(separator: ". ")
    }
}
