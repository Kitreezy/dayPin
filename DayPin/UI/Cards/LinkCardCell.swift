import UIKit

final class LinkCardCell: UICollectionViewCell {

    static let reuseID = "LinkCardCell"

    private let cardView = GlassCardView(style: .card)
    private let linkIconView = UIView()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let commentLabel = UILabel()
    private let previewImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 16
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

        let content = cardView.glass.contentView

        // Link icon badge
        linkIconView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        linkIconView.layer.cornerRadius = 10
        linkIconView.translatesAutoresizingMaskIntoConstraints = false

        let linkIcon = UIImageView(image: UIImage(systemName: "link"))
        linkIcon.tintColor = .systemBlue
        linkIcon.contentMode = .scaleAspectFit
        linkIcon.translatesAutoresizingMaskIntoConstraints = false
        linkIconView.addSubview(linkIcon)
        NSLayoutConstraint.activate([
            linkIcon.centerXAnchor.constraint(equalTo: linkIconView.centerXAnchor),
            linkIcon.centerYAnchor.constraint(equalTo: linkIconView.centerYAnchor),
            linkIcon.widthAnchor.constraint(equalToConstant: 14),
            linkIcon.heightAnchor.constraint(equalToConstant: 14)
        ])

        // Preview image
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.clipsToBounds = true
        previewImageView.layer.cornerRadius = 10
        previewImageView.backgroundColor = .tertiarySystemFill
        previewImageView.translatesAutoresizingMaskIntoConstraints = false

        // Labels
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        urlLabel.font = .systemFont(ofSize: 12, weight: .regular)
        urlLabel.textColor = .systemBlue
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        commentLabel.font = .systemFont(ofSize: 13, weight: .regular)
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 2
        commentLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, urlLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(linkIconView)
        content.addSubview(previewImageView)
        content.addSubview(textStack)
        content.addSubview(commentLabel)

        NSLayoutConstraint.activate([
            linkIconView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            linkIconView.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            linkIconView.widthAnchor.constraint(equalToConstant: 32),
            linkIconView.heightAnchor.constraint(equalToConstant: 32),

            previewImageView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            previewImageView.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            previewImageView.widthAnchor.constraint(equalToConstant: 56),
            previewImageView.heightAnchor.constraint(equalToConstant: 56),

            textStack.leadingAnchor.constraint(equalTo: linkIconView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: previewImageView.leadingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: previewImageView.centerYAnchor),

            commentLabel.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 10),
            commentLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            commentLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            commentLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14)
        ])
    }

    func configure(with card: LinkCard) {
        titleLabel.text = card.previewTitle ?? card.title
        urlLabel.text = card.url.host ?? card.url.absoluteString
        commentLabel.text = card.comment.isEmpty ? nil : card.comment
        commentLabel.isHidden = card.comment.isEmpty

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
