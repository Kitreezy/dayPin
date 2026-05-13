import Foundation

/// Mirror of DayPin/Shared/AppGroup.swift — must stay in sync.
/// Widget extension runs in its own process; it cannot import the main app module,
/// so this file is compiled separately into the widget target.
enum AppGroup {
    static let suiteName = "group.com.daypin.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
