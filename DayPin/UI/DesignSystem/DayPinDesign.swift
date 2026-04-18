import UIKit

// MARK: - DayPin Design System

enum DayPinDesign {

    // MARK: - Scheme-driven accent colors (computed from current theme)

    static var accent: UIColor      { ThemeManager.shared.colorScheme.accent }
    static var accentDeep: UIColor  { ThemeManager.shared.colorScheme.accentDeep }
    static var accentLight: UIColor { ThemeManager.shared.colorScheme.accentLight }

    // MARK: - Per-card-type tints

    static var textCardTint: UIColor  { ThemeManager.shared.colorScheme.textTint }
    static var imageCardTint: UIColor { ThemeManager.shared.colorScheme.imageTint }
    static var linkCardTint: UIColor  { ThemeManager.shared.colorScheme.linkTint }

    // MARK: - Static colors (not scheme-dependent)

    static let paleGold = UIColor(hex: "#FFF4D9")!

    /// Neutral base tinted ~3-4% with the current accent — adapts to light/dark and scheme.
    static var background: UIColor {
        UIColor { t in
            let isDark = t.userInterfaceStyle == .dark
            let base   = isDark ? UIColor(hex: "#0D0D0D")! : UIColor(hex: "#F5F3EF")!
            let tint   = ThemeManager.shared.colorScheme.accent
            return base.blendedWith(tint, fraction: isDark ? 0.04 : 0.03)
        }
    }

    static let cardSurface = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#161616")!
            : UIColor(hex: "#FDFCFA")!
    }

    static let cardBorderColor = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.clear
    }
    static func cardBorderWidth(for traitCollection: UITraitCollection) -> CGFloat {
        traitCollection.userInterfaceStyle == .dark ? 1.0 : 0.0
    }

    // MARK: - Typography

    static let fontScreenTitle   = UIFont.systemFont(ofSize: 34, weight: .bold)
    static let fontSectionHeader = UIFont.systemFont(ofSize: 22, weight: .semibold)
    static let fontBody          = UIFont.systemFont(ofSize: 17, weight: .regular)
    static let fontButton        = UIFont.systemFont(ofSize: 17, weight: .semibold)
    static let fontCaption       = UIFont.systemFont(ofSize: 12, weight: .medium)

    // MARK: - Gradient

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

    // MARK: - Shadow (neutral, not accent-tinted)

    static func applyCardShadow(to layer: CALayer) {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowRadius  = 12
        layer.shadowOffset  = CGSize(width: 0, height: 3)
    }

    // MARK: - Navigation Bar Appearance

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
                ? UIColor.black.withAlphaComponent(0.12)
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
                ? UIColor.black.withAlphaComponent(0.10)
                : UIColor.black.withAlphaComponent(0.05)
        }

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

// MARK: - UIColor helpers

private extension UIColor {
    /// Linearly interpolate `fraction` of the way from self toward `other`.
    func blendedWith(_ other: UIColor, fraction f: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: nil)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
        return UIColor(
            red:   r1 + (r2 - r1) * f,
            green: g1 + (g2 - g1) * f,
            blue:  b1 + (b2 - b1) * f,
            alpha: 1
        )
    }
}

// MARK: - GradientButton

final class GradientButton: UIButton {

    private let gradientContainer = UIView()
    private let gradientLayer     = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)

        gradientContainer.isUserInteractionEnabled = false
        gradientContainer.layer.insertSublayer(gradientLayer, at: 0)
        insertSubview(gradientContainer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Refresh gradient colors from current scheme on every layout pass
        gradientLayer.colors = [DayPinDesign.accentDeep.cgColor, DayPinDesign.accentLight.cgColor]
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
