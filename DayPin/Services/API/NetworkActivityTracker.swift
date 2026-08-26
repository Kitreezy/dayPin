import Foundation

// MARK: - NetworkActivityTracker
// Tracks how many API requests are currently in flight so the UI can show a
// single global "loading" indicator instead of leaving screens looking frozen
// while a request is pending.

@MainActor
final class NetworkActivityTracker {

    static let shared = NetworkActivityTracker()
    private init() {}

    private(set) var activeCount = 0 {
        didSet {
            NotificationCenter.default.post(name: .dayPinNetworkActivityChanged, object: nil)
        }
    }

    var isActive: Bool { activeCount > 0 }

    func begin() {
        activeCount += 1
    }

    func end() {
        activeCount = max(0, activeCount - 1)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let dayPinNetworkActivityChanged = Notification.Name("daypin.networkActivityChanged")
}
