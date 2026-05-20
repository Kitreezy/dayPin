import UIKit
import WidgetKit

// MARK: - Notification Names

extension Notification.Name {
    static let dayPinColorSchemeChanged = Notification.Name("dayPinColorSchemeChanged")
    // Add-note typed triggers (posted by the global "+" grid, consumed by active VC)
    static let dayPinAddText = Notification.Name("daypin.addText")
    static let dayPinAddPhoto = Notification.Name("daypin.addPhoto")
    static let dayPinAddCamera = Notification.Name("daypin.addCamera")
    static let dayPinAddLink = Notification.Name("daypin.addLink")
    /// Posted by NotePickerViewController after notes are added to a folder.
    /// FolderDetailViewController listens to this and reloads.
    static let dayPinFolderNeedsRefresh = Notification.Name("daypin.folderNeedsRefresh")
}

// MARK: - AppTheme (brightness)

enum AppTheme: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return L10n.themeSystem
        case .light:  return L10n.themeLight
        case .dark:   return L10n.themeDark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon.stars"
        }
    }
}

// MARK: - ThemeManager

final class ThemeManager {
    static let shared = ThemeManager()
    private init() {}

    private let themeKey = "appTheme"
    private let schemeKey = "colorSchemeID"

    var current: AppTheme {
        get { AppTheme(rawValue: UserDefaults.standard.integer(forKey: themeKey)) ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
            applyBrightness()
        }
    }

    var colorScheme: AppColorScheme {
        get {
            let raw = UserDefaults.standard.integer(forKey: schemeKey)
            return (ColorSchemeID(rawValue: raw) ?? .violet).scheme
        }
        set {
            UserDefaults.standard.set(newValue.id.rawValue, forKey: schemeKey)
            AppGroup.defaults.set(newValue.id.rawValue, forKey: "daypin.colorSchemeID")
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: .dayPinColorSchemeChanged, object: nil)
        }
    }

    // MARK: Apply

    func apply() {
        applyBrightness()
        AppGroup.defaults.set(colorScheme.id.rawValue, forKey: "daypin.colorSchemeID")
    }

    private func applyBrightness() {
        let style = current.userInterfaceStyle
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}
