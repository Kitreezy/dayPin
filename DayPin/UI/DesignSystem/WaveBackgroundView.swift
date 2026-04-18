import UIKit

/// Subtle wave watermark for app backgrounds.
/// Two soft overlapping bezier curves — very low opacity to serve as a brand accent.
final class WaveBackgroundView: UIView {

    private let wave1 = CAShapeLayer()
    private let wave2 = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(wave2)
        layer.addSublayer(wave1)
        updateColors()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged,
            object: nil
        )
    }

    @objc private func onSchemeChanged() {
        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePaths()
    }

    private func updatePaths() {
        let w = bounds.width
        let h = bounds.height

        // Wave 1 — large primary curve filling top ~38% of screen
        let p1 = UIBezierPath()
        p1.move(to: CGPoint(x: 0, y: 0))
        p1.addLine(to: CGPoint(x: 0, y: h * 0.26))
        p1.addCurve(
            to:            CGPoint(x: w,       y: h * 0.14),
            controlPoint1: CGPoint(x: w * 0.30, y: h * 0.42),
            controlPoint2: CGPoint(x: w * 0.68, y: h * 0.04)
        )
        p1.addLine(to: CGPoint(x: w, y: 0))
        p1.close()
        wave1.path = p1.cgPath

        // Wave 2 — secondary smaller curve for depth
        let p2 = UIBezierPath()
        p2.move(to: CGPoint(x: 0, y: 0))
        p2.addLine(to: CGPoint(x: 0, y: h * 0.14))
        p2.addCurve(
            to:            CGPoint(x: w,       y: h * 0.07),
            controlPoint1: CGPoint(x: w * 0.38, y: h * 0.24),
            controlPoint2: CGPoint(x: w * 0.72, y: h * 0.01)
        )
        p2.addLine(to: CGPoint(x: w, y: 0))
        p2.close()
        wave2.path = p2.cgPath
    }

    private func updateColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        wave1.fillColor = DayPinDesign.accent.withAlphaComponent(isDark ? 0.07 : 0.05).cgColor
        wave2.fillColor = DayPinDesign.accentDeep.withAlphaComponent(isDark ? 0.05 : 0.03).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            updateColors()
        }
    }
}
