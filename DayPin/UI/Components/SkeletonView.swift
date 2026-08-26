import UIKit

// MARK: - SkeletonView

/// Drop-in shimmer placeholder. Set frame/constraints, call startAnimating().
final class SkeletonView: UIView {

    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        layer.cornerRadius = 8
        clipsToBounds = true
        updateBaseColor()

        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.locations = [-1, -0.5, 0]
        layer.addSublayer(gradient)
        updateGradientColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = CGRect(x: -bounds.width, y: 0,
                                width: bounds.width * 3, height: bounds.height)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBaseColor()
            updateGradientColors()
        }
    }

    // MARK: - Animation

    func startAnimating() {
        guard gradient.animation(forKey: "shimmer") == nil else { return }
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-1, -0.5, 0]
        anim.toValue = [1, 1.5, 2]
        anim.duration = 1.3
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(anim, forKey: "shimmer")
    }

    func stopAnimating() {
        gradient.removeAnimation(forKey: "shimmer")
    }

    // MARK: - Private

    private func updateBaseColor() {
        let dark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = dark
            ? UIColor(white: 0.20, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    }

    private func updateGradientColors() {
        let dark = traitCollection.userInterfaceStyle == .dark
        let base = dark ? UIColor(white: 0.20, alpha: 1) : UIColor(white: 0.88, alpha: 1)
        let highlight = dark ? UIColor(white: 0.32, alpha: 1) : UIColor(white: 0.96, alpha: 1)
        gradient.colors = [base.cgColor, highlight.cgColor, base.cgColor]
    }
}

// MARK: - UIView + Skeleton helpers

extension UIView {

    /// Attaches skeleton subviews and starts animation.
    func addSkeleton(_ skeletons: [SkeletonView]) {
        skeletons.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
            $0.startAnimating()
        }
    }

    func removeSkeleton(_ skeletons: [SkeletonView]) {
        skeletons.forEach {
            $0.stopAnimating()
            $0.removeFromSuperview()
        }
    }
}
