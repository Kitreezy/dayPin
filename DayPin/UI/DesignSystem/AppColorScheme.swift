import UIKit

// MARK: - Color Scheme ID

enum ColorSchemeID: Int, CaseIterable, Codable {
    case violet  = 0
    case ocean   = 1
    case nature  = 2
    case healing = 3
    case retro   = 4

    var scheme: AppColorScheme {
        switch self {
        case .violet:  return .violet
        case .ocean:   return .ocean
        case .nature:  return .nature
        case .healing: return .healing
        case .retro:   return .retro
        }
    }

    var displayName: String {
        switch self {
        case .violet:  return "Violet"
        case .ocean:   return "Ocean"
        case .nature:  return "Nature"
        case .healing: return "Healing"
        case .retro:   return "Retro"
        }
    }

    var emoji: String {
        switch self {
        case .violet:  return "🔮"
        case .ocean:   return "🌊"
        case .nature:  return "🌿"
        case .healing: return "🪷"
        case .retro:   return "🎞"
        }
    }
}

// MARK: - AppColorScheme

struct AppColorScheme {
    let id: ColorSchemeID
    let name: String

    /// Primary interactive accent
    let accent: UIColor
    /// Darker accent (gradient start, deep accents)
    let accentDeep: UIColor
    /// Lighter accent (gradient end, highlights)
    let accentLight: UIColor

    /// Tint used for text card icon / border accent
    let textTint: UIColor
    /// Tint used for image card pin icon
    let imageTint: UIColor
    /// Tint used for link card icon / url label
    let linkTint: UIColor

    // MARK: - Built-in schemes

    static let violet = AppColorScheme(
        id: .violet, name: "Violet",
        accent:      UIColor(hex: "#9276FF")!,
        accentDeep:  UIColor(hex: "#7A5AF8")!,
        accentLight: UIColor(hex: "#B692FF")!,
        textTint:    UIColor(hex: "#9276FF")!,   // violet
        imageTint:   UIColor(hex: "#F2A7BB")!,   // sakura pink
        linkTint:    UIColor(hex: "#FFB347")!     // warm amber
    )

    static let ocean = AppColorScheme(
        id: .ocean, name: "Ocean",
        accent:      UIColor(hex: "#2196F3")!,
        accentDeep:  UIColor(hex: "#1565C0")!,
        accentLight: UIColor(hex: "#64B5F6")!,
        textTint:    UIColor(hex: "#2196F3")!,
        imageTint:   UIColor(hex: "#26C6DA")!,
        linkTint:    UIColor(hex: "#EF5350")!
    )

    static let nature = AppColorScheme(
        id: .nature, name: "Nature",
        accent:      UIColor(hex: "#2886D4")!,
        accentDeep:  UIColor(hex: "#1A6BB5")!,
        accentLight: UIColor(hex: "#7BB732")!,
        textTint:    UIColor(hex: "#2886D4")!,
        imageTint:   UIColor(hex: "#7BB732")!,
        linkTint:    UIColor(hex: "#E6A817")!
    )

    static let healing = AppColorScheme(
        id: .healing, name: "Healing",
        accent:      UIColor(hex: "#7986CB")!,
        accentDeep:  UIColor(hex: "#5C6BC0")!,
        accentLight: UIColor(hex: "#ADB5D5")!,
        textTint:    UIColor(hex: "#7986CB")!,
        imageTint:   UIColor(hex: "#C4A05A")!,
        linkTint:    UIColor(hex: "#B5879A")!
    )

    static let retro = AppColorScheme(
        id: .retro, name: "Retro",
        accent:      UIColor(hex: "#4B607F")!,
        accentDeep:  UIColor(hex: "#344A64")!,
        accentLight: UIColor(hex: "#7A90A8")!,
        textTint:    UIColor(hex: "#4B607F")!,
        imageTint:   UIColor(hex: "#F3701E")!,
        linkTint:    UIColor(hex: "#C7917A")!
    )

    static let all: [AppColorScheme] = [.violet, .ocean, .nature, .healing, .retro]
}
