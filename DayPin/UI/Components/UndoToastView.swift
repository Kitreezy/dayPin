import UIKit

/// Floating glass toast shown after a card is deleted.
/// Displays a "Note deleted" message and an "Undo" button for 4 seconds.
final class UndoToastView: UIView {

    // MARK: - Callback

    var onUndo: (() -> Void)?

    // MARK: - Private views

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let messageLabel = UILabel()
    private let undoButton = UIButton(type: .system)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        // Shadow on self (not on blur so shadow renders outside rounded rect)
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 4)

        // Blur view - clips to rounded rect
        blur.layer.cornerRadius = 16
        blur.clipsToBounds = true
        blur.layer.borderWidth = 0.5
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        // Tint overlay - dynamic color for dark/light
        let tint = UIView()
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.10)
                : UIColor(white: 1.0, alpha: 0.65)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)

        // Message label
        messageLabel.text = L10n.noteDeleted
        messageLabel.font = .inter(ofSize: 14, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(messageLabel)

        // Undo button
        undoButton.setTitle(L10n.undo, for: .normal)
        undoButton.titleLabel?.font = .inter(ofSize: 14, weight: .semibold)
        undoButton.tintColor = DayPinDesign.accent
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        blur.contentView.addSubview(undoButton)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),

            blur.contentView.heightAnchor.constraint(equalToConstant: 52),

            messageLabel.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            messageLabel.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),

            undoButton.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -12),
            undoButton.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            undoButton.leadingAnchor.constraint(greaterThanOrEqualTo: messageLabel.trailingAnchor, constant: 8)
        ])

        refreshBorderColor()
    }

    // MARK: - Adaptive border

    private func refreshBorderColor() {
        let dark = traitCollection.userInterfaceStyle == .dark
        blur.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.18).cgColor
            : UIColor.black.withAlphaComponent(0.12).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshBorderColor()
        }
    }

    // MARK: - Language / accent refresh

    func refresh() {
        messageLabel.text = L10n.noteDeleted
        undoButton.setTitle(L10n.undo, for: .normal)
    }

    func refreshAccent() {
        undoButton.tintColor = DayPinDesign.accent
    }

    // MARK: - Action

    @objc private func undoTapped() {
        onUndo?()
    }
}
