import Foundation
import CloudKit

// Raw CloudKit layer — all network operations go through here.
// Never call this directly from UI; use CloudSyncManager instead.

final class CloudKitManager {

    static let shared = CloudKitManager()
    private init() {}

    let container = CKContainer(identifier: "iCloud.com.daypin.app")

    var privateDB: CKDatabase { container.privateCloudDatabase }

    // MARK: - Record types

    enum RecordType {
        static let noteCard = "NoteCard"
        static let folder = "Folder"
    }

    // MARK: - iCloud availability

    func checkAccountStatus() async -> CKAccountStatus {
        (try? await container.accountStatus()) ?? .couldNotDetermine
    }

    // MARK: - Save

    func save(_ record: CKRecord) async throws {
        try await privateDB.save(record)
    }

    func saveAll(_ records: [CKRecord]) async throws {
        guard !records.isEmpty else { return }
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        op.qualityOfService = .userInitiated
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let e): cont.resume(throwing: e)
                }
            }
            privateDB.add(op)
        }
    }

    // MARK: - Delete

    func delete(recordID: CKRecord.ID) async throws {
        try await privateDB.deleteRecord(withID: recordID)
    }

    // MARK: - Fetch all

    func fetchAll(type: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
        var results: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (matchResults, nextCursor): ([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?)
            if let c = cursor {
                (matchResults, nextCursor) = try await privateDB.records(continuingMatchFrom: c)
            } else {
                (matchResults, nextCursor) = try await privateDB.records(matching: query, resultsLimit: 200)
            }
            for (_, result) in matchResults {
                if let record = try? result.get() {
                    results.append(record)
                }
            }
            cursor = nextCursor
        } while cursor != nil

        return results
    }

    // MARK: - Fetch single

    func fetch(recordName: String, type: String) async throws -> CKRecord? {
        let id = CKRecord.ID(recordName: recordName)
        return try? await privateDB.record(for: id)
    }

    // MARK: - Subscription (push when data changes)

    func setupSubscription() async {
        let subID = "daypin-private-changes"

        // Check if already exists
        if let _ = try? await privateDB.subscription(for: subID) { return }

        let sub = CKDatabaseSubscription(subscriptionID: subID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true  // silent push
        sub.notificationInfo = info

        try? await privateDB.save(sub)
    }

    // MARK: - User identity

    func fetchUserIdentity() async throws -> CKUserIdentity {
        let recordID = try await container.userRecordID()
        let identitiesMap = try await container.userIdentities(forUserRecordIDs: [recordID])
        guard let identity = identitiesMap[recordID] else {
            throw CKError(.unknownItem)
        }
        return identity
    }

    // MARK: - CKAsset helpers

    static func asset(from data: Data, filename: String = UUID().uuidString) -> CKAsset? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return CKAsset(fileURL: url)
        } catch {
            return nil
        }
    }

    static func data(from asset: CKAsset?) -> Data? {
        guard let url = asset?.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }
}

// MARK: - NoteCardDTO <-> CKRecord

extension NoteCardDTO {

    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: CloudKitManager.RecordType.noteCard, recordID: recordID)
        record["type"] = type.rawValue
        record["title"] = title
        record["comment"] = comment
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        record["dayDate"] = dayDate
        if let d = deletedAt { record["deletedAt"] = d }
        if let hex = colorHex { record["colorHex"] = hex }
        if let fid = folderID { record["folderID"] = fid.uuidString }
        if let ids = tagIDs, !ids.isEmpty,
           let data = try? JSONEncoder().encode(ids) { record["tagIDsJSON"] = data }
        if let d = reminderDate { record["reminderDate"] = d }

        switch type {
        case .text:
            if let data = rtfData { record["rtfData"] = data }
        case .image:
            if let data = imageData {
                record["imageAsset"] = CloudKitManager.asset(from: data, filename: "\(id.uuidString)_img")
            }
            if let ann = annotations, !ann.isEmpty,
               let data = try? JSONEncoder().encode(ann) { record["annotationsJSON"] = data }
        case .link:
            if let s = urlString { record["urlString"] = s }
            if let t = previewTitle { record["previewTitle"] = t }
            if let d = previewDescription { record["previewDescription"] = d }
            if let data = previewImageData {
                record["previewImageAsset"] = CloudKitManager.asset(from: data, filename: "\(id.uuidString)_prev")
            }
            if let extras = extraURLStrings, !extras.isEmpty,
               let data = try? JSONEncoder().encode(extras) { record["extraURLsJSON"] = data }
        }
        return record
    }

    static func from(ckRecord r: CKRecord) -> NoteCardDTO? {
        guard
            let idStr = r.recordID.recordName as String?,
            let id = UUID(uuidString: idStr),
            let typeStr = r["type"] as? String,
            let cardType = CardType(rawValue: typeStr),
            let title = r["title"] as? String,
            let comment = r["comment"] as? String,
            let createdAt = r["createdAt"] as? Date,
            let dayDate = r["dayDate"] as? Date
        else { return nil }

        var dto = NoteCardDTO(
            id: id, type: cardType, title: title, comment: comment,
            createdAt: createdAt, dayDate: dayDate, deletedAt: nil
        )
        dto.modifiedAt = (r["modifiedAt"] as? Date) ?? createdAt
        dto.deletedAt = r["deletedAt"] as? Date
        dto.colorHex = r["colorHex"] as? String
        dto.reminderDate = r["reminderDate"] as? Date

        if let fidStr = r["folderID"] as? String { dto.folderID = UUID(uuidString: fidStr) }
        if let data = r["tagIDsJSON"] as? Data {
            dto.tagIDs = try? JSONDecoder().decode([UUID].self, from: data)
        }

        switch cardType {
        case .text:
            dto.rtfData = r["rtfData"] as? Data
        case .image:
            dto.imageData = CloudKitManager.data(from: r["imageAsset"] as? CKAsset)
            if let data = r["annotationsJSON"] as? Data {
                dto.annotations = try? JSONDecoder().decode([ImageAnnotation].self, from: data)
            }
        case .link:
            dto.urlString = r["urlString"] as? String
            dto.previewTitle = r["previewTitle"] as? String
            dto.previewDescription = r["previewDescription"] as? String
            dto.previewImageData = CloudKitManager.data(from: r["previewImageAsset"] as? CKAsset)
            if let data = r["extraURLsJSON"] as? Data {
                dto.extraURLStrings = try? JSONDecoder().decode([String].self, from: data)
            }
        }
        return dto
    }
}

// MARK: - Folder <-> CKRecord

extension Folder {

    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: CloudKitManager.RecordType.folder, recordID: recordID)
        record["name"] = name
        record["colorHex"] = colorHex
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        if let e = emojiIcon { record["emojiIcon"] = e }
        if let data = iconImageData {
            record["iconImageAsset"] = CloudKitManager.asset(from: data, filename: "\(id.uuidString)_icon")
        }
        return record
    }

    static func from(ckRecord r: CKRecord) -> Folder? {
        guard
            let idStr = r.recordID.recordName as String?,
            let id = UUID(uuidString: idStr),
            let name = r["name"] as? String,
            let colorHex = r["colorHex"] as? String,
            let createdAt = r["createdAt"] as? Date
        else { return nil }

        var folder = Folder(id: id, name: name, colorHex: colorHex)
        folder.createdAt = createdAt
        folder.modifiedAt = (r["modifiedAt"] as? Date) ?? createdAt
        folder.emojiIcon = r["emojiIcon"] as? String
        folder.iconImageData = CloudKitManager.data(from: r["iconImageAsset"] as? CKAsset)
        return folder
    }
}
