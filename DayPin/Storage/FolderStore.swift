import Foundation

// MARK: - Folder Model

struct Folder: Identifiable, Codable {
    let id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var emojiIcon: String?
    var iconImageData: Data?

    init(id: UUID = UUID(), name: String, colorHex: String = "#007AFF",
         emojiIcon: String? = nil, iconImageData: Data? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.emojiIcon = emojiIcon
        self.iconImageData = iconImageData
    }
}

// MARK: - FolderStore

final class FolderStore {

    static let shared = FolderStore()
    private init() { load() }

    private var folders: [Folder] = []
    private let key = "daypin.folders"
    private let defaults = UserDefaults.standard

    // MARK: - Public

    func all() -> [Folder] { folders.sorted { $0.createdAt < $1.createdAt } }

    func folder(for id: UUID) -> Folder? { folders.first { $0.id == id } }

    func save(_ folder: Folder) {
        if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[idx] = folder
        } else {
            folders.append(folder)
        }
        persist()
    }

    func delete(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        CardStore.shared.removeFolder(folder.id)
        persist()
    }

    // MARK: - Backup / Restore

    func restore(folders: [Folder]) {
        self.folders = folders
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        defaults.set(data, forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Folder].self, from: data) else { return }
        folders = decoded
    }
}
