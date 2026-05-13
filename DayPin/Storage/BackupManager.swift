import Foundation

// MARK: - Backup container

struct DayPinBackup: Codable {
    let version: Int
    let exportDate: Date
    let cards: [NoteCardDTO]
    let folders: [Folder]
    var tags: [Tag]

    static let currentVersion = 2

    // Backward-compat memberwise init
    init(version: Int, exportDate: Date, cards: [NoteCardDTO], folders: [Folder], tags: [Tag] = []) {
        self.version    = version
        self.exportDate = exportDate
        self.cards      = cards
        self.folders    = folders
        self.tags       = tags
    }

    // Custom decode so old backups without `tags` still load
    enum CodingKeys: String, CodingKey { case version, exportDate, cards, folders, tags }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version    = try c.decode(Int.self,           forKey: .version)
        exportDate = try c.decode(Date.self,          forKey: .exportDate)
        cards      = try c.decode([NoteCardDTO].self, forKey: .cards)
        folders    = try c.decode([Folder].self,      forKey: .folders)
        tags       = try c.decodeIfPresent([Tag].self, forKey: .tags) ?? []
    }
}

// MARK: - BackupManager

final class BackupManager {

    static let shared = BackupManager()
    private init() {}

    // MARK: - Export

    /// Serialises all data into a JSON Data blob ready to be written to a file.
    func makeBackupData() throws -> Data {
        let backup = DayPinBackup(
            version: DayPinBackup.currentVersion,
            exportDate: Date(),
            cards: CardStore.shared.allDTOs(),
            folders: FolderStore.shared.all(),
            tags: TagStore.shared.all()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // No prettyPrinted — large imageData makes the file unnecessarily huge
        return try encoder.encode(backup)
    }

    /// Suggested filename: daypin_backup_2024-01-15.json
    func suggestedFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "daypin_backup_\(df.string(from: Date())).json"
    }

    // MARK: - Import

    struct RestoreResult {
        let cards: Int
        let folders: Int
        let tags: Int
    }

    /// Deserialises backup data and REPLACES current data.
    /// Call only after user confirmation.
    @discardableResult
    func restore(from data: Data) throws -> RestoreResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DayPinBackup.self, from: data)
        FolderStore.shared.restore(folders: backup.folders)
        TagStore.shared.restore(tags: backup.tags)
        CardStore.shared.restore(dtos: backup.cards)
        return RestoreResult(cards: backup.cards.count, folders: backup.folders.count, tags: backup.tags.count)
    }

    /// Reads backup metadata without restoring — used to show preview in UI.
    func peekBackup(from data: Data) throws -> DayPinBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DayPinBackup.self, from: data)
    }
}
