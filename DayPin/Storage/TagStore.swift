import Foundation
import UIKit

// MARK: - Tag Model

struct Tag: Codable, Identifiable {
    let id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    var color: UIColor { UIColor(hex: colorHex) ?? DayPinDesign.accent }
}

// MARK: - TagStore

final class TagStore {

    static let shared = TagStore()
    private init() { load() }

    private var tags: [Tag] = []
    private let key = "daypin.tags"
    private let defaults = UserDefaults.standard

    // MARK: - Public

    func all() -> [Tag] { tags.sorted { $0.name < $1.name } }

    func tag(for id: UUID) -> Tag? { tags.first { $0.id == id } }

    func save(_ tag: Tag) {
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[idx] = tag
        } else {
            tags.append(tag)
        }
        persist()
        postChange()
    }

    func delete(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        persist()
        postChange()
    }

    // MARK: - Backup / Restore

    func restore(tags: [Tag]) {
        self.tags = tags
        persist()
        postChange()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        defaults.set(data, forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Tag].self, from: data) else { return }
        tags = decoded
    }

    private func postChange() {
        NotificationCenter.default.post(name: .dayPinTagsChanged, object: nil)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let dayPinTagsChanged = Notification.Name("daypin.tagsChanged")
}

// MARK: - Tag Color Palette

extension TagStore {
    static let palette: [String] = [
        "#A184E5",
        "#E57373",
        "#64B5F6",
        "#81C784",
        "#FFB74D",
        "#F06292"
    ]

    func nextPaletteColor() -> String {
        let usedColors = tags.map(\.colorHex)
        for color in TagStore.palette where !usedColors.contains(color) { return color }
        return TagStore.palette[tags.count % TagStore.palette.count]
    }
}
