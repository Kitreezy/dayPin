import Foundation

final class ShareService {

    static let shared = ShareService()
    private init() {}

    // MARK: - Create

    func createCardShare(card: NoteCard, expiresInDays: Int?) async throws -> ShareCreatedResponse {
        let body = CreateCardShareRequest(
            card: NoteCardDTO(from: card),
            expiresInDays: expiresInDays
        )
        return try await APIClient.shared.request(Endpoint(.post, "/share/card", body: body))
    }

    func createCollectionShare(
        title: String,
        cards: [NoteCard],
        folder: Folder?,
        expiresInDays: Int?
    ) async throws -> ShareCreatedResponse {
        let body = CreateCollectionShareRequest(
            title: title,
            cards: cards.map { NoteCardDTO(from: $0) },
            folder: folder,
            expiresInDays: expiresInDays
        )
        return try await APIClient.shared.request(Endpoint(.post, "/share/collection", body: body))
    }

    // MARK: - List & delete

    func myShares() async throws -> [ShareItem] {
        let response: ShareListResponse = try await APIClient.shared.request(
            Endpoint(.get, "/share")
        )
        return response.shares
    }

    func deleteShare(id: String) async throws {
        _ = try await APIClient.shared.requestRaw(Endpoint(.delete, "/share/\(id)"))
    }

    // MARK: - Fetch shared content (public, no auth)

    func fetchSharedContent(id: String) async throws -> SharedContentResponse {
        try await APIClient.shared.request(Endpoint(.get, "/s/\(id)", auth: false))
    }
}
