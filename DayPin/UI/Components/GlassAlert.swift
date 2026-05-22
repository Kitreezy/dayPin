import UIKit

// MARK: - GlassAlert
// Centered confirmation dialog matching the app's glass design language.
//
// Usage:
//   GlassAlert.confirm(in: self, title: "Delete", destructive: "Delete") { ... }
//   GlassAlert.show(in: self, title: "Done", message: "Backup restored.")

final class GlassAlert: UIView {

    // MARK: - Entry points

    /// Two-button dialog: Cancel + a confirm action (destructive or accent-colored).
    static func confirm(
        in vc: UIViewController,
        title: String,
        message: String? = nil,
        cancelTitle: String = L10n.cancel,
        confirmTitle: String,
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) {
        guard let window = vc.view.window else { return }
        let alert = GlassAlert(
            title: title, message: message,
            cancelTitle: cancelTitle,
            confirmTitle: confirmTitle,
            isDestructive: isDestructive,
            onConfirm: onConfirm
        )
        alert.frame = window.bounds
        alert.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(alert)
        alert.animateIn()
    }

    /// Single-button informational alert.
    static func show(
        in vc: UIViewController,
        title: String,
        message: String? = nil,
        buttonTitle: String = "OK"
    ) {
        guard let window = vc.view.window else { return }
        let alert = GlassAlert(
            title: title, message: message,
            cancelTitle: nil,
            confirmTitle: buttonTitle,
            isDestructive: false,
            onConfirm: {}
        )
        alert.frame = window.bounds
        alert.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(alert)
        alert.animateIn()
    }

    // MARK: - Private state

    private let alertTitle: String
    private let alertMessage: String?
    private let cancelTitle: String?
    private let confirmTitle: String
    private let isDestructive: Bool
    private let onConfirm: () -> Void

    private let dimView = UIView()
    private let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

    private static let cardWidth: CGFloat = 270

    private init(
        title: String,
        message: String?,
        cancelTitle: String?,
        confirmTitle: String,
        isDestructive: Bool,
        onConfirm: @escaping () -> Void
    ) {
        self.alertTitle = title
        self.alertMessage = message
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        // Dim
        dimView.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.50)
                : UIColor.black.withAlphaComponent(0.35)
        }
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        // Tap outside = cancel
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))

        // Card
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        card.clipsToBounds = true
        card.alpha = 0
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: Self.cardWidth)
        ])

        buildCardContent()
    }

    private func buildCardContent() {
        let cv = card.contentView

        // Title
        let titleLabel = UILabel()
        titleLabel.text = alertTitle
        titleLabel.font = .inter(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(titleLabel)

        var lastAnchor = cv.topAnchor
        var lastConstant: CGFloat = 18

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: lastAnchor, constant: lastConstant),
            titleLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16)
        ])
        lastAnchor = titleLabel.bottomAnchor
        lastConstant = 6

        // Message (optional)
        if let message = alertMessage {
            let msgLabel = UILabel()
            msgLabel.text = message
            msgLabel.font = .inter(ofSize: 13)
            msgLabel.textColor = .secondaryLabel
            msgLabel.textAlignment = .center
            msgLabel.numberOfLines = 0
            msgLabel.translatesAutoresizingMaskIntoConstraints = false
            cv.addSubview(msgLabel)
            NSLayoutConstraint.activate([
                msgLabel.topAnchor.constraint(equalTo: lastAnchor, constant: lastConstant),
                msgLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
                msgLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16)
            ])
            lastAnchor = msgLabel.bottomAnchor
            lastConstant = 16
        } else {
            lastConstant = 16
        }

        // Separator above buttons
        let sep = makeSeparator()
        cv.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: lastAnchor, constant: lastConstant),
            sep.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
        ])

        // Buttons row
        let buttonRow = buildButtonRow()
        cv.addSubview(buttonRow)
        NSLayoutConstraint.activate([
            buttonRow.topAnchor.constraint(equalTo: sep.bottomAnchor),
            buttonRow.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            buttonRow.heightAnchor.constraint(equalToConstant: 44),
            buttonRow.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
        ])
    }

    private func buildButtonRow() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        if let cancelTitle {
            // Two buttons with vertical separator
            let cancelBtn = makeButton(title: cancelTitle, isDestructive: false, isBold: false)
            cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

            let confirmBtn = makeButton(title: confirmTitle, isDestructive: isDestructive, isBold: true)
            confirmBtn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

            let vSep = makeSeparator(vertical: true)

            container.addSubview(cancelBtn)
            container.addSubview(vSep)
            container.addSubview(confirmBtn)
            NSLayoutConstraint.activate([
                cancelBtn.topAnchor.constraint(equalTo: container.topAnchor),
                cancelBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                cancelBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                vSep.topAnchor.constraint(equalTo: container.topAnchor),
                vSep.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                vSep.centerXAnchor.constraint(equalTo: container.centerXAnchor),

                confirmBtn.topAnchor.constraint(equalTo: container.topAnchor),
                confirmBtn.leadingAnchor.constraint(equalTo: vSep.trailingAnchor),
                confirmBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                confirmBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                cancelBtn.widthAnchor.constraint(equalTo: confirmBtn.widthAnchor)
            ])
        } else {
            // Single centered button
            let btn = makeButton(title: confirmTitle, isDestructive: false, isBold: true)
            btn.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
            container.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: container.topAnchor),
                btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                btn.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
        return container
    }

    private func makeButton(title: String, isDestructive: Bool, isBold: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        let color: UIColor = isDestructive ? .systemRed : DayPinDesign.accent
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .inter(ofSize: 15, weight: isBold ? .semibold : .regular)
        btn.setTitleColor(color, for: .normal)
        btn.setTitleColor(color.withAlphaComponent(0.4), for: .highlighted)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private func makeSeparator(vertical: Bool = false) -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        v.translatesAutoresizingMaskIntoConstraints = false
        if vertical {
            v.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        } else {
            v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        }
        return v
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        animateOut { [weak self] in self?.onConfirm() }
    }

    @objc private func cancelTapped() {
        animateOut(completion: nil)
    }

    // MARK: - Animation

    private func animateIn() {
        card.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        UIView.animate(withDuration: 0.38, delay: 0,
                       usingSpringWithDamping: 0.70, initialSpringVelocity: 0.2) {
            self.dimView.alpha = 1
            self.card.alpha = 1
            self.card.transform = .identity
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func animateOut(completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}
