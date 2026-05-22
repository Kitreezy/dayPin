import UIKit

// Circular avatar: photo if available, otherwise gradient + initials.
// Usage: AvatarView(size: 32) — self-sizing, just set frame or constraints.

final class AvatarView: UIView {

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    private let borderLayer = CALayer()

    var size: CGFloat

    init(size: CGFloat = 36) {
        self.size = size
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        layer.cornerRadius = size / 2
        clipsToBounds = true

        // Gradient background
        gradientLayer.cornerRadius = size / 2
        gradientLayer.frame = bounds
        layer.insertSublayer(gradientLayer, at: 0)

        // Photo
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Initials
        initialsLabel.textAlignment = .center
        initialsLabel.font = .inter(ofSize: size * 0.36, weight: .semibold)
        initialsLabel.textColor = .white
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(initialsLabel)
        NSLayoutConstraint.activate([
            initialsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Border ring
        borderLayer.cornerRadius = size / 2
        borderLayer.borderWidth = 1.5
        borderLayer.frame = bounds
        layer.addSublayer(borderLayer)

        refreshColors()
        configure(image: ProfileManager.shared.avatarImage,
                  initials: ProfileManager.shared.initials)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        borderLayer.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshColors()
    }

    private func refreshColors() {
        let accent = DayPinDesign.accent
        // Gradient: accent → slightly lighter variant
        gradientLayer.colors = [
            accent.withAlphaComponent(0.85).cgColor,
            accent.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        borderLayer.borderColor = accent.withAlphaComponent(0.30).cgColor
    }

    // MARK: - Configure

    func configure(image: UIImage?, initials: String) {
        if let img = image {
            imageView.image = img
            imageView.isHidden = false
            initialsLabel.isHidden = true
        } else {
            imageView.image = nil
            imageView.isHidden = true
            initialsLabel.isHidden = false
            initialsLabel.text = initials.isEmpty ? "?" : initials
        }
    }

    // Call when ProfileManager updates
    func refresh() {
        configure(image: ProfileManager.shared.avatarImage,
                  initials: ProfileManager.shared.initials)
        refreshColors()
    }
}
