import UIKit

/// Telegram-style frosted glass container
final class GlassView: UIView {

    enum Style {
        case light
        case dark
        case thinLight
        case thinDark
        case card

        var blurStyle: UIBlurEffect.Style {
            switch self {
            case .light:     return .systemMaterial
            case .dark:      return .systemMaterialDark
            case .thinLight: return .systemUltraThinMaterial
            case .thinDark:  return .systemUltraThinMaterialDark
            case .card:      return .systemThickMaterial
            }
        }
    }

    private let blurView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    let contentView: UIView

    var cornerRadius: CGFloat = 16 {
        didSet {
            layer.cornerRadius = cornerRadius
            blurView.layer.cornerRadius = cornerRadius
        }
    }

    // MARK: Init

    init(style: Style = .thinLight) {
        let blur = UIBlurEffect(style: style.blurStyle)
        blurView = UIVisualEffectView(effect: blur)
        vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blur))
        contentView = UIView()

        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true

        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
        ])
    }
}

// MARK: - GlassCardView

/// Card with shadow + glass effect — used for NoteCard cells
final class GlassCardView: UIView {

    let glass: GlassView
    let stackView = UIStackView()

    init(style: GlassView.Style = .card) {
        glass = GlassView(style: style)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 12
        layer.cornerRadius = 16
        backgroundColor = .clear

        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: glass.contentView.topAnchor, constant: 14),
            stackView.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor, constant: -14)
        ])
    }
}
