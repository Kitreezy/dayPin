import UIKit

/// Full-screen background view that renders the app's chosen background style.
/// Responds to color-scheme changes and `dayPinBackgroundChanged` with smooth animations.
final class GradientBackgroundView: UIView {

    // Two gradient layers for the "system" mode
    private let primaryLayer = CAGradientLayer()
    private let secondaryLayer = CAGradientLayer()
    // Solid layer for solid/custom-gradient modes
    private let solidLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        primaryLayer.type = .axial
        secondaryLayer.type = .axial
        solidLayer.type = .axial

        layer.insertSublayer(secondaryLayer, at: 0)
        layer.insertSublayer(primaryLayer,   at: 1)
        layer.insertSublayer(solidLayer,     at: 2)

        applyBackground(animated: false)

        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinBackgroundChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        primaryLayer.frame = bounds
        secondaryLayer.frame = bounds
        solidLayer.frame = bounds
    }

    @objc private func onSchemeChanged() { applyBackground(animated: true) }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            applyBackground(animated: true)
        }
    }

    /// Apply a specific background without touching `BackgroundManager` (used for previews).
    func preview(_ bg: AppBackground, animated: Bool = true) {
        applyBg(bg, animated: animated)
    }

    func applyBackground(animated: Bool) {
        applyBg(BackgroundManager.shared.current, animated: animated)
    }

    private func applyBg(_ bg: AppBackground, animated: Bool) {
        switch bg {
        case .system:
            applySystemGradient(animated: animated)
            solidLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]

        case .solidColor(let hex):
            let color = UIColor(hex: hex) ?? .systemBackground
            let colors: [CGColor] = [color.cgColor, color.cgColor]
            solidLayer.colors = colors
            solidLayer.startPoint = CGPoint(x: 0, y: 0)
            solidLayer.endPoint = CGPoint(x: 1, y: 1)
            // hide system layers
            primaryLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            secondaryLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            if animated { animateLayer(solidLayer, toColors: colors) }

        case .gradient(let startHex, let endHex, let angle):
            let startColor = UIColor(hex: startHex) ?? .systemBackground
            let endColor = UIColor(hex: endHex)   ?? .systemBackground
            let (start, end) = gradientPoints(for: angle)
            let colors: [CGColor] = [startColor.cgColor, endColor.cgColor]
            solidLayer.colors = colors
            solidLayer.startPoint = start
            solidLayer.endPoint = end
            primaryLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            secondaryLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
            if animated { animateLayer(solidLayer, toColors: colors) }
        }
    }

    // MARK: - System gradient (accent-tinted diagonal wash)

    private func applySystemGradient(animated: Bool) {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let accent = DayPinDesign.accent
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        accent.getRed(&r, green: &g, blue: &b, alpha: nil)

        let p0 = UIColor(red: r, green: g, blue: b, alpha: isDark ? 0.20 : 0.18).cgColor
        let p1 = UIColor(red: r, green: g, blue: b, alpha: isDark ? 0.07 : 0.07).cgColor
        let pClear = UIColor.clear.cgColor
        let primaryColors: [CGColor] = [p0, p1, pClear]
        primaryLayer.locations = [0.0, 0.30, 1.0]
        primaryLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        primaryLayer.endPoint = CGPoint(x: 1.0, y: 0.85)

        let s0 = UIColor(red: r, green: g, blue: b, alpha: isDark ? 0.10 : 0.09).cgColor
        let sClear = UIColor.clear.cgColor
        let secondaryColors: [CGColor] = [s0, sClear]
        secondaryLayer.locations = [0.0, 1.0]
        secondaryLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        secondaryLayer.endPoint = CGPoint(x: 0.2, y: 0.5)

        solidLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]

        if animated {
            animateLayer(primaryLayer,   toColors: primaryColors)
            animateLayer(secondaryLayer, toColors: secondaryColors)
        }
        primaryLayer.colors = primaryColors
        secondaryLayer.colors = secondaryColors
    }

    // MARK: - Helpers

    private func animateLayer(_ layer: CAGradientLayer, toColors: [CGColor]) {
        let anim = CABasicAnimation(keyPath: "colors")
        anim.fromValue = layer.presentation()?.colors ?? layer.colors
        anim.toValue = toColors
        anim.duration = 0.55
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: "gradientColors")
    }

    /// Convert a 0–360 angle (CSS-style, 0=top) to CAGradientLayer start/end points.
    private func gradientPoints(for angleDeg: Float) -> (CGPoint, CGPoint) {
        let rad = Double(angleDeg) * .pi / 180
        let x = sin(rad)
        let y = -cos(rad)
        let start = CGPoint(x: 0.5 - x / 2, y: 0.5 - y / 2)
        let end = CGPoint(x: 0.5 + x / 2, y: 0.5 + y / 2)
        return (start, end)
    }
}
