import Foundation

// MARK: - Folder Model

struct Folder: Identifiable, Codable {
    let id: UUID
    var name: String
    var colorHex: String       // accent color
    var createdAt: Date
    var emojiIcon: String?     // nil → дефолтная иконка
    var iconImageData: Data?   // nil → нет фото

    init(id: UUID = UUID(), name: String, colorHex: String = "#007AFF",
         emojiIcon: String? = nil, iconImageData: Data? = nil) {
        self.id            = id
        self.name          = name
        self.colorHex      = colorHex
        self.createdAt     = Date()
        self.emojiIcon     = emojiIcon
        self.iconImageData = iconImageData
    }
}

// MARK: - FolderStore

final class FolderStore {

    static let shared = FolderStore()
    private init() { load() }

    private var folders: [Folder] = []
    private let key = "daypin.folders"

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
        // Unassign all cards in this folder
        CardStore.shared.removeFolder(folder.id)
        persist()
    }

    // MARK: - Backup / Restore

    /// Replaces all folders with data from a backup.
    func restore(folders: [Folder]) {
        self.folders = folders
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Folder].self, from: data) else { return }
        folders = decoded
    }
}
