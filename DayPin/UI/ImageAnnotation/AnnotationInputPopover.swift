import UIKit

// MARK: - AnnotationInputPopover

/// Glass popover for entering/editing annotation text.
/// Appears near the pin location (auto-positioned to stay on screen).
final class AnnotationInputPopover: UIView {

    // MARK: Public

    var onSave: ((String) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: Private

    private let existingText: String?
    private let pinWindowPoint: CGPoint

    private let dimView = UIView()
    private let card = GlassView(style: .card)
    private let textView = UITextView()
    private let placeholder = UILabel()
    private let titleLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let pinIndicator = UIView()

    private var cardCenterYConstraint: NSLayoutConstraint!

    // MARK: Init

    private init(pinWindowPoint: CGPoint, existingText: String?) {
        self.pinWindowPoint = pinWindowPoint
        self.existingText = existingText
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Static entry

    static func show(
        pinWindowPoint: CGPoint,
        existingText: String? = nil,
        onSave: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return }

        let popover = AnnotationInputPopover(pinWindowPoint: pinWindowPoint, existingText: existingText)
        popover.onSave = onSave
        popover.onCancel = onCancel
        popover.frame = window.bounds
        popover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(popover)
        popover.animateIn()
    }

    // MARK: Setup

    private func setup() {
        // Keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Dim
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelTapped)))

        // Pin indicator dot
        pinIndicator.backgroundColor = DayPinDesign.accent
        pinIndicator.layer.cornerRadius = 6
        pinIndicator.layer.shadowColor = DayPinDesign.accent.cgColor
        pinIndicator.layer.shadowOpacity = 0.6
        pinIndicator.layer.shadowRadius = 8
        pinIndicator.layer.shadowOffset = .zero
        pinIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pinIndicator)
        NSLayoutConstraint.activate([
            pinIndicator.centerXAnchor.constraint(equalTo: leadingAnchor, constant: pinWindowPoint.x),
            pinIndicator.centerYAnchor.constraint(equalTo: topAnchor, constant: pinWindowPoint.y),
            pinIndicator.widthAnchor.constraint(equalToConstant: 12),
            pinIndicator.heightAnchor.constraint(equalToConstant: 12)
        ])

        // Card
        card.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        // Position card: above pin if in lower half, below if upper half
        let isLowerHalf = pinWindowPoint.y > UIScreen.main.bounds.height * 0.55
        let targetY = isLowerHalf
            ? pinWindowPoint.y - 20   // card bottom near pin
            : pinWindowPoint.y + 20   // card top near pin

        cardCenterYConstraint = card.centerYAnchor.constraint(equalTo: topAnchor, constant: targetY)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            cardCenterYConstraint
        ])

        buildCardContent()
    }

    private func buildCardContent() {
        let content = card.contentView

        // Title
        titleLabel.text = existingText == nil ? L10n.addAnnotation : L10n.editAnnotationTitle
        titleLabel.font = .inter(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleLabel)

        let separator = UIView()
        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.6)
        separator.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(separator)

        // Text view
        textView.font = .inter(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.text = existingText ?? ""
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(textView)

        // Placeholder
        placeholder.text = L10n.commentOptionalPlaceholder
        placeholder.font = .inter(ofSize: 16)
        placeholder.textColor = .placeholderText
        placeholder.isHidden = !(existingText?.isEmpty ?? true)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(placeholder)

        // Buttons
        cancelButton.setTitle(L10n.cancel, for: .normal)
        cancelButton.titleLabel?.font = .inter(ofSize: 15, weight: .medium)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        saveButton.setTitle(L10n.save, for: .normal)
        saveButton.titleLabel?.font = .inter(ofSize: 15, weight: .semibold)
        saveButton.setTitleColor(DayPinDesign.accent, for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = UIStackView(arrangedSubviews: [cancelButton, saveButton])
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttonRow)

        let btnSeparator = UIView()
        btnSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.6)
        btnSeparator.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(btnSeparator)

        let btnMidSeparator = UIView()
        btnMidSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.6)
        btnMidSeparator.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(btnMidSeparator)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),

            separator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            textView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            textView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            placeholder.topAnchor.constraint(equalTo: textView.topAnchor, constant: 4),
            placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 5),

            btnSeparator.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 12),
            btnSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            btnSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            btnSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            buttonRow.topAnchor.constraint(equalTo: btnSeparator.bottomAnchor),
            buttonRow.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            buttonRow.heightAnchor.constraint(equalToConstant: 50),
            buttonRow.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            btnMidSeparator.topAnchor.constraint(equalTo: btnSeparator.bottomAnchor),
            btnMidSeparator.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            btnMidSeparator.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            btnMidSeparator.widthAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: Animation

    private func animateIn() {
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        pinIndicator.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.5) {
            self.dimView.alpha = 1
            self.card.alpha = 1
            self.card.transform = .identity
            self.pinIndicator.transform = .identity
        } completion: { _ in
            self.textView.becomeFirstResponder()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func animateOut(completion: (() -> Void)? = nil) {
        textView.resignFirstResponder()
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.pinIndicator.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    // MARK: Actions

    @objc private func saveTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        animateOut { [weak self] in
            self?.onSave?(text)
        }
    }

    @objc private func cancelTapped() {
        animateOut { [weak self] in
            self?.onCancel?()
        }
    }

    // MARK: Keyboard

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        let keyboardTop = frame.minY
        let cardBottom = cardCenterYConstraint.constant + 160
        if cardBottom > keyboardTop - 20 {
            let shift = cardBottom - (keyboardTop - 20)
            UIView.animate(withDuration: duration) {
                self.cardCenterYConstraint.constant -= shift
                self.layoutIfNeeded()
            }
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        UIView.animate(withDuration: duration) {
            self.layoutIfNeeded()
        }
    }
}

// MARK: - UITextViewDelegate

extension AnnotationInputPopover: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
    }
}
