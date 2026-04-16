import UIKit

// MARK: - DayPin Design System
// "Deep Space & Soft Cream" aesthetic
// Single source of truth for all colors, typography, and gradients.

enum DayPinDesign {

    // MARK: - Color Palette

    /// #9276FF — Primary interactive accent (buttons, selections, progress)
    static let accent      = UIColor(hex: "#9276FF")!
    /// #7A5AF8 — Gradient start (deeper violet)
    static let accentDeep  = UIColor(hex: "#7A5AF8")!
    /// #B692FF — Gradient end (lighter violet)
    static let accentLight = UIColor(hex: "#B692FF")!
    /// #FFF4D9 — Pale gold for micro-interactions / notification dots
    static let paleGold    = UIColor(hex: "#FFF4D9")!

    /// #F5F3EF (light) / #0D0D0D (dark)
    static let background = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#0D0D0D")!
            : UIColor(hex: "#F5F3EF")!
    }

    /// Warm off-white card surface in light; near-black in dark
    static let cardSurface = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#161616")!
            : UIColor(hex: "#FDFCFA")!
    }

    /// In dark mode: 1px border at 10% accent opacity. In light: no border.
    static let cardBorderColor = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#9276FF")!.withAlphaComponent(0.12)
            : UIColor.clear
    }
    static func cardBorderWidth(for traitCollection: UITraitCollection) -> CGFloat {
        traitCollection.userInterfaceStyle == .dark ? 1.0 : 0.0
    }

    // MARK: - Typography (SF Pro, Dynamic Type compatible)

    static let fontScreenTitle   = UIFont.systemFont(ofSize: 34, weight: .bold)
    static let fontSectionHeader = UIFont.systemFont(ofSize: 22, weight: .semibold)
    static let fontBody          = UIFont.systemFont(ofSize: 17, weight: .regular)
    static let fontButton        = UIFont.systemFont(ofSize: 17, weight: .semibold)
    static let fontCaption       = UIFont.systemFont(ofSize: 12, weight: .medium)

    // MARK: - Gradient Helpers

    /// Linear diagonal gradient: #7A5AF8 → #B692FF
    static func accentGradientLayer(frame: CGRect,
                                    cornerRadius: CGFloat = 12) -> CAGradientLayer {
        let g = CAGradientLayer()
        g.colors      = [accentDeep.cgColor, accentLight.cgColor]
        g.startPoint  = CGPoint(x: 0, y: 0)
        g.endPoint    = CGPoint(x: 1, y: 1)
        g.frame       = frame
        g.cornerRadius = cornerRadius
        return g
    }

    // MARK: - Shadow

    /// Subtle violet-tinted shadow for cards
    static func applyCardShadow(to layer: CALayer) {
        layer.shadowColor   = accent.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowRadius  = 14
        layer.shadowOffset  = CGSize(width: 0, height: 4)
    }

    // MARK: - Navigation Bar Appearance (Liquid Glass)

    static func makeNavBarAppearance() -> UINavigationBarAppearance {
        let a = UINavigationBarAppearance()
        a.configureWithDefaultBackground()
        a.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        a.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#0D0D0D")!.withAlphaComponent(0.82)
                : UIColor(hex: "#F5F3EF")!.withAlphaComponent(0.88)
        }
        a.shadowColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#9276FF")!.withAlphaComponent(0.08)
                : UIColor.black.withAlphaComponent(0.06)
        }
        a.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        return a
    }

    // MARK: - Tab Bar Appearance

    static func makeTabBarAppearance() -> UITabBarAppearance {
        let a = UITabBarAppearance()
        a.configureWithDefaultBackground()
        a.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        a.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#0D0D0D")!.withAlphaComponent(0.90)
                : UIColor(hex: "#F5F3EF")!.withAlphaComponent(0.92)
        }
        a.shadowColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#9276FF")!.withAlphaComponent(0.06)
                : UIColor.black.withAlphaComponent(0.05)
        }

        // Selected item: accent violet
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: accent
        ]
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        [a.inlineLayoutAppearance,
         a.stackedLayoutAppearance,
         a.compactInlineLayoutAppearance].forEach { item in
            item.selected.titleTextAttributes = selectedAttrs
            item.selected.iconColor           = accent
            item.normal.titleTextAttributes   = normalAttrs
            item.normal.iconColor             = .secondaryLabel
        }
        return a
    }
}

// MARK: - GradientButton
// UIButton subclass with a diagonal violet gradient background.
// Keeps the gradient layer in sync with layout.

final class GradientButton: UIButton {

    private let gradientContainer = UIView()
    private let gradientLayer     = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors     = [DayPinDesign.accentDeep.cgColor,
                                    DayPinDesign.accentLight.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)

        gradientContainer.isUserInteractionEnabled = false
        gradientContainer.layer.insertSublayer(gradientLayer, at: 0)
        // Insert as the very first subview so it stays behind imageView & titleLabel
        insertSubview(gradientContainer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        // UIButton переставляет subviews во время layout — принудительно отправляем контейнер назад
        sendSubviewToBack(gradientContainer)
        let r = layer.cornerRadius
        gradientContainer.frame               = bounds
        gradientContainer.layer.cornerRadius  = r
        gradientContainer.layer.masksToBounds = true
        gradientLayer.frame                   = gradientContainer.bounds
        gradientLayer.cornerRadius            = r
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.82 : 1
            }
        }
    }
}
