import Foundation
import WidgetKit

final class CardStore {

    static let shared = CardStore()
    private init() {
        migrateFromStandardIfNeeded()
        load()
        purgeExpiredDeleted()
    }

    private var storage: [NoteCardDTO] = []
    private let key = "daypin.cards"
    private let defaults = AppGroup.defaults

    // MARK: - Queries

    func cards(for date: Date) -> [NoteCard] {
        let day = Calendar.current.startOfDay(for: date)
        let dtos = storage.filter {
            $0.deletedAt == nil && Calendar.current.startOfDay(for: $0.dayDate) == day
        }
        // If any card has a manual display order, sort by it; otherwise fall back to creation date.
        let hasOrder = dtos.contains { $0.displayOrder != nil }
        let sorted = hasOrder
            ? dtos.sorted { ($0.displayOrder ?? Int.max) < ($1.displayOrder ?? Int.max) }
            : dtos.sorted { $0.createdAt > $1.createdAt }
        return sorted.compactMap { $0.toModel() }
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

    // MARK: - Save

    func save(card: NoteCard) {
        if let idx = storage.firstIndex(where: { $0.id == card.id }) {
            var dto = NoteCardDTO(from: card)
            dto.deletedAt = nil
            dto.modifiedAt = Date()
            storage[idx] = dto
        } else {
            storage.append(NoteCardDTO(from: card))
        }
        persist()
    }

    /// Saves multiple cards in a single pass and writes once.
    /// Prefer this over repeated `save(card:)` calls in batch operations.
    func saveMany(cards: [NoteCard]) {
        guard !cards.isEmpty else { return }
        for card in cards {
            if let idx = storage.firstIndex(where: { $0.id == card.id }) {
                var dto = NoteCardDTO(from: card)
                dto.deletedAt = nil
                storage[idx] = dto
            } else {
                storage.append(NoteCardDTO(from: card))
            }
        }
        persist()
    }

    // MARK: - Delete

    func delete(card: NoteCard) {
        ReminderManager.shared.cancel(for: card)
        if let idx = storage.firstIndex(where: { $0.id == card.id }) {
            storage[idx].deletedAt = Date()
            storage[idx].modifiedAt = Date()
            persist()
        }
    }

    /// Soft-deletes multiple cards in a single pass and writes once.
    /// Prefer this over repeated `delete(card:)` calls in batch operations.
    func deleteMany(cards: [NoteCard]) {
        guard !cards.isEmpty else { return }
        let now = Date()
        for card in cards {
            ReminderManager.shared.cancel(for: card)
            if let idx = storage.firstIndex(where: { $0.id == card.id }) {
                storage[idx].deletedAt = now
            }
        }
        persist()
    }

    // MARK: - Trash

    /// Cards deleted within the last 30 days, sorted by deletion date.
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

    func deletedAt(for id: UUID) -> Date? {
        storage.first { $0.id == id }?.deletedAt
    }

    func restoreFromTrash(card: NoteCard) {
        if let idx = storage.firstIndex(where: { $0.id == card.id }) {
            storage[idx].deletedAt = nil
            persist()
        }
    }

    func permanentlyDelete(card: NoteCard) {
        storage.removeAll { $0.id == card.id }
        persist()
    }

    func emptyTrash() {
        storage.removeAll { $0.deletedAt != nil }
        persist()
    }

    // MARK: - Order

    /// Persists a new display order for a set of cards on the same day.
    /// `orderedCards` must be the full ordered array for that day after the drag.
    func updateOrder(cards orderedCards: [NoteCard]) {
        for (idx, card) in orderedCards.enumerated() {
            if let pos = storage.firstIndex(where: { $0.id == card.id }) {
                storage[pos].displayOrder = idx
            }
        }
        persist()
    }

    // MARK: - Misc

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

    private let widgetKey = "daypin.widget_cards"

    /// Serial queue for all disk I/O. Background QoS so heavy encodes never block the main thread.
    private let persistQueue = DispatchQueue(label: "com.daypin.cardstore.persist", qos: .utility)

    /// Snapshot `storage` (value type) on the calling thread, then encode + write on a background queue.
    /// UI never waits for disk I/O.
    private func persist() {
        let snapshot = storage   // [NoteCardDTO] is a value-type copy — safe to hand off
        persistQueue.async { [weak self] in
            guard let self else { return }
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            self.defaults.set(data, forKey: self.key)
            // Note: defaults.synchronize() is deprecated and causes a blocking stall — omitted intentionally.
            // UserDefaults flushes to disk automatically on its own schedule.
            let slim = snapshot.map { WidgetCardSlim(from: $0) }
            if let slimData = try? JSONEncoder().encode(slim) {
                AppGroup.defaults.set(slimData, forKey: self.widgetKey)
            }
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NoteCardDTO].self, from: data) else { return }
        storage = decoded
    }

    // MARK: - One-time migration: UserDefaults.standard → App Group

    private func migrateFromStandardIfNeeded() {
        // v2 key: v1 could set the flag prematurely when App Group wasn't configured yet,
        // making .standard data look like it was already migrated.
        let migrationKey = "daypin.migrated_to_appgroup_v2"
        guard !AppGroup.defaults.bool(forKey: migrationKey) else { return }

        defer { AppGroup.defaults.set(true, forKey: migrationKey) }

        let decoder = JSONDecoder()

        let standardCards: [NoteCardDTO]
        if let data = UserDefaults.standard.data(forKey: key) {
            standardCards = (try? decoder.decode([NoteCardDTO].self, from: data)) ?? []
        } else {
            standardCards = []
        }

        let groupCards: [NoteCardDTO]
        if let data = AppGroup.defaults.data(forKey: key) {
            groupCards = (try? decoder.decode([NoteCardDTO].self, from: data)) ?? []
        } else {
            groupCards = []
        }

        print("[CardStore] Migration v2: standard=\(standardCards.count) cards, appGroup=\(groupCards.count) cards")

        if standardCards.count > groupCards.count,
           let standardData = UserDefaults.standard.data(forKey: key) {
            AppGroup.defaults.set(standardData, forKey: key)
            print("[CardStore] Migration v2: copied \(standardCards.count) cards from standard → App Group")
        }

        // Write slim widget snapshot synchronously here since storage isn't loaded yet
        // and persist() would snapshot an empty array at this point.
        let slim = (try? JSONDecoder().decode([NoteCardDTO].self,
                                              from: AppGroup.defaults.data(forKey: key) ?? Data()))
            .map { $0.map { WidgetCardSlim(from: $0) } } ?? []
        if let slimData = try? JSONEncoder().encode(slim) {
            AppGroup.defaults.set(slimData, forKey: widgetKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
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
    var modifiedAt: Date = Date()
    var dayDate: Date
    var deletedAt: Date?
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
    var tagIDs: [UUID]?
    // Reminder
    var reminderDate: Date?
    var reminderNotificationID: String?
    // Display order (for drag-to-reorder within a day)
    var displayOrder: Int?

    init(from card: NoteCard) {
        id = card.id
        type = card.type
        title = card.title
        comment = card.comment
        createdAt = card.createdAt
        dayDate = card.dayDate
        folderID = card.folderID
        colorHex = card.colorHex
        tagIDs = card.tagIDs
        reminderDate = card.reminderDate
        reminderNotificationID = card.reminderNotificationID
        deletedAt = nil

        if let text = card as? TextCard { rtfData = text.rtfData }
        if let img = card as? ImageCard {
            imageData = img.imageData
            annotations = img.annotations
        }
        if let link = card as? LinkCard {
            urlString = link.url.absoluteString
            extraURLStrings = link.extraURLs.map(\.absoluteString)
            previewTitle = link.previewTitle
            previewDescription = link.previewDescription
            previewImageData = link.previewImageData
        }
    }

    func toModel() -> NoteCard? {
        switch type {
        case .text:
            let c = TextCard(id: id, title: title, comment: comment, dayDate: dayDate)
            c.rtfData = rtfData
            c.createdAt = createdAt
            c.folderID = folderID
            c.colorHex = colorHex
            c.tagIDs = tagIDs ?? []
            c.reminderDate = reminderDate
            c.reminderNotificationID = reminderNotificationID
            return c
        case .image:
            let c = ImageCard(id: id, title: title, comment: comment, dayDate: dayDate,
                              imageData: imageData, annotations: annotations ?? [])
            c.createdAt = createdAt
            c.folderID = folderID
            c.colorHex = colorHex
            c.tagIDs = tagIDs ?? []
            c.reminderDate = reminderDate
            c.reminderNotificationID = reminderNotificationID
            return c
        case .link:
            guard let urlStr = urlString, let url = URL(string: urlStr) else { return nil }
            let extra = (extraURLStrings ?? []).compactMap(URL.init(string:))
            let c = LinkCard(id: id, title: title, comment: comment, dayDate: dayDate,
                             url: url, extraURLs: extra)
            c.previewTitle = previewTitle
            c.previewDescription = previewDescription
            c.previewImageData = previewImageData
            c.createdAt = createdAt
            c.folderID = folderID
            c.colorHex = colorHex
            c.tagIDs = tagIDs ?? []
            c.reminderDate = reminderDate
            c.reminderNotificationID = reminderNotificationID
            return c
        }
    }
}

// MARK: - Widget Slim DTO
// Text-only snapshot for the widget — no image blobs, stays under the 4 MB App Group limit.

struct WidgetCardSlim: Codable {
    let id: UUID
    let type: String
    let title: String
    let comment: String
    let createdAt: Date
    let dayDate: Date
    let deletedAt: Date?
    let reminderDate: Date?

    init(from dto: NoteCardDTO) {
        id = dto.id
        type = dto.type.rawValue
        title = dto.title
        comment = dto.comment
        createdAt = dto.createdAt
        dayDate = dto.dayDate
        deletedAt = dto.deletedAt
        reminderDate = dto.reminderDate
    }
}
