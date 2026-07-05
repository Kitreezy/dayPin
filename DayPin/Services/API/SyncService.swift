import Foundation

// MARK: - Sync Result

enum SyncResult {
    case success(SyncSummary)
    case noBackup               // server returned 204
    case failure(Error)
}

// MARK: - SyncService

@MainActor
final class SyncService {

    static let shared = SyncService()
    private init() {}

    // MARK: - State

    private(set) var isSyncing = false {
        didSet {
            NotificationCenter.default.post(name: .dayPinSyncStateChanged, object: nil)
        }
    }

    // MARK: - Push (local → server)

    func push() async -> SyncResult {
        guard !isSyncing else {
            return .failure(APIClientError.serverError("Sync already in progress"))
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let rawData = try BackupManager.shared.makeBackupData()

            // Decode to struct so the encoder can write it with ISO-8601 dates.
            let decoder = BackupManager.isoDecoder
            let backup = try decoder.decode(DayPinBackup.self, from: rawData)

            let response: SyncPushResponse = try await APIClient.shared.request(
                Endpoint(.post, "/sync/push", body: backup)
            )
            writeCache(rawData)

            return .success(SyncSummary(
                syncedAt: response.syncedAt,
                cards: response.stats.cards,
                folders: response.stats.folders,
                tags: response.stats.tags
            ))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Pull (server → local)

    func pull() async -> SyncResult {
        guard !isSyncing else {
            return .failure(APIClientError.serverError("Sync already in progress"))
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let data = try await APIClient.shared.requestRaw(
                Endpoint(.get, "/sync/pull")
            )
            guard !data.isEmpty else { return .noBackup }

            let result = try BackupManager.shared.restore(from: data)
            writeCache(data)

            // Find exportDate from the backup for the summary timestamp.
            let decoder = BackupManager.isoDecoder
            let backup = try decoder.decode(DayPinBackup.self, from: data)

            NotificationCenter.default.post(name: .dayPinDataRestored, object: nil)

            return .success(SyncSummary(
                syncedAt: backup.exportDate,
                cards: result.cards,
                folders: result.folders,
                tags: result.tags
            ))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Status

    func fetchStatus() async throws -> SyncStatusResponse {
        try await APIClient.shared.request(Endpoint(.get, "/sync/status"))
    }

    // MARK: - Cache fallback

    var hasCachedBackup: Bool {
        guard let url = cacheURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var cachedBackupDate: Date? {
        guard let url = cacheURL else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    func restoreFromCache() throws {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else {
            throw APIClientError.noData
        }
        try BackupManager.shared.restore(from: data)
        NotificationCenter.default.post(name: .dayPinDataRestored, object: nil)
    }

    // MARK: - Private

    private var cacheURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("daypin_sync_cache.json")
    }

    private func writeCache(_ data: Data) {
        guard let url = cacheURL else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let dayPinSyncStateChanged = Notification.Name("daypin.syncStateChanged")
}

// MARK: - BackupManager helpers

private extension BackupManager {
    static var isoDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
