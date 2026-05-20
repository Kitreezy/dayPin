import UIKit

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

final class GlassCardView: UIView {

    let glass: GlassView
    let stackView = UIStackView()

    var cornerRadius: CGFloat = 16 {
        didSet {
            layer.cornerRadius = cornerRadius
            glass.cornerRadius = cornerRadius
            glass.layer.cornerRadius = cornerRadius
        }
    }

    init(style: GlassView.Style = .card) {
        glass = GlassView(style: style)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        glass.layer.borderColor = DayPinDesign.cardBorderColor.cgColor
        glass.layer.borderWidth = DayPinDesign.cardBorderWidth(for: traitCollection)
        DayPinDesign.applyCardShadow(to: layer, for: traitCollection)
    }

    /// Adds a tinted overlay; tag 9001 ensures only one overlay exists at a time.
    func setAccentColor(_ color: UIColor) {
        glass.contentView.viewWithTag(9001)?.removeFromSuperview()
        let overlay = UIView()
        overlay.tag = 9001
        overlay.backgroundColor = color.withAlphaComponent(0.13)
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.insertSubview(overlay, at: 0)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor)
        ])
    }

    private func setup() {
        DayPinDesign.applyCardShadow(to: layer, for: traitCollection)
        layer.cornerRadius = 16
        backgroundColor = .clear

        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.layer.borderColor = DayPinDesign.cardBorderColor.cgColor
        glass.layer.borderWidth = DayPinDesign.cardBorderWidth(for: traitCollection)
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
