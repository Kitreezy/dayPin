import UIKit

// MARK: - Color Scheme ID

enum ColorSchemeID: Int, CaseIterable, Codable {
    case violet  = 0
    case ocean   = 1
    case nature  = 2
    case healing = 3
    case retro   = 4
    case spring  = 5
    case vintage = 6
    case garden  = 7

    var scheme: AppColorScheme {
        switch self {
        case .violet:  return .violet
        case .ocean:   return .ocean
        case .nature:  return .nature
        case .healing: return .healing
        case .retro:   return .retro
        case .spring:  return .spring
        case .vintage: return .vintage
        case .garden:  return .garden
        }
    }

    var displayName: String {
        switch self {
        case .violet:  return "Violet"
        case .ocean:   return "Ocean"
        case .nature:  return "Nature"
        case .healing: return "Healing"
        case .retro:   return "Retro"
        case .spring:  return "Spring"
        case .vintage: return "Vintage"
        case .garden:  return "Garden"
        }
    }

    var emoji: String {
        switch self {
        case .violet:  return "🔮"
        case .ocean:   return "🌊"
        case .nature:  return "🌿"
        case .healing: return "🪷"
        case .retro:   return "🎞"
        case .spring:  return "🫐"
        case .vintage: return "🍒"
        case .garden:  return "🌱"
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
        textTint:    UIColor(hex: "#9276FF")!,
        imageTint:   UIColor(hex: "#F2A7BB")!,
        linkTint:    UIColor(hex: "#FFB347")!
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

    // Palette 04 — перивинкль + весенний зелёный + тёмный navy
    static let spring = AppColorScheme(
        id: .spring, name: "Spring",
        accent:      UIColor(hex: "#95B1EE")!,
        accentDeep:  UIColor(hex: "#364C84")!,
        accentLight: UIColor(hex: "#B8CCEF")!,
        textTint:    UIColor(hex: "#95B1EE")!,
        imageTint:   UIColor(hex: "#A8C46A")!,   // насыщеннее, чем #E7F1A8
        linkTint:    UIColor(hex: "#364C84")!
    )

    // Palette 01 — вишня + кастард + голубика
    static let vintage = AppColorScheme(
        id: .vintage, name: "Vintage",
        accent:      UIColor(hex: "#861519")!,
        accentDeep:  UIColor(hex: "#620F12")!,
        accentLight: UIColor(hex: "#FAE38E")!,
        textTint:    UIColor(hex: "#861519")!,
        imageTint:   UIColor(hex: "#FAE38E")!,
        linkTint:    UIColor(hex: "#7AAAD6")!    // blueberry pie, чуть насыщеннее
    )

    // Graphic Garden — лайм + мягкий фиолетовый
    static let garden = AppColorScheme(
        id: .garden, name: "Garden",
        accent:      UIColor(hex: "#A184E5")!,
        accentDeep:  UIColor(hex: "#7B5EC7")!,
        accentLight: UIColor(hex: "#C2D039")!,
        textTint:    UIColor(hex: "#A184E5")!,
        imageTint:   UIColor(hex: "#C2D039")!,
        linkTint:    UIColor(hex: "#7B5EC7")!
    )

    static let all: [AppColorScheme] = [
        .violet, .ocean, .nature, .healing, .retro, .spring, .vintage, .garden
    ]
}
