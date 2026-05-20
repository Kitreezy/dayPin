import Foundation

// Shared UserDefaults for the main app and Widget extension — suite name must match the portal.
enum AppGroup {
    static let suiteName = "group.com.daypin.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? {
            assertionFailure("App Group '\(suiteName)' not configured. Check Signing & Capabilities.")
            return .standard
        }()
    }
}
