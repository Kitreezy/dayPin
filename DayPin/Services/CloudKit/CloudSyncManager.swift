import Foundation
import CloudKit

// High-level sync coordinator. CardStore and FolderStore call this after each local save.
// All CloudKit calls are fire-and-forget from the caller's perspective.

final class CloudSyncManager {

    static let shared = CloudSyncManager()
    private init() {}

    private let ck = CloudKitManager.shared
    private let syncQueue = DispatchQueue(label: "com.daypin.sync", qos: .utility)

    // MARK: - State

    enum SyncStatus {
        case idle
        case syncing
        case synced(Date)
        case error(String)
        case disabled // iCloud not available
    }

    private(set) var status: SyncStatus = .idle {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dayPinSyncStatusChanged, object: nil)
            }
        }
    }

    private(set) var isEnabled: Bool = false

    // Prevents sync loops: set to true while applying cloud data locally
    var isApplyingCloudData = false

    // MARK: - Setup

    func setup() {
        Task {
            let accountStatus = await ck.checkAccountStatus()
            guard accountStatus == .available else {
                await MainActor.run { self.status = .disabled }
                return
            }
            await MainActor.run { self.isEnabled = true }
            await ck.setupSubscription()
            await syncAll()
        }
    }

    // MARK: - Push (called by CardStore / FolderStore after local save)

    func push(cardID: UUID) {
        guard isEnabled, !isApplyingCloudData else { return }
        Task {
            guard let dto = CardStore.shared.allDTOs().first(where: { $0.id == cardID }) else { return }
            let record = dto.toCKRecord()
            try? await ck.save(record)
        }
    }

    func push(folderID: UUID) {
        guard isEnabled, !isApplyingCloudData else { return }
        Task {
            guard let folder = FolderStore.shared.folder(for: folderID) else { return }
            let record = folder.toCKRecord()
            try? await ck.save(record)
        }
    }

    func deleteFolder(id: UUID) {
        guard isEnabled else { return }
        Task {
            let rid = CKRecord.ID(recordName: id.uuidString)
            try? await ck.delete(recordID: rid)
        }
    }

    // MARK: - Full sync (on launch or after receiving a push)

    func syncAll() async {
        guard isEnabled else { return }
        await MainActor.run { self.status = .syncing }
        do {
            async let cardRecords = ck.fetchAll(type: CloudKitManager.RecordType.noteCard)
            async let folderRecords = ck.fetchAll(type: CloudKitManager.RecordType.folder)
            let (cards, folders) = try await (cardRecords, folderRecords)

            await mergeCards(from: cards)
            await mergeFolders(from: folders)

            await pushLocalOnlyItems()

            await MainActor.run { self.status = .synced(Date()) }
        } catch {
            await MainActor.run { self.status = .error(error.localizedDescription) }
        }
    }

    // MARK: - Merge: cloud → local

    private func mergeCards(from records: [CKRecord]) async {
        let cloudDTOs = records.compactMap { NoteCardDTO.from(ckRecord: $0) }
        let localDTOs = CardStore.shared.allDTOs()
        let localIndex = Dictionary(uniqueKeysWithValues: localDTOs.map { ($0.id, $0) })

        var updated: [NoteCardDTO] = []
        for cloud in cloudDTOs {
            if let local = localIndex[cloud.id] {
                // Prefer whichever was modified more recently
                if cloud.modifiedAt > local.modifiedAt {
                    updated.append(cloud)
                }
            } else {
                // New from cloud — add locally
                updated.append(cloud)
            }
        }

        if !updated.isEmpty {
            isApplyingCloudData = true
            await MainActor.run {
                var all = CardStore.shared.allDTOs()
                for dto in updated {
                    if let idx = all.firstIndex(where: { $0.id == dto.id }) {
                        all[idx] = dto
                    } else {
                        all.append(dto)
                    }
                }
                CardStore.shared.restore(dtos: all)
                NotificationCenter.default.post(name: .dayPinDataRestored, object: nil)
            }
            isApplyingCloudData = false
        }
    }

    private func mergeFolders(from records: [CKRecord]) async {
        let cloudFolders = records.compactMap { Folder.from(ckRecord: $0) }
        let localFolders = FolderStore.shared.all()
        let localIndex = Dictionary(uniqueKeysWithValues: localFolders.map { ($0.id, $0) })

        var updated: [Folder] = []
        for cloud in cloudFolders {
            if let local = localIndex[cloud.id] {
                if cloud.modifiedAt > local.modifiedAt {
                    updated.append(cloud)
                }
            } else {
                updated.append(cloud)
            }
        }

        if !updated.isEmpty {
            isApplyingCloudData = true
            await MainActor.run {
                var all = FolderStore.shared.all()
                for folder in updated {
                    if let idx = all.firstIndex(where: { $0.id == folder.id }) {
                        all[idx] = folder
                    } else {
                        all.append(folder)
                    }
                }
                FolderStore.shared.restore(folders: all)
            }
            isApplyingCloudData = false
        }
    }

    // MARK: - Push items that exist locally but not in cloud yet

    private func pushLocalOnlyItems() async {
        guard isEnabled else { return }
        do {
            let cloudCardIDs = Set(
                try await ck.fetchAll(type: CloudKitManager.RecordType.noteCard)
                    .compactMap { UUID(uuidString: $0.recordID.recordName) }
            )
            let localCards = CardStore.shared.allDTOs()
            let missing = localCards.filter { !cloudCardIDs.contains($0.id) }
            if !missing.isEmpty {
                try? await ck.saveAll(missing.map { $0.toCKRecord() })
            }

            let cloudFolderIDs = Set(
                try await ck.fetchAll(type: CloudKitManager.RecordType.folder)
                    .compactMap { UUID(uuidString: $0.recordID.recordName) }
            )
            let localFolders = FolderStore.shared.all()
            let missingFolders = localFolders.filter { !cloudFolderIDs.contains($0.id) }
            if !missingFolders.isEmpty {
                try? await ck.saveAll(missingFolders.map { $0.toCKRecord() })
            }
        } catch {
            // Non-critical — will retry on next sync
        }
    }

    // MARK: - Handle incoming push notification

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard notification?.notificationType == .database else { return }
        Task { await syncAll() }
    }

    // MARK: - Change notification for UI (who changed what)

    func postChangeNotice(authorName: String, cardTitle: String, cardID: UUID) {
        let info: [String: Any] = [
            "authorName": authorName,
            "cardTitle": cardTitle,
            "cardID": cardID
        ]
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .dayPinRemoteChangeReceived, object: nil, userInfo: info)
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let dayPinSyncStatusChanged = Notification.Name("dayPinSyncStatusChanged")
    static let dayPinRemoteChangeReceived = Notification.Name("dayPinRemoteChangeReceived")
}
