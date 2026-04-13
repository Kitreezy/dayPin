import UIKit

final class TextCardCell: UICollectionViewCell {

    static let reuseID = "TextCardCell"

    private let cardView = GlassCardView(style: .card)
    private let typeIcon = UIImageView()
    private let titleLabel = UILabel()
    private let commentLabel = UILabel()
    private let dateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 16

        // Shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 3)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        typeIcon.image = UIImage(systemName: "text.alignleft")
        typeIcon.tintColor = .tertiaryLabel
        typeIcon.contentMode = .scaleAspectFit
        typeIcon.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = .systemFont(ofSize: 11, weight: .regular)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [typeIcon, dateLabel, UIView()])
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 3
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        commentLabel.font = .systemFont(ofSize: 14, weight: .regular)
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 3
        commentLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [topRow, titleLabel, commentLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.glass.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.glass.contentView.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: cardView.glass.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cardView.glass.contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: cardView.glass.contentView.bottomAnchor, constant: -14),

            typeIcon.widthAnchor.constraint(equalToConstant: 14),
            typeIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    func configure(with card: TextCard) {
        titleLabel.text = card.title
        commentLabel.text = card.comment.isEmpty ? nil : card.comment
        commentLabel.isHidden = card.comment.isEmpty

        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        dateLabel.text = df.string(from: card.createdAt)
        typeIcon.image = UIImage(systemName: "text.alignleft")
        typeIcon.tintColor = .tertiaryLabel
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
