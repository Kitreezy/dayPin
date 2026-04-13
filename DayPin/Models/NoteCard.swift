import Foundation

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
    var previewTitle: String?
    var previewDescription: String?
    var previewImageData: Data?

    init(id: UUID = UUID(), title: String, comment: String = "", dayDate: Date, url: URL) {
        self.url = url
        super.init(id: id, type: .link, title: title, comment: comment, dayDate: dayDate)
    }
}

// MARK: - Text Card

final class TextCard: NoteCard {
    init(id: UUID = UUID(), title: String, comment: String = "", dayDate: Date) {
        super.init(id: id, type: .text, title: title, comment: comment, dayDate: dayDate)
    }
}

// MARK: - Image Annotation

struct ImageAnnotation: Identifiable, Codable {
    let id: UUID
    /// Normalized coordinates 0...1
    var x: Double
    var y: Double
    var text: String

    init(id: UUID = UUID(), x: Double, y: Double, text: String) {
        self.id = id
        self.x = x
        self.y = y
        self.text = text
    }
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
