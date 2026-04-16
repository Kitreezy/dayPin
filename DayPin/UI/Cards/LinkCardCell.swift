import UIKit

final class LinkCardCell: UICollectionViewCell {

    static let reuseID = "LinkCardCell"

    private let cardView = GlassCardView(style: .card)
    private let linkIconView = UIView()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let commentLabel = UILabel()
    private let timeLabel = UILabel()
    private let previewImageView = UIImageView()

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

        let content = cardView.glass.contentView

        // Link icon badge
        linkIconView.backgroundColor = DayPinDesign.accentDeep.withAlphaComponent(0.14)
        linkIconView.layer.cornerRadius = 10
        linkIconView.translatesAutoresizingMaskIntoConstraints = false

        let linkIcon = UIImageView(image: UIImage(systemName: "link"))
        linkIcon.tintColor = DayPinDesign.accentDeep
        linkIcon.contentMode = .scaleAspectFit
        linkIcon.translatesAutoresizingMaskIntoConstraints = false
        linkIconView.addSubview(linkIcon)
        NSLayoutConstraint.activate([
            linkIcon.centerXAnchor.constraint(equalTo: linkIconView.centerXAnchor),
            linkIcon.centerYAnchor.constraint(equalTo: linkIconView.centerYAnchor),
            linkIcon.widthAnchor.constraint(equalToConstant: 14),
            linkIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        // Labels — compact vertical stack for 2-column grid
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        urlLabel.font = .systemFont(ofSize: 11, weight: .regular)
        urlLabel.textColor = DayPinDesign.accentDeep
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        commentLabel.font = .systemFont(ofSize: 12, weight: .regular)
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 2
        commentLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .systemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = .tertiaryLabel
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView(arrangedSubviews: [linkIconView, titleLabel, urlLabel, commentLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 5
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(mainStack)
        content.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            linkIconView.widthAnchor.constraint(equalToConstant: 32),
            linkIconView.heightAnchor.constraint(equalToConstant: 32),

            mainStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            timeLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            timeLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10)
        ])
    }

    func configure(with card: LinkCard) {
        titleLabel.text = card.previewTitle ?? card.title
        urlLabel.text = card.url.host ?? card.url.absoluteString
        commentLabel.text = card.comment.isEmpty ? nil : card.comment
        commentLabel.isHidden = card.comment.isEmpty
        cardView.setAccentColor(DayPinDesign.accentDeep)

        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        timeLabel.text = df.string(from: card.createdAt)

        if let data = card.previewImageData {
            previewImageView.image = UIImage(data: data)
        } else {
            previewImageView.image = UIImage(systemName: "photo")
            previewImageView.tintColor = .quaternaryLabel
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}
