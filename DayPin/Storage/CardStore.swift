import Foundation

/// In-memory + UserDefaults persistence store for NoteCards.
/// Lightweight approach — no CoreData dependency for initial launch.
/// Can be replaced with CoreData/SwiftData later.
final class CardStore {

    static let shared = CardStore()
    private init() { load() }

    private var storage: [NoteCardDTO] = []
    private let key = "daypin.cards"

    // MARK: - Public

    func cards(for date: Date) -> [NoteCard] {
        let day = Calendar.current.startOfDay(for: date)
        return storage
            .filter { Calendar.current.startOfDay(for: $0.dayDate) == day }
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { $0.toModel() }
    }

    func allCards() -> [NoteCard] {
        return storage
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { $0.toModel() }
    }

    func save(card: NoteCard) {
        if let idx = storage.firstIndex(where: { $0.id == card.id }) {
            storage[idx] = NoteCardDTO(from: card)
        } else {
            storage.append(NoteCardDTO(from: card))
        }
        persist()
    }

    func delete(card: NoteCard) {
        storage.removeAll { $0.id == card.id }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NoteCardDTO].self, from: data) else { return }
        storage = decoded
    }
}

// MARK: - DTO

struct NoteCardDTO: Codable {
    let id: UUID
    var type: CardType
    var title: String
    var comment: String
    var createdAt: Date
    var dayDate: Date
    // ImageCard
    var imageData: Data?
    var annotations: [ImageAnnotation]?
    // LinkCard
    var urlString: String?
    var previewTitle: String?
    var previewDescription: String?
    var previewImageData: Data?

    init(from card: NoteCard) {
        id = card.id
        type = card.type
        title = card.title
        comment = card.comment
        createdAt = card.createdAt
        dayDate = card.dayDate

        if let img = card as? ImageCard {
            imageData = img.imageData
            annotations = img.annotations
        }
        if let link = card as? LinkCard {
            urlString = link.url.absoluteString
            previewTitle = link.previewTitle
            previewDescription = link.previewDescription
            previewImageData = link.previewImageData
        }
    }

    func toModel() -> NoteCard? {
        switch type {
        case .text:
            let c = TextCard(id: id, title: title, comment: comment, dayDate: dayDate)
            c.createdAt = createdAt
            return c
        case .image:
            let c = ImageCard(id: id, title: title, comment: comment, dayDate: dayDate, imageData: imageData, annotations: annotations ?? [])
            c.createdAt = createdAt
            return c
        case .link:
            guard let urlStr = urlString, let url = URL(string: urlStr) else { return nil }
            let c = LinkCard(id: id, title: title, comment: comment, dayDate: dayDate, url: url)
            c.previewTitle = previewTitle
            c.previewDescription = previewDescription
            c.previewImageData = previewImageData
            c.createdAt = createdAt
            return c
        }
    }
}
