import UIKit

final class ImageCardCell: UICollectionViewCell {

    // MARK: - Properties

    static let reuseID = "ImageCardCell"

    private let thumbnailView = UIImageView()
    private let titleLabel    = UILabel()
    private let pinCountLabel = UILabel()
    private let pinIcon       = UIImageView()
    private let timeLabel     = UILabel()
    private let gradientLayer = CAGradientLayer()
    private let reminderDot   = UIImageView()

    // Glass panel: plain UIView - semi-transparent so the photo shows through.
    // UIVisualEffectView doesn't blur sibling views in collection cells reliably.
    private let glassPanel = UIView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Notifications

    @objc private func onSchemeChanged() {
        refreshTint(DayPinDesign.imageCardTint)
    }

    // MARK: - UI Setup

    private func refreshTint(_ tint: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        tint.getRed(&r, green: &g, blue: &b, alpha: nil)
        // Black base (alpha 0.52) lightly tinted — image shows through the 48% transparency
        glassPanel.backgroundColor = UIColor(red: r * 0.18, green: g * 0.18, blue: b * 0.18, alpha: 0.52)
    }

    private func setup() {
        backgroundColor = .clear
        // No masksToBounds on the cell — thumbnail clips itself
        layer.cornerRadius = 18
        DayPinDesign.applyCardShadow(to: layer)

        // ── Photo ──────────────────────────────────────────────
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.14, alpha: 1)
                : UIColor(white: 0.88, alpha: 1)
        }
        thumbnailView.layer.cornerRadius = 18
        thumbnailView.layer.masksToBounds = true
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailView)

        // ── Vignette gradient ──────────────────────────────────
        gradientLayer.colors = [UIColor.clear.cgColor,
                                UIColor(dynamicProvider: { _ in UIColor.black }).withAlphaComponent(0.60).cgColor]
        gradientLayer.locations = [0.28, 1.0]
        gradientLayer.cornerRadius = 18
        contentView.layer.addSublayer(gradientLayer)

        // ── Floating glass panel ───────────────────────────────
        glassPanel.layer.cornerRadius = 14
        glassPanel.layer.borderWidth  = 0.5
        glassPanel.layer.borderColor  = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.18).cgColor
        glassPanel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(glassPanel)
        refreshTint(DayPinDesign.imageCardTint)


        // ── Labels ─────────────────────────────────────────────
        titleLabel.font = .inter(ofSize: 15, weight: .semibold)
        titleLabel.textColor = UIColor(dynamicProvider: { _ in UIColor.white })
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        pinIcon.image = UIImage(systemName: "mappin.circle.fill")
        pinIcon.tintColor = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.75)
        pinIcon.contentMode = .scaleAspectFit
        pinIcon.translatesAutoresizingMaskIntoConstraints = false

        pinCountLabel.font = .inter(ofSize: 12, weight: .medium)
        pinCountLabel.textColor = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.90)
        pinCountLabel.translatesAutoresizingMaskIntoConstraints = false

        let pinRow = UIStackView(arrangedSubviews: [pinIcon, pinCountLabel])
        pinRow.axis = .horizontal
        pinRow.spacing = 4
        pinRow.alignment = .center
        pinRow.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .inter(ofSize: 11, weight: .regular)
        timeLabel.textColor = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.55)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let bottomRow = UIStackView(arrangedSubviews: [pinRow, UIView(), timeLabel])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.spacing = 6
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, bottomRow])
        infoStack.axis = .vertical
        infoStack.spacing = 5
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        glassPanel.addSubview(infoStack)

        let ratioConstraint = thumbnailView.heightAnchor.constraint(
            equalTo: thumbnailView.widthAnchor, multiplier: 0.65)
        ratioConstraint.priority = UILayoutPriority(999)

        setupReminderDot()

        NSLayoutConstraint.activate([
            // Photo
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ratioConstraint,
            thumbnailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Glass panel — 8pt inset from sides, 8pt from bottom
            glassPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            glassPanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            glassPanel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            // Info stack
            infoStack.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: 10),
            infoStack.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: 12),
            infoStack.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -12),
            infoStack.bottomAnchor.constraint(equalTo: glassPanel.bottomAnchor, constant: -10),

            pinIcon.widthAnchor.constraint(equalToConstant: 14),
            pinIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func setupReminderDot() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        reminderDot.image = UIImage(systemName: "bell.fill", withConfiguration: cfg)
        reminderDot.tintColor = UIColor(dynamicProvider: { _ in UIColor.white })
        reminderDot.contentMode = .scaleAspectFit
        reminderDot.translatesAutoresizingMaskIntoConstraints = false
        reminderDot.isHidden = true
        contentView.addSubview(reminderDot)
        NSLayoutConstraint.activate([
            reminderDot.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            reminderDot.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            reminderDot.widthAnchor.constraint(equalToConstant: 14),
            reminderDot.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
    }

    // MARK: - Configuration

    func configure(with card: ImageCard) {
        titleLabel.text = card.title
        thumbnailView.image = card.imageData.flatMap { UIImage(data: $0) }

        let count = card.annotations.count
        let tint = card.colorHex.flatMap { UIColor(hex: $0) } ?? DayPinDesign.imageCardTint
        pinIcon.tintColor = count > 0 ? tint : UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.4)
        refreshTint(tint)

        if count == 0 {
            pinCountLabel.text = L10n.noAnnotations
        } else {
            // Title is the primary field — always prefer it over the optional comment
            let first = card.annotations.first(where: { !$0.title.isEmpty })?.title
                     ?? card.annotations.first(where: { !$0.text.isEmpty })?.text
            if let label = first {
                let preview = label.count > 28 ? String(label.prefix(28)) + "…" : label
                pinCountLabel.text = count > 1 ? "\(preview)  +\(count - 1)" : preview
            } else {
                pinCountLabel.text = L10n.annotationCount(count)
            }
        }

        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.locale = L10n.activeLocale
        timeLabel.text = df.string(from: card.createdAt)

        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        reminderDot.isHidden = !hasReminder
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}
