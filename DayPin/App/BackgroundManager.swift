import UIKit

// MARK: - AppBackground

enum AppBackground: Equatable {
    case system
    case solidColor(hex: String)
    case gradient(startHex: String, endHex: String, angle: Float)
}

extension AppBackground {

    private static let modeKey = "daypin.bgMode"
    private static let startHexKey = "daypin.bgStartHex"
    private static let endHexKey = "daypin.bgEndHex"
    private static let angleKey = "daypin.bgAngle"

    var modeName: String {
        switch self {
        case .system:    return "system"
        case .solidColor: return "solid"
        case .gradient:  return "gradient"
        }
    }

    func save() {
        let ud = UserDefaults.standard
        ud.set(modeName, forKey: Self.modeKey)
        switch self {
        case .system:
            ud.removeObject(forKey: Self.startHexKey)
            ud.removeObject(forKey: Self.endHexKey)
            ud.removeObject(forKey: Self.angleKey)
        case .solidColor(let hex):
            ud.set(hex, forKey: Self.startHexKey)
        case .gradient(let s, let e, let a):
            ud.set(s, forKey: Self.startHexKey)
            ud.set(e, forKey: Self.endHexKey)
            ud.set(a, forKey: Self.angleKey)
        }
    }

    static func load() -> AppBackground {
        let ud = UserDefaults.standard
        let mode = ud.string(forKey: modeKey) ?? "system"
        switch mode {
        case "solid":
            let hex = ud.string(forKey: startHexKey) ?? "#FFFFFF"
            return .solidColor(hex: hex)
        case "gradient":
            let s = ud.string(forKey: startHexKey) ?? "#FFFFFF"
            let e = ud.string(forKey: endHexKey)   ?? "#FFFFFF"
            let a = ud.float(forKey: angleKey)
            return .gradient(startHex: s, endHex: e, angle: a)
        default:
            return .system
        }
    }
}

// MARK: - BackgroundManager

final class BackgroundManager {

    static let shared = BackgroundManager()
    private init() {}

    var current: AppBackground = AppBackground.load() {
        didSet {
            current.save()
            NotificationCenter.default.post(name: .dayPinBackgroundChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let dayPinBackgroundChanged = Notification.Name("dayPinBackgroundChanged")
}
