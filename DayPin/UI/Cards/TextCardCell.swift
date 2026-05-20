import UIKit
import Lottie

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

        dateLabel.font = .inter(ofSize: 10, weight: .regular)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .inter(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 3
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        commentLabel.font = .inter(ofSize: 12, weight: .regular)
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
        df.locale = L10n.activeLocale
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

    // MARK: - Properties

    private let animationView = LottieAnimationView(name: "empty_cat", bundle: .main)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            animationView.play()
        } else {
            animationView.stop()
        }
    }

    /// Called by TodayViewController each time the cell is dequeued,
    /// including after a day switch where didMoveToWindow does not fire again.
    func startAnimating() {
        animationView.play()
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear

        // Shadow outer wrapper — no clip so shadow renders outside rounded rect
        let outer = UIView()
        outer.layer.cornerRadius  = 16
        outer.layer.shadowColor   = UIColor.black.cgColor
        outer.layer.shadowOpacity = 0.10
        outer.layer.shadowRadius  = 14
        outer.layer.shadowOffset  = CGSize(width: 0, height: 3)
        outer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: contentView.topAnchor),
            outer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            outer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // Frosted glass — same material & border as cards
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.layer.cornerRadius = 16
        blur.clipsToBounds      = true
        blur.layer.borderWidth  = 0.5
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: outer.topAnchor),
            blur.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: outer.bottomAnchor)
        ])

        // Tint overlay — NEVER set contentView.backgroundColor directly (breaks blur on iOS 17+)
        let tint = UIView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        tint.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.13)
                : UIColor(white: 1.0, alpha: 0.60)
        }
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        // Lottie animation — loops continuously while visible
        animationView.loopMode        = .loop
        animationView.contentMode     = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(animationView)

        let titleLabel = UILabel()
        titleLabel.text      = L10n.emptyDay
        titleLabel.font      = .inter(ofSize: 15, weight: .medium)
        titleLabel.textColor = .tertiaryLabel
        titleLabel.textAlignment = .center

        let hintLabel = UILabel()
        hintLabel.text      = L10n.emptyDayHint
        hintLabel.font      = .inter(ofSize: 13)
        hintLabel.textColor = .quaternaryLabel
        hintLabel.textAlignment = .center

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, hintLabel])
        labelStack.axis      = .vertical
        labelStack.spacing   = 4
        labelStack.alignment = .center
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(labelStack)

        // Animation: 280x200 native ratio - display at 126x90
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            animationView.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 20),
            animationView.widthAnchor.constraint(equalToConstant: 126),
            animationView.heightAnchor.constraint(equalToConstant: 90),

            labelStack.topAnchor.constraint(equalTo: animationView.bottomAnchor, constant: 8),
            labelStack.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            labelStack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            labelStack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -16),
            labelStack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -20)
        ])
    }
}
