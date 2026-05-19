import UIKit

final class LinkCardCell: UICollectionViewCell {

    static let reuseID = "LinkCardCell"

    // MARK: - Glass mode (no thumbnail)

    private let cardView      = GlassCardView(style: .card)
    private let linkIconBadge = UIView()
    private let linkIconImage = UIImageView(image: UIImage(systemName: "link"))
    private let titleLabel    = UILabel()
    private let urlLabel      = UILabel()
    private let commentLabel  = UILabel()
    private let glassTimeLabel = UILabel()
    private let reminderDot   = UIImageView()

    // MARK: - Thumbnail mode (previewImageData present)

    private let thumbnailView  = UIImageView()
    private let thumbGradient  = CAGradientLayer()
    private let thumbBadge     = UIView()
    private let thumbBadgeIcon = UIImageView(image: UIImage(systemName: "link"))
    private let thumbTitle     = UILabel()
    private let thumbUrl       = UILabel()
    private let thumbTime      = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 16
        DayPinDesign.applyCardShadow(to: layer)

        setupGlassMode()
        setupThumbnailMode()
    }

    private func setupGlassMode() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let content = cardView.glass.contentView

        linkIconBadge.layer.cornerRadius = 10
        linkIconBadge.translatesAutoresizingMaskIntoConstraints = false

        linkIconImage.contentMode = .scaleAspectFit
        linkIconImage.translatesAutoresizingMaskIntoConstraints = false
        linkIconBadge.addSubview(linkIconImage)
        NSLayoutConstraint.activate([
            linkIconImage.centerXAnchor.constraint(equalTo: linkIconBadge.centerXAnchor),
            linkIconImage.centerYAnchor.constraint(equalTo: linkIconBadge.centerYAnchor),
            linkIconImage.widthAnchor.constraint(equalToConstant: 14),
            linkIconImage.heightAnchor.constraint(equalToConstant: 14)
        ])

        titleLabel.font = .inter(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        urlLabel.font = .inter(ofSize: 11, weight: .regular)
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        commentLabel.font = .inter(ofSize: 12, weight: .regular)
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 2
        commentLabel.translatesAutoresizingMaskIntoConstraints = false

        glassTimeLabel.font = .inter(ofSize: 10, weight: .regular)
        glassTimeLabel.textColor = .tertiaryLabel
        glassTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView(arrangedSubviews: [linkIconBadge, titleLabel, urlLabel, commentLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 5
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let bellCfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        reminderDot.image = UIImage(systemName: "bell.fill", withConfiguration: bellCfg)
        reminderDot.contentMode = .scaleAspectFit
        reminderDot.translatesAutoresizingMaskIntoConstraints = false
        reminderDot.isHidden = true

        content.addSubview(mainStack)
        content.addSubview(glassTimeLabel)
        content.addSubview(reminderDot)

        NSLayoutConstraint.activate([
            linkIconBadge.widthAnchor.constraint(equalToConstant: 32),
            linkIconBadge.heightAnchor.constraint(equalToConstant: 32),

            mainStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            glassTimeLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            glassTimeLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),

            reminderDot.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            reminderDot.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            reminderDot.widthAnchor.constraint(equalToConstant: 12),
            reminderDot.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    private func setupThumbnailMode() {
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.backgroundColor = .secondarySystemFill
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailView)
        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        thumbGradient.colors = [
            UIColor.clear.cgColor,
            UIColor(dynamicProvider: { _ in UIColor.black }).withAlphaComponent(0.55).cgColor,
            UIColor(dynamicProvider: { _ in UIColor.black }).withAlphaComponent(0.75).cgColor
        ]
        thumbGradient.locations = [0.3, 0.7, 1.0]
        contentView.layer.addSublayer(thumbGradient)

        // Badge
        thumbBadge.backgroundColor = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.18)
        thumbBadge.layer.cornerRadius = 8
        thumbBadge.translatesAutoresizingMaskIntoConstraints = false

        thumbBadgeIcon.contentMode = .scaleAspectFit
        thumbBadgeIcon.tintColor = UIColor(dynamicProvider: { _ in UIColor.white })
        thumbBadgeIcon.translatesAutoresizingMaskIntoConstraints = false
        thumbBadge.addSubview(thumbBadgeIcon)
        NSLayoutConstraint.activate([
            thumbBadgeIcon.centerXAnchor.constraint(equalTo: thumbBadge.centerXAnchor),
            thumbBadgeIcon.centerYAnchor.constraint(equalTo: thumbBadge.centerYAnchor),
            thumbBadgeIcon.widthAnchor.constraint(equalToConstant: 12),
            thumbBadgeIcon.heightAnchor.constraint(equalToConstant: 12)
        ])

        thumbTitle.font = .inter(ofSize: 13, weight: .semibold)
        thumbTitle.textColor = UIColor(dynamicProvider: { _ in UIColor.white })
        thumbTitle.numberOfLines = 2
        thumbTitle.translatesAutoresizingMaskIntoConstraints = false

        thumbUrl.font = .inter(ofSize: 11, weight: .regular)
        thumbUrl.textColor = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.7)
        thumbUrl.translatesAutoresizingMaskIntoConstraints = false

        thumbTime.font = .inter(ofSize: 10, weight: .regular)
        thumbTime.textColor = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.55)
        thumbTime.translatesAutoresizingMaskIntoConstraints = false

        let urlRow = UIStackView(arrangedSubviews: [thumbBadge, thumbUrl, UIView(), thumbTime])
        urlRow.axis = .horizontal
        urlRow.spacing = 5
        urlRow.alignment = .center
        urlRow.translatesAutoresizingMaskIntoConstraints = false

        let bottomStack = UIStackView(arrangedSubviews: [thumbTitle, urlRow])
        bottomStack.axis = .vertical
        bottomStack.spacing = 4
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bottomStack)

        NSLayoutConstraint.activate([
            thumbBadge.widthAnchor.constraint(equalToConstant: 22),
            thumbBadge.heightAnchor.constraint(equalToConstant: 22),

            bottomStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bottomStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bottomStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        thumbnailView.isHidden = true
        bottomStack.isHidden   = true

        // Store reference to toggle
        thumbnailContentStack = bottomStack
    }

    private var thumbnailContentStack: UIStackView?

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        thumbGradient.frame  = contentView.bounds
        layer.masksToBounds  = thumbnailView.isHidden ? false : true
        layer.shadowPath     = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
    }

    // MARK: - Configure

    func configure(with card: LinkCard) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.locale = L10n.activeLocale
        let timeStr = df.string(from: card.createdAt)

        let tint = card.colorHex.flatMap { UIColor(hex: $0) } ?? DayPinDesign.linkCardTint
        let hasThumb = card.previewImageData != nil
        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        reminderDot.isHidden = hasThumb || !hasReminder   // only show in glass mode
        reminderDot.tintColor = tint

        if hasThumb, let data = card.previewImageData, let image = UIImage(data: data) {
            // Thumbnail mode
            thumbnailView.image     = image
            thumbnailView.isHidden  = false
            thumbnailContentStack?.isHidden = false
            cardView.isHidden       = true

            thumbTitle.text = card.previewTitle ?? card.title
            thumbUrl.text   = card.url.host ?? card.url.absoluteString
            thumbTime.text  = timeStr
        } else {
            // Glass mode
            thumbnailView.isHidden  = true
            thumbnailContentStack?.isHidden = true
            cardView.isHidden       = false

            titleLabel.text   = card.previewTitle ?? card.title
            urlLabel.text     = card.url.host ?? card.url.absoluteString
            urlLabel.textColor = tint
            commentLabel.text = card.comment.isEmpty ? nil : card.comment
            commentLabel.isHidden = card.comment.isEmpty
            glassTimeLabel.text = timeStr

            linkIconImage.tintColor         = tint
            linkIconBadge.backgroundColor   = tint.withAlphaComponent(0.12)
            cardView.setAccentColor(tint)
        }

        setNeedsLayout()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}
