import Foundation

/// In-memory + UserDefaults persistence store for NoteCards.
final class CardStore {

    static let shared = CardStore()
    private init() {
        load()
        purgeExpiredDeleted()   // при старте сносим то, что висит больше 30 дней
    }

    private var storage: [NoteCardDTO] = []
    private let key = "daypin.cards"
    private let defaults = UserDefaults.standard

    // MARK: - Публичные запросы (только живые карточки)

    func cards(for date: Date) -> [NoteCard] {
        let day = Calendar.current.startOfDay(for: date)
        return storage
            .filter { $0.deletedAt == nil &&
                      Calendar.current.startOfDay(for: $0.dayDate) == day }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { $0.toModel() }
    }

    func allCards() -> [NoteCard] {
        storage
            .filter { $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { $0.toModel() }
    }

    func cards(inFolder folderID: UUID) -> [NoteCard] {
        storage
            .filter { $0.deletedAt == nil && $0.folderID == folderID }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { $0.toModel() }
    }

    // MARK: - Сохранение

    func save(card: NoteCard) {
        if let idx = storage.firstIndex(where: { $0.id == card.id }) {
            var dto = NoteCardDTO(from: card)
            dto.deletedAt = nil   // восстанавливаем, если была в корзине
            storage[idx] = dto
        } else {
            storage.append(NoteCardDTO(from: card))
        }
        persist()
    }

    // MARK: - Мягкое удаление (в корзину)

    func delete(card: NoteCard) {
        if let idx = storage.firstIndex(where: { $0.id == card.id }) {
            storage[idx].deletedAt = Date()
            persist()
        }
    }

    // MARK: - Корзина

    /// Возвращает карточки в корзине (в пределах 30 дней), сортировка по дате удаления.
    func recentlyDeleted() -> [NoteCard] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        return storage
            .filter { dto in
                guard let d = dto.deletedAt else { return false }
                return d > cutoff
            }
            .sorted { $0.deletedAt! > $1.deletedAt! }
            .compactMap { $0.toModel() }
    }

    /// Дата удаления для конкретной карточки.
    func deletedAt(for id: UUID) -> Date? {
        storage.first { $0.id == id }?.deletedAt
    }

    /// Восстановить из корзины.
    func restoreFromTrash(card: NoteCard) {
        if let idx = storage.firstIndex(where: { $0.id == card.id }) {
            storage[idx].deletedAt = nil
            persist()
        }
    }

    /// Удалить навсегда.
    func permanentlyDelete(card: NoteCard) {
        storage.removeAll { $0.id == card.id }
        persist()
    }

    /// Очистить всю корзину.
    func emptyTrash() {
        storage.removeAll { $0.deletedAt != nil }
        persist()
    }

    // MARK: - Служебные

    func removeFolder(_ folderID: UUID) {
        for idx in storage.indices where storage[idx].folderID == folderID {
            storage[idx].folderID = nil
        }
        persist()
    }

    // MARK: - Backup / Restore

    func allDTOs() -> [NoteCardDTO] { storage }

    func restore(dtos: [NoteCardDTO]) {
        storage = dtos
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        defaults.set(data, forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NoteCardDTO].self, from: data) else { return }
        storage = decoded
    }

    private func purgeExpiredDeleted() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let before = storage.count
        storage.removeAll { ($0.deletedAt ?? Date.distantFuture) <= cutoff }
        if storage.count != before { persist() }
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
    var deletedAt: Date?        // nil = живая, Date = в корзине
    // TextCard
    var rtfData: Data?
    // ImageCard
    var imageData: Data?
    var annotations: [ImageAnnotation]?
    // Folder
    var folderID: UUID?
    var colorHex: String?
    // LinkCard
    var urlString: String?
    var previewTitle: String?
    var previewDescription: String?
    var previewImageData: Data?
    var extraURLStrings: [String]?

    init(from card: NoteCard) {
        id        = card.id
        type      = card.type
        title     = card.title
        comment   = card.comment
        createdAt = card.createdAt
        dayDate   = card.dayDate
        folderID  = card.folderID
        colorHex  = card.colorHex
        deletedAt = nil

        if let text = card as? TextCard { rtfData = text.rtfData }
        if let img  = card as? ImageCard {
            imageData   = img.imageData
            annotations = img.annotations
        }
        if let link = card as? LinkCard {
            urlString          = link.url.absoluteString
            extraURLStrings    = link.extraURLs.map(\.absoluteString)
            previewTitle       = link.previewTitle
            previewDescription = link.previewDescription
            previewImageData   = link.previewImageData
        }
    }

    func toModel() -> NoteCard? {
        switch type {
        case .text:
            let c = TextCard(id: id, title: title, comment: comment, dayDate: dayDate)
            c.rtfData   = rtfData
            c.createdAt = createdAt
            c.folderID  = folderID
            c.colorHex  = colorHex
            return c
        case .image:
            let c = ImageCard(id: id, title: title, comment: comment, dayDate: dayDate,
                              imageData: imageData, annotations: annotations ?? [])
            c.createdAt = createdAt
            c.folderID  = folderID
            c.colorHex  = colorHex
            return c
        case .link:
            guard let urlStr = urlString, let url = URL(string: urlStr) else { return nil }
            let extra = (extraURLStrings ?? []).compactMap(URL.init(string:))
            let c = LinkCard(id: id, title: title, comment: comment, dayDate: dayDate,
                             url: url, extraURLs: extra)
            c.previewTitle       = previewTitle
            c.previewDescription = previewDescription
            c.previewImageData   = previewImageData
            c.createdAt          = createdAt
            c.folderID           = folderID
            c.colorHex           = colorHex
            return c
        }
    }
}
