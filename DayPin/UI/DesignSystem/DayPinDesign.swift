import UIKit

enum DayPinDesign {

    // MARK: - Accent

    static var accent: UIColor      { ThemeManager.shared.colorScheme.accent }
    static var accentDeep: UIColor  { ThemeManager.shared.colorScheme.accentDeep }
    static var accentLight: UIColor { ThemeManager.shared.colorScheme.accentLight }

    // MARK: - Card tints

    static var textCardTint: UIColor  { ThemeManager.shared.colorScheme.textTint }
    static var imageCardTint: UIColor { ThemeManager.shared.colorScheme.imageTint }
    static var linkCardTint: UIColor  { ThemeManager.shared.colorScheme.linkTint }

    static let paleGold = UIColor(hex: "#FFF4D9") ?? UIColor(red: 1.0, green: 0.957, blue: 0.851, alpha: 1)

    /// Neutral base tinted ~3-7% with the current accent so it adapts to both themes and schemes.
    static var background: UIColor {
        UIColor { t in
            let isDark = t.userInterfaceStyle == .dark
            let base = isDark ? UIColor(hex: "#0D0D0D") ?? .black : UIColor(hex: "#F5F3EF") ?? .systemBackground
            let tint = ThemeManager.shared.colorScheme.accent
            return base.blendedWith(tint, fraction: isDark ? 0.05 : 0.07)
        }
    }

    static let cardSurface = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#161616") ?? .black
            : UIColor(hex: "#FDFCFA") ?? .systemBackground
    }

    static let cardBorderColor = UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.07)
    }
    static func cardBorderWidth(for traitCollection: UITraitCollection) -> CGFloat {
        traitCollection.userInterfaceStyle == .dark ? 1.0 : 0.5
    }

    // MARK: - Typography

    static let fontScreenTitle = UIFont.inter(ofSize: 34, weight: .bold)
    static let fontSectionHeader = UIFont.inter(ofSize: 22, weight: .semibold)
    static let fontBody = UIFont.inter(ofSize: 17, weight: .regular)
    static let fontButton = UIFont.inter(ofSize: 17, weight: .semibold)
    static let fontCaption = UIFont.inter(ofSize: 12, weight: .medium)

    // MARK: - Gradient

    static func accentGradientLayer(frame: CGRect,
                                    cornerRadius: CGFloat = 12) -> CAGradientLayer {
        let g = CAGradientLayer()
        g.colors = [accentDeep.cgColor, accentLight.cgColor]
        g.startPoint = CGPoint(x: 0, y: 0)
        g.endPoint = CGPoint(x: 1, y: 1)
        g.frame = frame
        g.cornerRadius = cornerRadius
        return g
    }

    // MARK: - Shadow

    static func applyCardShadow(to layer: CALayer, for traitCollection: UITraitCollection? = nil) {
        let isDark = traitCollection.map { $0.userInterfaceStyle == .dark } ?? true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = isDark ? 0.07 : 0.13
        layer.shadowRadius = isDark ? 12    : 8
        layer.shadowOffset = CGSize(width: 0, height: isDark ? 3 : 2)
    }

    // MARK: - Navigation Bar Appearance

    static func makeNavBarAppearance() -> UINavigationBarAppearance {
        let a = UINavigationBarAppearance()
        // Transparent so the gradient background shows through
        a.configureWithTransparentBackground()
        a.backgroundEffect = nil
        a.backgroundColor = .clear
        a.shadowColor = .clear
        a.titleTextAttributes = [
            .font: UIFont.inter(ofSize: 17, weight: .semibold),
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
            let base = isDark ? UIColor(hex: "#0D0D0D") ?? .black : UIColor(hex: "#F5F5F5") ?? .systemBackground
            let tinted = base.blendedWith(ThemeManager.shared.colorScheme.accent, fraction: isDark ? 0.09 : 0.07)
            return tinted.withAlphaComponent(isDark ? 0.86 : 0.90)
        }
        a.shadowColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.10)
                : UIColor.black.withAlphaComponent(0.05)
        }

        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.inter(ofSize: 10, weight: .medium),
            .foregroundColor: accent
        ]
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.inter(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        [a.inlineLayoutAppearance,
         a.stackedLayoutAppearance,
         a.compactInlineLayoutAppearance].forEach { item in
            item.selected.titleTextAttributes = selectedAttrs
            item.selected.iconColor = accent
            item.normal.titleTextAttributes = normalAttrs
            item.normal.iconColor = .secondaryLabel
        }
        return a
    }
}

extension UIColor {
    /// Linear interpolation `fraction` of the way from self toward `other`.
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
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)

        gradientContainer.isUserInteractionEnabled = false
        gradientContainer.layer.insertSublayer(gradientLayer, at: 0)
        insertSubview(gradientContainer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.colors = [DayPinDesign.accentDeep.cgColor, DayPinDesign.accentLight.cgColor]
        sendSubviewToBack(gradientContainer)
        let r = layer.cornerRadius
        gradientContainer.frame = bounds
        gradientContainer.layer.cornerRadius = r
        gradientContainer.layer.masksToBounds = true
        gradientLayer.frame = gradientContainer.bounds
        gradientLayer.cornerRadius = r
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

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let overlay = UIView()
    private let iconButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 4)

        blur.layer.cornerRadius = 26
        blur.layer.borderWidth = 0.5
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(overlay)

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
        overlay.backgroundColor = UIColor { trait in
            let dark = trait.userInterfaceStyle == .dark
            let base: UIColor = dark
                ? UIColor(red: 0.05 + r * 0.10, green: 0.05 + g * 0.10, blue: 0.05 + b * 0.10, alpha: 1)
                : UIColor(red: 0.96 + r * 0.04, green: 0.96 + g * 0.04, blue: 0.96 + b * 0.04, alpha: 1)
            return base.withAlphaComponent(dark ? 0.38 : 0.28)
        }
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
