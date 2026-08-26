import Foundation

#if DEBUG

// MARK: - NetworkLogEntry

struct NetworkLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let path: String
    let requestBody: Data?
    let responseBody: Data?
    let errorMessage: String?
    let duration: TimeInterval

    var isSuccess: Bool { errorMessage == nil }
}

// MARK: - NetworkLogger
// In-memory log of API calls, surfaced in the debug-only "Network" tab.
// Never compiled into release builds.

@MainActor
final class NetworkLogger {

    static let shared = NetworkLogger()
    private init() {}

    private(set) var entries: [NetworkLogEntry] = []
    private let maxEntries = 200

    func record(endpoint: Endpoint, responseData: Data?, error: Error?, duration: TimeInterval) {
        let entry = NetworkLogEntry(
            timestamp: Date(),
            method: endpoint.method.rawValue,
            path: endpoint.path,
            requestBody: endpoint.body.flatMap { try? JSONEncoder().encode($0) },
            responseBody: responseData,
            errorMessage: error?.localizedDescription,
            duration: duration
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        NotificationCenter.default.post(name: .dayPinNetworkLogUpdated, object: nil)
    }

    func clear() {
        entries.removeAll()
        NotificationCenter.default.post(name: .dayPinNetworkLogUpdated, object: nil)
    }
}

extension Notification.Name {
    static let dayPinNetworkLogUpdated = Notification.Name("daypin.networkLogUpdated")
}

#endif
