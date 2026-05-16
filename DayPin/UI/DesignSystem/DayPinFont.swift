import UIKit

// MARK: - DayPin Font System
//
// Uses Inter if the font files are present in the bundle (registered in Info.plist).
// Falls back gracefully to SF Pro (UIFont.systemFont) so the app always compiles.

enum DayPinFont {

    // MARK: - Check availability

    private static let isInterAvailable: Bool = {
        UIFont.familyNames.contains("Inter")
    }()

    // MARK: - Core factory

    static func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        guard isInterAvailable else {
            return .systemFont(ofSize: size, weight: weight)
        }
        let name: String
        switch weight {
        case .bold,      .heavy, .black:  name = "Inter-Bold"
        case .semibold:                    name = "Inter-SemiBold"
        case .medium:                      name = "Inter-Medium"
        default:                           name = "Inter-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    // MARK: - Named sizes (mirrors DayPinDesign typography)

    static func largeTitle()  -> UIFont { font(size: 34, weight: .bold) }
    static func title()       -> UIFont { font(size: 28, weight: .bold) }
    static func headline()    -> UIFont { font(size: 17, weight: .semibold) }
    static func body()        -> UIFont { font(size: 16, weight: .regular) }
    static func subheadline() -> UIFont { font(size: 15, weight: .regular) }
    static func callout()     -> UIFont { font(size: 14, weight: .regular) }
    static func footnote()    -> UIFont { font(size: 12, weight: .regular) }
    static func caption()     -> UIFont { font(size: 11, weight: .medium) }
    static func caption2()    -> UIFont { font(size: 10, weight: .medium) }

    // Semibold variants used in card cells / headers
    static func subheadlineSemibold() -> UIFont { font(size: 15, weight: .semibold) }
    static func footnoteSemibold()    -> UIFont { font(size: 12, weight: .semibold) }
    static func captionSemibold()     -> UIFont { font(size: 11, weight: .semibold) }
}

// MARK: - UIFont convenience (matches old systemFont call-sites)

extension UIFont {
    static func inter(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        DayPinFont.font(size: size, weight: weight)
    }
}
