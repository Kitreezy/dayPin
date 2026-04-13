import UIKit

final class ImageCardCell: UICollectionViewCell {

    static let reuseID = "ImageCardCell"

    private let thumbnailView = UIImageView()
    private let titleLabel = UILabel()
    private let pinCountLabel = UILabel()
    private let pinIcon = UIImageView()
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 18
        layer.masksToBounds = true

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 4)

        // Image
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.backgroundColor = .secondarySystemFill
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailView)

        // Gradient overlay
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
        gradientLayer.locations = [0.45, 1.0]
        contentView.layer.addSublayer(gradientLayer)

        // Bottom info
        let blurOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blurOverlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(blurOverlay)

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        pinIcon.image = UIImage(systemName: "mappin.circle.fill")
        pinIcon.tintColor = UIColor.white.withAlphaComponent(0.7)
        pinIcon.contentMode = .scaleAspectFit
        pinIcon.translatesAutoresizingMaskIntoConstraints = false

        pinCountLabel.font = .systemFont(ofSize: 12, weight: .medium)
        pinCountLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        pinCountLabel.translatesAutoresizingMaskIntoConstraints = false

        let pinRow = UIStackView(arrangedSubviews: [pinIcon, pinCountLabel])
        pinRow.axis = .horizontal
        pinRow.spacing = 4
        pinRow.alignment = .center
        pinRow.translatesAutoresizingMaskIntoConstraints = false

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, pinRow])
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        blurOverlay.contentView.addSubview(infoStack)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailView.heightAnchor.constraint(equalTo: thumbnailView.widthAnchor, multiplier: 0.65),
            thumbnailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            blurOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blurOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blurOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            infoStack.topAnchor.constraint(equalTo: blurOverlay.contentView.topAnchor, constant: 12),
            infoStack.leadingAnchor.constraint(equalTo: blurOverlay.contentView.leadingAnchor, constant: 14),
            infoStack.trailingAnchor.constraint(equalTo: blurOverlay.contentView.trailingAnchor, constant: -14),
            infoStack.bottomAnchor.constraint(equalTo: blurOverlay.contentView.bottomAnchor, constant: -12),

            pinIcon.widthAnchor.constraint(equalToConstant: 14),
            pinIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
        // Ensure corner radius applies correctly after layout
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18).cgPath
    }

    func configure(with card: ImageCard) {
        titleLabel.text = card.title
        thumbnailView.image = card.imageData.flatMap { UIImage(data: $0) }

        let count = card.annotations.count
        pinCountLabel.text = count > 0 ? L10n.annotationCount(count) : L10n.noAnnotations
        pinIcon.tintColor = count > 0 ? .systemBlue : UIColor.white.withAlphaComponent(0.4)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}
