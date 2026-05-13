import UIKit

final class TextCardCell: UICollectionViewCell {

    static let reuseID = "TextCardCell"

    private let cardView = GlassCardView(style: .card)
    private let typeIcon = UIImageView()
    private let titleLabel = UILabel()
    private let commentLabel = UILabel()
    private let dateLabel = UILabel()
    private let reminderDot = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 16
        DayPinDesign.applyCardShadow(to: layer)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let cv = cardView.glass.contentView

        typeIcon.image = UIImage(systemName: "text.alignleft")
        typeIcon.tintColor = DayPinDesign.accent
        typeIcon.contentMode = .scaleAspectFit
        typeIcon.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = .systemFont(ofSize: 10, weight: .regular)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 3
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        commentLabel.font = .systemFont(ofSize: 12, weight: .regular)
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 4
        commentLabel.translatesAutoresizingMaskIntoConstraints = false

        // Small bell badge for reminders
        let bellCfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        reminderDot.image = UIImage(systemName: "bell.fill", withConfiguration: bellCfg)
        reminderDot.tintColor = DayPinDesign.accent
        reminderDot.contentMode = .scaleAspectFit
        reminderDot.translatesAutoresizingMaskIntoConstraints = false
        reminderDot.isHidden = true

        let topRow = UIStackView(arrangedSubviews: [typeIcon, UIView(), reminderDot, dateLabel])
        topRow.axis = .horizontal
        topRow.spacing = 4
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [topRow, titleLabel, commentLabel])
        stack.axis = .vertical
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cv.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: cv.bottomAnchor, constant: -12),

            typeIcon.widthAnchor.constraint(equalToConstant: 14),
            typeIcon.heightAnchor.constraint(equalToConstant: 14),
            reminderDot.widthAnchor.constraint(equalToConstant: 12),
            reminderDot.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    func configure(with card: TextCard) {
        titleLabel.text = card.title
        commentLabel.text = card.comment.isEmpty ? nil : card.comment
        commentLabel.isHidden = card.comment.isEmpty

        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        dateLabel.text = df.string(from: card.createdAt)

        let tint = card.colorHex.flatMap { UIColor(hex: $0) } ?? DayPinDesign.textCardTint
        typeIcon.image = UIImage(systemName: "text.alignleft")
        typeIcon.tintColor = tint
        cardView.setAccentColor(tint)

        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        reminderDot.isHidden = !hasReminder
        reminderDot.tintColor = tint
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

// MARK: - EmptyCardCell

final class EmptyCardCell: UICollectionViewCell {

    static let reuseID = "EmptyCardCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear

        let card = GlassCardView(style: .card)
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let icon = UIImageView(image: UIImage(systemName: "note.text"))
        icon.tintColor = .quaternaryLabel
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = L10n.emptyDay
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .tertiaryLabel
        titleLabel.textAlignment = .center

        let hintLabel = UILabel()
        hintLabel.text = L10n.emptyDayHint
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .quaternaryLabel
        hintLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, hintLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.glass.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: card.glass.contentView.centerXAnchor),
            stack.topAnchor.constraint(equalTo: card.glass.contentView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.glass.contentView.bottomAnchor, constant: -28),
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
}
