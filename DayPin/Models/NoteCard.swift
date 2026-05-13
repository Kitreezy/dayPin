import Foundation
import UIKit

// MARK: - Card Type

enum CardType: String, Codable {
    case text
    case image
    case link
}

// MARK: - Base NoteCard

class NoteCard: Identifiable, ObservableObject {
    let id: UUID
    var type: CardType
    var title: String
    var comment: String
    var createdAt: Date
    var dayDate: Date
    var folderID: UUID?
    /// Optional per-card color override (hex string). Nil = use type-based theme tint.
    var colorHex: String?
    /// IDs of tags attached to this card.
    var tagIDs: [UUID] = []
    /// Scheduled reminder date, if any.
    var reminderDate: Date?
    /// UNUserNotification identifier used to cancel the scheduled notification.
    var reminderNotificationID: String?

    init(id: UUID = UUID(), type: CardType, title: String, comment: String = "", dayDate: Date) {
        self.id = id
        self.type = type
        self.title = title
        self.comment = comment
        self.createdAt = Date()
        self.dayDate = dayDate
    }
}

// MARK: - Image Card

final class ImageCard: NoteCard {
    var imageData: Data?
    var annotations: [ImageAnnotation]

    init(id: UUID = UUID(), title: String, comment: String = "", dayDate: Date, imageData: Data? = nil, annotations: [ImageAnnotation] = []) {
        self.imageData = imageData
        self.annotations = annotations
        super.init(id: id, type: .image, title: title, comment: comment, dayDate: dayDate)
    }
}

// MARK: - Link Card

final class LinkCard: NoteCard {
    var url: URL
    var extraURLs: [URL]
    var previewTitle: String?
    var previewDescription: String?
    var previewImageData: Data?

    init(id: UUID = UUID(), title: String, comment: String = "", dayDate: Date, url: URL, extraURLs: [URL] = []) {
        self.url = url
        self.extraURLs = extraURLs
        super.init(id: id, type: .link, title: title, comment: comment, dayDate: dayDate)
    }
}

// MARK: - Text Card

final class TextCard: NoteCard {
    /// RTF-encoded attributed comment. When set, `comment` is kept as plain-text fallback for search.
    var rtfData: Data?

    init(id: UUID = UUID(), title: String, comment: String = "", dayDate: Date) {
        super.init(id: id, type: .text, title: title, comment: comment, dayDate: dayDate)
    }

    var attributedComment: NSAttributedString? {
        guard let data = rtfData else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    func setAttributedComment(_ attributed: NSAttributedString) {
        comment = attributed.string   // plain-text for search
        rtfData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

// MARK: - Image Annotation

struct ImageAnnotation: Identifiable, Codable {
    let id: UUID
    /// Normalized coordinates 0...1
    var x: Double
    var y: Double
    var title: String
    var text: String
    /// Hex color string, e.g. "#007AFF". Default = systemBlue.
    var colorHex: String

    init(id: UUID = UUID(), x: Double, y: Double, title: String = "", text: String, colorHex: String = "#007AFF") {
        self.id = id
        self.x = x
        self.y = y
        self.title = title
        self.text = text
        self.colorHex = colorHex
    }

    enum CodingKeys: String, CodingKey {
        case id, x, y, title, text, colorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self, forKey: .id)
        x        = try c.decode(Double.self, forKey: .x)
        y        = try c.decode(Double.self, forKey: .y)
        title    = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        text     = try c.decode(String.self, forKey: .text)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#007AFF"
    }

    var color: UIColor { UIColor(hex: colorHex) ?? .systemBlue }
}

// MARK: - Day Entry

struct DayEntry {
    let date: Date
    var cards: [NoteCard]

    var normalizedDate: Date {
        Calendar.current.startOfDay(for: date)
    }

    var hasCards: Bool { !cards.isEmpty }
}
