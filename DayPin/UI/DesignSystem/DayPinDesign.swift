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
            return base.blendedWith(tint, fraction: isDark ? 0.05 : 0.07)
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
        a.configureWithTransparentBackground()
        a.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        // Same tint formula as PillTabBar — accent RGB blended into near-black/near-white base
        a.backgroundColor = UIColor { t in
            let isDark  = t.userInterfaceStyle == .dark
            let accent  = ThemeManager.shared.colorScheme.accent
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            accent.getRed(&r, green: &g, blue: &b, alpha: nil)
            let base: UIColor = isDark
                ? UIColor(red: 0.05 + r * 0.10, green: 0.05 + g * 0.10, blue: 0.05 + b * 0.10, alpha: 1)
                : UIColor(red: 0.96 + r * 0.04, green: 0.96 + g * 0.04, blue: 0.96 + b * 0.04, alpha: 1)
            return base.withAlphaComponent(isDark ? 0.38 : 0.30)
        }
        // Hairline separator matches glass border aesthetic
        a.shadowColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
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
        a.configureWithTransparentBackground()
        a.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        a.backgroundColor = UIColor { t in
            let isDark = t.userInterfaceStyle == .dark
            let base   = isDark ? UIColor(hex: "#0D0D0D")! : UIColor(hex: "#F5F5F5")!
            let tinted = base.blendedWith(ThemeManager.shared.colorScheme.accent, fraction: isDark ? 0.09 : 0.07)
            return tinted.withAlphaComponent(isDark ? 0.86 : 0.90)
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

extension UIColor {
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

// MARK: - GlassFABView

final class GlassFABView: UIView {

    var action: (() -> Void)?

    private let blur       = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let overlay    = UIView()
    private let iconButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // Shadow on self — clipsToBounds stays false so shadow renders outside
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius  = 14
        layer.shadowOffset  = CGSize(width: 0, height: 4)

        // Blur pill
        blur.layer.cornerRadius = 26
        blur.layer.borderWidth  = 0.5
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.20).cgColor
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Accent tint overlay (behind icon, non-interactive)
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(overlay)

        // + icon button — fills entire pill to handle taps
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        iconButton.setImage(UIImage(systemName: "plus", withConfiguration: cfg), for: .normal)
        iconButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        iconButton.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(iconButton)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),

            iconButton.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            iconButton.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            iconButton.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            iconButton.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        refresh()
    }

    func refresh() {
        let accent = DayPinDesign.accent
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        accent.getRed(&r, green: &g, blue: &b, alpha: nil)
        let isDark = traitCollection.userInterfaceStyle == .dark
        let base: UIColor = isDark
            ? UIColor(red: 0.05 + r * 0.10, green: 0.05 + g * 0.10, blue: 0.05 + b * 0.10, alpha: 1)
            : UIColor(red: 0.96 + r * 0.04, green: 0.96 + g * 0.04, blue: 0.96 + b * 0.04, alpha: 1)
        overlay.backgroundColor = base.withAlphaComponent(isDark ? 0.38 : 0.28)
        iconButton.tintColor = accent
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 26).cgPath
    }

    override func traitCollectionDidChange(_ prev: UITraitCollection?) {
        super.traitCollectionDidChange(prev)
        if traitCollection.hasDifferentColorAppearance(comparedTo: prev) { refresh() }
    }

    @objc private func tapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        action?()
    }
}
