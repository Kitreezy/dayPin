import UIKit

// Toast shown when a shared note was changed by another user.
// Appears at the bottom of the screen, dismisses after 4 seconds.

final class RemoteChangeToast: UIView {

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let tint = UIView()
    private let iconView = UIImageView()
    private let textStack = UIStackView()
    private let authorLabel = UILabel()
    private let bodyLabel = UILabel()

    init(author: String, cardTitle: String) {
        super.init(frame: .zero)
        setup(author: author, cardTitle: cardTitle)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(author: String, cardTitle: String) {
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        blur.layer.cornerRadius = 16
        blur.layer.borderWidth = 0.5
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.06)
                : UIColor(white: 1.0, alpha: 0.55)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        // Icon
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: "person.fill.badge.plus", withConfiguration: cfg)
        iconView.tintColor = DayPinDesign.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Text
        authorLabel.text = author
        authorLabel.font = .inter(ofSize: 14, weight: .semibold)
        authorLabel.textColor = .label

        bodyLabel.text = cardTitle
        bodyLabel.font = .inter(ofSize: 13)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 1
        bodyLabel.lineBreakMode = .byTruncatingTail

        textStack.axis = .vertical
        textStack.spacing = 1
        textStack.addArrangedSubview(authorLabel)
        textStack.addArrangedSubview(bodyLabel)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        blur.contentView.addSubview(iconView)
        blur.contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: blur.contentView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: blur.contentView.bottomAnchor, constant: -12)
        ])

        heightAnchor.constraint(equalToConstant: 60).isActive = true
    }

    // MARK: - Animate

    func show(duration: TimeInterval = 4.0) {
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: 20)

        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.transform = .identity
        }

        UIView.animate(withDuration: 0.3, delay: duration,
                       options: .curveEaseIn) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 10)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}
