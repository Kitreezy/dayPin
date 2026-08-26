import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

// MARK: - Endpoint

struct Endpoint {
    let method: HTTPMethod
    let path: String
    let body: (any Encodable)?
    let requiresAuth: Bool

    init(_ method: HTTPMethod, _ path: String, body: (any Encodable)? = nil, auth: Bool = true) {
        self.method = method
        self.path = path
        self.body = body
        self.requiresAuth = auth
    }
}

// MARK: - APIClientError

enum APIClientError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)
    case noData
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid server URL"
        case .unauthorized:          return "Session expired - please sign in again"
        case .serverError(let msg):  return msg
        case .noData:                return "No data received"
        case .decodingError(let e):  return e.localizedDescription
        }
    }
}

// MARK: - APIClient

final class APIClient {

    static let shared = APIClient()
    private init() {}

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: "daypin.serverURL") ?? "https://daypin-server.onrender.com" }
        set { UserDefaults.standard.set(newValue, forKey: "daypin.serverURL") }
    }

    private let session = URLSession.shared

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // Serialises concurrent token refreshes into a single network call.
    private var isRefreshing = false
    private var pendingRefreshConts: [CheckedContinuation<String, Error>] = []

    // MARK: - Public

    /// Fetches endpoint and decodes JSON response into T.
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await trackedPerform(endpoint)
        guard !data.isEmpty else { throw APIClientError.noData }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingError(error)
        }
    }

    /// Fetches endpoint and returns raw Data. Safe for 204 No Content (returns empty Data).
    func requestRaw(_ endpoint: Endpoint) async throws -> Data {
        try await trackedPerform(endpoint)
    }

    /// Fetches endpoint and decodes JSON, returning nil on 204 No Content.
    func requestOptional<T: Decodable>(_ endpoint: Endpoint) async throws -> T? {
        let data = try await trackedPerform(endpoint)
        guard !data.isEmpty else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingError(error)
        }
    }

    // MARK: - Activity tracking + debug logging
    // Single choke point every public call goes through, so the global
    // loading HUD and the debug Network tab stay accurate without touching
    // the retry/refresh logic in `perform(_:retrying:)`.

    private func trackedPerform(_ endpoint: Endpoint) async throws -> Data {
        await NetworkActivityTracker.shared.begin()
        let start = Date()
        do {
            let data = try await perform(endpoint, retrying: true)
            #if DEBUG
            await NetworkLogger.shared.record(endpoint: endpoint, responseData: data, error: nil, duration: Date().timeIntervalSince(start))
            #endif
            await NetworkActivityTracker.shared.end()
            return data
        } catch {
            #if DEBUG
            await NetworkLogger.shared.record(endpoint: endpoint, responseData: nil, error: error, duration: Date().timeIntervalSince(start))
            #endif
            await NetworkActivityTracker.shared.end()
            throw error
        }
    }

    // MARK: - Private

    private func perform(_ endpoint: Endpoint, retrying: Bool) async throws -> Data {
        var req = try makeURLRequest(endpoint)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.noData }

        switch http.statusCode {
        case 200...299:
            return data

        case 401 where retrying && endpoint.requiresAuth:
            // Single refresh, then retry once.
            let newToken = try await refreshAccessToken()
            req.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResp) = try await session.data(for: req)
            guard let retryHTTP = retryResp as? HTTPURLResponse else { throw APIClientError.noData }
            if retryHTTP.statusCode >= 200 && retryHTTP.statusCode < 300 { return retryData }
            // Still 401 after refresh - force sign out.
            await MainActor.run { AuthService.shared.signOut() }
            throw APIClientError.unauthorized

        case 401:
            await MainActor.run { AuthService.shared.signOut() }
            throw APIClientError.unauthorized

        default:
            throw parseServerError(data)
        }
    }

    private func makeURLRequest(_ endpoint: Endpoint) throws -> URLRequest {
        guard let url = URL(string: APIClient.baseURL + endpoint.path) else {
            throw APIClientError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if endpoint.requiresAuth, let token = KeychainStore.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }

    private func parseServerError(_ data: Data) -> Error {
        if let body = try? decoder.decode(ServerErrorBody.self, from: data) {
            return APIClientError.serverError(body.error)
        }
        return APIClientError.serverError("Unexpected server error")
    }

    // MARK: - Token refresh

    private func refreshAccessToken() async throws -> String {
        // If a refresh is already in flight, wait for its result.
        if isRefreshing {
            return try await withCheckedThrowingContinuation { cont in
                pendingRefreshConts.append(cont)
            }
        }

        isRefreshing = true
        defer {
            isRefreshing = false
            pendingRefreshConts.removeAll()
        }

        guard let storedRefresh = KeychainStore.shared.refreshToken else {
            throw APIClientError.unauthorized
        }

        let ep = Endpoint(.post, "/auth/refresh",
                          body: RefreshRequest(refreshToken: storedRefresh), auth: false)
        let tokens: TokenResponse = try await request(ep)
        KeychainStore.shared.accessToken = tokens.token
        KeychainStore.shared.refreshToken = tokens.refreshToken

        // Deliver token to any waiting callers.
        for cont in pendingRefreshConts { cont.resume(returning: tokens.token) }
        return tokens.token
    }
}
