import Foundation

/// Shared App Group container — used by both the main app and the Widget extension.
/// The suite name must match exactly what is registered in the Apple Developer portal
/// and enabled in both targets' capabilities.
enum AppGroup {
    static let suiteName = "group.com.daypin.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? {
            assertionFailure("App Group '\(suiteName)' not configured. Check Signing & Capabilities.")
            return .standard
        }()
    }
}
