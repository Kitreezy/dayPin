import Foundation

// MARK: - Auth Requests

struct RegisterRequest: Encodable {
    let email: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

struct DeleteAccountRequest: Encodable {
    let password: String
}

// MARK: - Auth Responses

struct AuthResponse: Decodable {
    let user: APIUser
    let token: String
    let refreshToken: String
}

struct TokenResponse: Decodable {
    let token: String
    let refreshToken: String
}

struct APIUser: Decodable {
    let id: String
    let email: String
    let createdAt: Date?
}

// MARK: - Sync

struct SyncPushResponse: Decodable {
    struct Stats: Decodable {
        let cards: Int
        let folders: Int
        let tags: Int
    }
    let syncedAt: Date
    let stats: Stats
}

// Note: "hasBacup" is a literal typo in the server spec — match it exactly.
struct SyncStatusResponse: Decodable {
    let hasBacup: Bool
    let syncedAt: Date?
    let backupVersion: Int?
    let sizeBytes: Int?
}

struct SyncSummary {
    let syncedAt: Date
    let cards: Int
    let folders: Int
    let tags: Int
}

// MARK: - Share Requests

struct CreateCardShareRequest: Encodable {
    let card: NoteCardDTO
    let expiresInDays: Int?
}

struct CreateCollectionShareRequest: Encodable {
    let title: String
    let cards: [NoteCardDTO]
    let folder: Folder?
    let expiresInDays: Int?
}

// MARK: - Share Responses

struct ShareCreatedResponse: Decodable {
    let shareID: String
    let url: String
    let expiresAt: Date?
}

struct ShareItem: Decodable {
    let shareID: String
    let type: String
    let title: String
    let url: String
    let createdAt: Date
    let expiresAt: Date?
    let viewCount: Int
}

struct ShareListResponse: Decodable {
    let shares: [ShareItem]
}

// MARK: - Public shared content (GET /s/:id, no auth)

struct SharedContentResponse: Decodable {
    let type: String       // "card" | "collection"
    let title: String
    let createdAt: Date
    let expiresAt: Date?
    let card: NoteCardDTO?
    let cards: [NoteCardDTO]?
    let folder: Folder?
}

// MARK: - Errors

struct ServerErrorBody: Decodable {
    let error: String
}
