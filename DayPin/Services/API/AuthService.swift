import Foundation

// MARK: - Auth State

enum AuthState {
    case loading     // checking Keychain / restoring session on startup
    case signedOut
    case signedIn(APIUser)
}

// MARK: - AuthService

@MainActor
final class AuthService {

    static let shared = AuthService()
    private init() { restoreSession() }

    // MARK: - State

    private(set) var state: AuthState = .loading {
        didSet {
            NotificationCenter.default.post(name: .dayPinAuthStateChanged, object: nil)
            flushReadyContinuations()
        }
    }

    var isLoggedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var currentUser: APIUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    // MARK: - Startup readiness
    // Session restore (GET /auth/me) can take a while on a cold server -
    // callers that need to know "logged in or not" before showing UI (e.g.
    // the launch sign-in sheet) should await this instead of guessing a delay.

    private var readyContinuations: [CheckedContinuation<Void, Never>] = []

    var isReady: Bool {
        if case .loading = state { return false }
        return true
    }

    func awaitReady() async {
        if isReady { return }
        await withCheckedContinuation { cont in
            readyContinuations.append(cont)
        }
    }

    private func flushReadyContinuations() {
        guard isReady, !readyContinuations.isEmpty else { return }
        let conts = readyContinuations
        readyContinuations.removeAll()
        conts.forEach { $0.resume() }
    }

    // MARK: - Register

    func register(email: String, password: String) async throws {
        let body = RegisterRequest(email: email, password: password)
        let response: AuthResponse = try await APIClient.shared.request(
            Endpoint(.post, "/auth/register", body: body, auth: false)
        )
        save(response)
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        let body = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await APIClient.shared.request(
            Endpoint(.post, "/auth/login", body: body, auth: false)
        )
        save(response)
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainStore.shared.clearTokens()
        state = .signedOut
    }

    // MARK: - Delete Account

    func deleteAccount(password: String) async throws {
        _ = try await APIClient.shared.requestRaw(
            Endpoint(.delete, "/auth/account", body: DeleteAccountRequest(password: password))
        )
        KeychainStore.shared.clearAll()
        state = .signedOut
    }

    // MARK: - Session restore

    private func restoreSession() {
        guard KeychainStore.shared.accessToken != nil ||
              KeychainStore.shared.refreshToken != nil
        else {
            state = .signedOut
            return
        }
        Task {
            do {
                let user: APIUser = try await APIClient.shared.request(
                    Endpoint(.get, "/auth/me")
                )
                state = .signedIn(user)
            } catch {
                state = .signedOut
            }
        }
    }

    // MARK: - Private

    private func save(_ response: AuthResponse) {
        KeychainStore.shared.accessToken = response.token
        KeychainStore.shared.refreshToken = response.refreshToken
        state = .signedIn(response.user)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let dayPinAuthStateChanged = Notification.Name("daypin.authStateChanged")
}
