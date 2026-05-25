import UIKit

/// Floating glass toast displayed while multi-photo import is in progress.
/// Shows "Adding N photos..." with a spinner. Auto-hidden when import completes.
final class FolderImportToastView: UIView {

    // MARK: - Views

    private let blur    = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let label   = UILabel()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        // Outer shadow (on self, not blur, so it renders outside the rounded rect)
        layer.cornerRadius  = 16
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius  = 14
        layer.shadowOffset  = CGSize(width: 0, height: 4)

        // Blur card
        blur.layer.cornerRadius = 16
        blur.clipsToBounds = true
        blur.layer.borderWidth  = 0.5
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Tint overlay
        let tint = UIView()
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.10)
                : UIColor(white: 1, alpha: 0.65)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        // Spinner
        spinner.hidesWhenStopped = false
        spinner.color = DayPinDesign.accent
        spinner.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(spinner)

        // Label
        label.font = .inter(ofSize: 14, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            blur.contentView.heightAnchor.constraint(equalToConstant: 52),

            spinner.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            spinner.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -16)
        ])

        refreshBorder()
    }

    // MARK: - Border

    private func refreshBorder() {
        let dark = traitCollection.userInterfaceStyle == .dark
        blur.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.18).cgColor
            : UIColor.black.withAlphaComponent(0.12).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshBorder()
        }
    }

    // MARK: - Public API

    func show(in parentView: UIView, count: Int) {
        label.text = L10n.isRussian
            ? "Добавляем \(count) фото…"
            : "Adding \(count) photo\(count == 1 ? "" : "s")…"

        // Make sure we're in the right superview
        if superview !== parentView {
            removeFromSuperview()
            parentView.addSubview(self)
        }
        parentView.bringSubviewToFront(self)

        spinner.startAnimating()
        UIView.animate(withDuration: 0.30, delay: 0,
                       usingSpringWithDamping: 0.80, initialSpringVelocity: 0.4) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func hide() {
        UIView.animate(withDuration: 0.25) {
            self.alpha = 0
        } completion: { _ in
            self.spinner.stopAnimating()
        }
    }
}
