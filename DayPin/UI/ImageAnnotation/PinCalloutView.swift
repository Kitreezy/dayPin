import UIKit

// MARK: - PinCalloutView
//
// Callout that grows from the pin.
// View mode  → text shown; edit / clear as floating circle buttons above card
// Edit mode  → title + text fields; ✓ / ✕ as floating circles; keyboard-aware
//
// The target pin view can be passed so it fades out while callout is visible.

final class PinCalloutView: UIView {

    // MARK: - Public entry

    static func show(
        pinWindowPoint: CGPoint,
        title: String,
        text: String,
        colorHex: String = "#007AFF",
        startInEditMode: Bool = false,
        sourcePinView: UIView? = nil,
        onEdit: @escaping (String, String, String) -> Void,   // title, text, colorHex
        onDelete: (() -> Void)? = nil
    ) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: \.isKeyWindow) else { return }

        window.subviews.compactMap { $0 as? PinCalloutView }.forEach { $0.dismissSelf() }

        let c = PinCalloutView(
            pin: pinWindowPoint, title: title, text: text,
            colorHex: colorHex,
            startInEdit: startInEditMode,
            sourcePinView: sourcePinView,
            onEdit: onEdit, onDelete: onDelete
        )
        c.frame = window.bounds
        c.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(c)
        c.animateIn()
    }

    // MARK: - Private storage

    private let pinPoint: CGPoint
    private let storedTitle: String
    private let storedText: String
    private var selectedColorHex: String
    private let startInEdit: Bool
    private weak var sourcePinView: UIView?
    private let editCallback: (String, String, String) -> Void
    private let deleteCallback: (() -> Void)?

    private static let pinColors: [(String, String)] = [
        ("Синий",    "#007AFF"),
        ("Красный",  "#FF3B30"),
        ("Зелёный",  "#34C759"),
        ("Оранж.",   "#FF9500"),
        ("Фиолет.",  "#AF52DE"),
        ("Жёлтый",   "#FFCC00"),
        ("Белый",    "#FFFFFF")
    ]

    private init(
        pin: CGPoint, title: String, text: String,
        colorHex: String,
        startInEdit: Bool,
        sourcePinView: UIView?,
        onEdit: @escaping (String, String, String) -> Void, onDelete: (() -> Void)?
    ) {
        pinPoint = pin
        storedTitle = title
        storedText = text
        selectedColorHex = colorHex
        self.startInEdit = startInEdit
        self.sourcePinView = sourcePinView
        editCallback = onEdit
        deleteCallback = onDelete
        super.init(frame: .zero)
        buildUI()
        observeKeyboard()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Geometry

    private let cardWidth: CGFloat = min(240, UIScreen.main.bounds.width - 32)
    private var viewHeight: CGFloat { storedTitle.isEmpty ? 80 : 104 }
    private let editHeight: CGFloat = 232   // extra row for color picker

    private var cardAbovePin: Bool {
        pinPoint.y > UIScreen.main.bounds.height * 0.45
    }

    private var cardOriginX: CGFloat {
        max(12, min(UIScreen.main.bounds.width - cardWidth - 12, pinPoint.x - cardWidth / 2))
    }

    private func cardOriginY(height: CGFloat, keyboardTop: CGFloat? = nil) -> CGFloat {
        let screen = UIScreen.main.bounds.height
        let safeBottom = keyboardTop ?? screen

        if cardAbovePin {
            // Prefer above pin, but also must be above keyboard
            let abovePin = pinPoint.y - height - 14
            let aboveKbd = safeBottom - height - 12
            return min(abovePin, aboveKbd)
        } else {
            let preferred = pinPoint.y + 14
            let maxY = safeBottom - height - 12
            return min(preferred, maxY)
        }
    }

    // MARK: - UI

    private let dimView = UIView()
    private let cardShadow = UIView()
    private let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    // Two floating buttons — same positions, icons swap per mode:
    // view mode:  left = edit (pencil),     right = delete (trash)
    // edit mode:  left = save (checkmark),  right = cancel (xmark)
    private let leftBtn = CircleActionButton()
    private let rightBtn = CircleActionButton()

    // View mode
    private let viewContentView = UIView()
    private let titleDisplayLabel = UILabel()
    private let textLabel = UILabel()

    // Edit mode
    private let editContentView = UIView()
    private let titleField = UITextField()
    private let textView = UITextView()

    private var keyboardTop: CGFloat? = nil

    private func buildUI() {
        // Dim overlay
        dimView.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.20)
                : UIColor.black.withAlphaComponent(0.12)
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
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))

        // Card - outer shadow wrapper + inner blur (iOS 17+ glass pattern)
        let h = startInEdit ? editHeight : viewHeight
        cardShadow.layer.cornerRadius = 14
        cardShadow.layer.shadowColor = UIColor.black.cgColor
        cardShadow.layer.shadowOpacity = 0.3
        cardShadow.layer.shadowRadius = 16
        cardShadow.layer.shadowOffset = CGSize(width: 0, height: 5)
        cardShadow.frame = CGRect(x: cardOriginX, y: cardOriginY(height: h), width: cardWidth, height: h)
        addSubview(cardShadow)
        card.layer.cornerRadius = 14
        card.clipsToBounds = true
        card.frame = cardShadow.bounds
        card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cardShadow.addSubview(card)

        buildViewContent()
        buildEditContent()
        buildFloatingButtons()
        viewContentView.isHidden = startInEdit
        editContentView.isHidden = !startInEdit
    }

    // MARK: View content

    private func buildViewContent() {
        titleDisplayLabel.text = storedTitle
        titleDisplayLabel.isHidden = storedTitle.isEmpty
        titleDisplayLabel.font = .inter(ofSize: 13, weight: .semibold)
        titleDisplayLabel.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .white
        }
        titleDisplayLabel.numberOfLines = 1

        textLabel.text = storedText
        textLabel.font = .inter(ofSize: 13)
        textLabel.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.85)
                : UIColor.white.withAlphaComponent(0.85)
        }
        textLabel.numberOfLines = 4

        let inner: UIView
        if storedTitle.isEmpty {
            inner = padded(view: textLabel, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        } else {
            let stack = UIStackView(arrangedSubviews: [titleDisplayLabel, textLabel])
            stack.axis = .vertical
            stack.spacing = 4
            inner = padded(view: stack, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))
        }

        inner.translatesAutoresizingMaskIntoConstraints = false
        viewContentView.translatesAutoresizingMaskIntoConstraints = false
        viewContentView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: viewContentView.topAnchor),
            inner.leadingAnchor.constraint(equalTo: viewContentView.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: viewContentView.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: viewContentView.bottomAnchor)
        ])

        card.contentView.addSubview(viewContentView)
        NSLayoutConstraint.activate([
            viewContentView.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            viewContentView.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            viewContentView.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            viewContentView.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])
    }

    // MARK: Edit content

    private func buildEditContent() {
        // Title field
        titleField.text = storedTitle
        titleField.placeholder = L10n.photoName
        titleField.attributedPlaceholder = NSAttributedString(
            string: L10n.photoName,
            attributes: [.foregroundColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(0.35)
                    : UIColor.white.withAlphaComponent(0.35)
            }]
        )
        titleField.font = .inter(ofSize: 13, weight: .semibold)
        titleField.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .white
        }
        titleField.borderStyle = .none
        titleField.returnKeyType = .next
        titleField.delegate = self
        titleField.translatesAutoresizingMaskIntoConstraints = false

        // Separator
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        sep.translatesAutoresizingMaskIntoConstraints = false

        // Text view
        textView.backgroundColor = .clear
        textView.font = .inter(ofSize: 13)
        textView.textColor = UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }
        textView.text = storedText
        textView.isScrollEnabled = false
        textView.returnKeyType = .default
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        textView.translatesAutoresizingMaskIntoConstraints = false

        // Placeholder
        let ph = UILabel()
        ph.text = L10n.annotationPlaceholder
        ph.font = .inter(ofSize: 13)
        ph.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.35)
                : UIColor.white.withAlphaComponent(0.35)
        }
        ph.translatesAutoresizingMaskIntoConstraints = false
        ph.isHidden = !storedText.isEmpty
        textView.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10),
            ph.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 14)
        ])

        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification, object: textView, queue: .main
        ) { [weak ph, weak self] _ in
            ph?.isHidden = !(self?.textView.text.isEmpty ?? true)
        }

        // Color picker row
        let colorStack = buildColorPicker()
        colorStack.translatesAutoresizingMaskIntoConstraints = false

        let sep2 = UIView()
        sep2.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        sep2.translatesAutoresizingMaskIntoConstraints = false

        editContentView.translatesAutoresizingMaskIntoConstraints = false
        editContentView.addSubview(titleField)
        editContentView.addSubview(sep)
        editContentView.addSubview(textView)
        editContentView.addSubview(sep2)
        editContentView.addSubview(colorStack)
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true

        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: editContentView.topAnchor, constant: 10),
            titleField.leadingAnchor.constraint(equalTo: editContentView.leadingAnchor, constant: 14),
            titleField.trailingAnchor.constraint(equalTo: editContentView.trailingAnchor, constant: -14),
            titleField.heightAnchor.constraint(equalToConstant: 30),

            sep.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 8),
            sep.leadingAnchor.constraint(equalTo: editContentView.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: editContentView.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            textView.topAnchor.constraint(equalTo: sep.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: editContentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: editContentView.trailingAnchor),

            sep2.topAnchor.constraint(equalTo: textView.bottomAnchor),
            sep2.leadingAnchor.constraint(equalTo: editContentView.leadingAnchor),
            sep2.trailingAnchor.constraint(equalTo: editContentView.trailingAnchor),
            sep2.heightAnchor.constraint(equalToConstant: 0.5),

            colorStack.topAnchor.constraint(equalTo: sep2.bottomAnchor, constant: 8),
            colorStack.leadingAnchor.constraint(equalTo: editContentView.leadingAnchor, constant: 14),
            colorStack.trailingAnchor.constraint(lessThanOrEqualTo: editContentView.trailingAnchor, constant: -14),
            colorStack.bottomAnchor.constraint(equalTo: editContentView.bottomAnchor, constant: -8),
            colorStack.heightAnchor.constraint(equalToConstant: 22)
        ])

        card.contentView.addSubview(editContentView)
        NSLayoutConstraint.activate([
            editContentView.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            editContentView.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            editContentView.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            editContentView.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])
    }

    // MARK: Color picker

    private var colorDots: [UIButton] = []

    private func buildColorPicker() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        colorDots.removeAll()

        for (_, hex) in PinCalloutView.pinColors {
            let btn = UIButton(type: .system)
            let color = UIColor(hex: hex) ?? .systemBlue
            btn.backgroundColor = color
            btn.layer.cornerRadius = 11
            btn.layer.borderWidth = 2
            btn.widthAnchor.constraint(equalToConstant: 22).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
            let capturedHex = hex
            btn.addAction(UIAction { [weak self] _ in
                self?.selectedColorHex = capturedHex
                self?.updateColorSelection()
                // Live-update source pin
                if let pin = self?.sourcePinView as? AnnotationPinView {
                    pin.pinColor = UIColor(hex: capturedHex) ?? .systemBlue
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }, for: .touchUpInside)
            stack.addArrangedSubview(btn)
            colorDots.append(btn)
        }
        updateColorSelection()
        return stack
    }

    private func updateColorSelection() {
        for (i, (_, hex)) in PinCalloutView.pinColors.enumerated() {
            guard i < colorDots.count else { break }
            let selected = hex.uppercased() == selectedColorHex.uppercased()
            colorDots[i].layer.borderColor = selected ? UIColor.white.cgColor : UIColor.clear.cgColor
            colorDots[i].transform = selected ? CGAffineTransform(scaleX: 1.15, y: 1.15) : .identity
        }
    }

    // MARK: Floating buttons

    private func buildFloatingButtons() {
        // Set explicit bounds so center-based positioning gives correct hit area
        let size = CGSize(width: 36, height: 36)
        leftBtn.bounds = CGRect(origin: .zero, size: size)
        rightBtn.bounds = CGRect(origin: .zero, size: size)
        // Wire once — targets dispatch to mode-aware selectors
        leftBtn.addTarget(self,  action: #selector(leftBtnTapped),  for: .touchUpInside)
        rightBtn.addTarget(self, action: #selector(rightBtnTapped), for: .touchUpInside)
        addSubview(leftBtn)
        addSubview(rightBtn)
        updateButtonAppearance(forEdit: startInEdit)
    }

    /// Updates icon/color/visibility; does NOT change targets.
    private func updateButtonAppearance(forEdit edit: Bool) {
        let whiteTint = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor.white : UIColor.white }
        let darkBg = UIColor { trait in UIColor.black.withAlphaComponent(0.60) }
        if edit {
            leftBtn.configure(systemName: "checkmark", tint: whiteTint,
                              background: UIColor.systemGreen.withAlphaComponent(0.85))
            rightBtn.configure(systemName: "xmark", tint: whiteTint,
                               background: darkBg)
            rightBtn.isHidden = false
        } else {
            leftBtn.configure(systemName: "pencil", tint: whiteTint,
                              background: darkBg)
            rightBtn.configure(systemName: "trash", tint: whiteTint,
                               background: UIColor.systemRed.withAlphaComponent(0.80))
            rightBtn.isHidden = (deleteCallback == nil)
        }
    }

    // Dispatches based on which content view is active
    @objc private func leftBtnTapped()  { editContentView.isHidden ? enterEdit()  : saveTapped()    }
    @objc private func rightBtnTapped() { editContentView.isHidden ? confirmDelete() : cancelEdit() }

    /// Repositions the floating buttons relative to card frame.
    /// Uses `.center` (safe with any transform) instead of `.frame`.
    private func positionFloatingButtons(animated: Bool) {
        let btnSize: CGFloat = 36
        let gap:     CGFloat = 10
        let cardMid = cardShadow.frame.midX
        let centerY = cardShadow.frame.minY - 10 - btnSize / 2

        // Center leftBtn when rightBtn is hidden (single button)
        let leftCX:  CGFloat = rightBtn.isHidden ? cardMid : cardMid - btnSize / 2 - gap / 2
        let rightCX: CGFloat = cardMid + btnSize / 2 + gap / 2

        let block = { [self] in
            leftBtn.center = CGPoint(x: leftCX,  y: centerY)
            rightBtn.center = CGPoint(x: rightCX, y: centerY)
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0,
                           usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                           animations: block)
        } else {
            block()
        }
    }

    /// Cross-fades button icons only. Position is managed exclusively by
    /// animateCardAndButtons (keyboard callbacks) and positionFloatingButtons.
    private func animateButtonSwap(toEdit: Bool) {
        UIView.animate(withDuration: 0.13, delay: 0, options: .curveEaseIn,
                       animations: {
            self.leftBtn.alpha = 0
            self.rightBtn.alpha = 0
        }, completion: { _ in
            self.updateButtonAppearance(forEdit: toEdit)
            let showRight = !self.rightBtn.isHidden
            UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut,
                           animations: {
                self.leftBtn.alpha = 1
                self.rightBtn.alpha = showRight ? 1 : 0
            }, completion: nil)
        })
    }

    // MARK: - Mode switch

    @objc private func enterEdit() {
        titleField.text = titleDisplayLabel.text
        textView.text = textLabel.text
        UIView.transition(with: card, duration: 0.2, options: .transitionCrossDissolve) {
            self.viewContentView.isHidden = true
            self.editContentView.isHidden = false
        }
        animateCardHeight(editHeight)
        animateButtonSwap(toEdit: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { self.titleField.becomeFirstResponder() }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func cancelEdit() {
        textView.resignFirstResponder()
        titleField.resignFirstResponder()
        if startInEdit {
            dismissSelf()
        } else {
            UIView.transition(with: card, duration: 0.2, options: .transitionCrossDissolve) {
                self.viewContentView.isHidden = false
                self.editContentView.isHidden = true
            }
            animateCardHeight(viewHeight) { self.positionFloatingButtons(animated: true) }
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                self.cardShadow.frame.origin.y = self.cardOriginY(height: self.viewHeight, keyboardTop: self.keyboardTop)
            }
            animateButtonSwap(toEdit: false)
        }
    }

    @objc private func saveTapped() {
        let newTitle = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        textView.resignFirstResponder()
        titleField.resignFirstResponder()
        let cb = editCallback
        let colorHex = selectedColorHex
        dismissSelf { cb(newTitle, newText, colorHex) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func confirmDelete() {
        guard let cb = deleteCallback else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        UIView.animate(withDuration: 0.12) {
            self.cardShadow.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        } completion: { _ in
            self.dismissSelf { cb() }
        }
    }

    private func animateCardHeight(_ h: CGFloat, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
                       animations: { self.cardShadow.frame.size.height = h },
                       completion: { _ in completion?() })
    }

    // MARK: - Keyboard avoidance

    private func observeKeyboard() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                       name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                       name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info = n.userInfo,
              let kbFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        keyboardTop = kbFrame.minY
        let newCardY = cardOriginY(height: editHeight, keyboardTop: kbFrame.minY)
        animateCardAndButtons(toCardY: newCardY, duration: duration)
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) else { return }
        keyboardTop = nil
        let newCardY = cardOriginY(height: editHeight)
        animateCardAndButtons(toCardY: newCardY, duration: duration)
    }

    /// Animates the card origin.y and buttons together in one block (no nested calls).
    private func animateCardAndButtons(toCardY newCardY: CGFloat, duration: Double) {
        let btnSize: CGFloat = 36
        let gap:     CGFloat = 10
        let targetCY = newCardY - 10 - btnSize / 2
        let cardMid = cardOriginX + cardWidth / 2
        let showRight = !rightBtn.isHidden
        let leftCX: CGFloat = showRight ? cardMid - btnSize/2 - gap/2 : cardMid

        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.cardShadow.frame.origin.y = newCardY
            self.leftBtn.center = CGPoint(x: leftCX,                     y: targetCY)
            self.rightBtn.center = CGPoint(x: cardMid + btnSize/2 + gap/2, y: targetCY)
        }
    }

    // MARK: - Animate in/out

    private func animateIn() {
        sourcePinView?.alpha = 0.25

        // Save frame BEFORE changing anchorPoint — changing anchorPoint shifts the visual frame
        // unless we immediately compensate the layer position.
        let savedFrame = cardShadow.frame
        let anchorY: CGFloat = cardAbovePin ? 1.0 : 0.0
        cardShadow.layer.anchorPoint = CGPoint(x: 0.5, y: anchorY)
        cardShadow.layer.position = CGPoint(
            x: savedFrame.midX,
            y: savedFrame.minY + anchorY * savedFrame.height
        )

        // 1. Set content visibility (no animation yet)
        viewContentView.isHidden = startInEdit
        editContentView.isHidden = !startInEdit

        // 2. Position buttons while they have identity transform.
        //    Setting .frame/.center on a view with non-identity transform is undefined — must do this first.
        positionFloatingButtons(animated: false)

        // 3. Set initial animation state (AFTER positioning)
        [leftBtn, rightBtn].forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        }
        cardShadow.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        cardShadow.alpha = 0

        // 4. Animate card in, then reset anchorPoint to center for clean subsequent animations
        UIView.animate(withDuration: 0.34, delay: 0,
                       usingSpringWithDamping: 0.70, initialSpringVelocity: 0.4) {
            self.dimView.alpha = 1
            self.cardShadow.transform = .identity
            self.cardShadow.alpha = 1
        } completion: { _ in
            let f = self.cardShadow.frame
            self.cardShadow.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            self.cardShadow.layer.position = CGPoint(x: f.midX, y: f.midY)
        }

        // 5. Animate buttons in with correct target alphas
        let rightAlpha: CGFloat = rightBtn.isHidden ? 0 : 1
        UIView.animate(withDuration: 0.28, delay: 0.12,
                       usingSpringWithDamping: 0.72, initialSpringVelocity: 0) {
            self.leftBtn.alpha = 1
            self.leftBtn.transform = .identity
            self.rightBtn.alpha = rightAlpha
            self.rightBtn.transform = .identity
        }

        if startInEdit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { self.titleField.becomeFirstResponder() }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func dismissTapped() { dismissSelf() }

    func dismissSelf(completion: (() -> Void)? = nil) {
        textView.resignFirstResponder()
        titleField.resignFirstResponder()
        // Restore source pin
        let pinView = sourcePinView
        let done = completion
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn,
            animations: { [weak self] in
                self?.dimView.alpha = 0
                self?.cardShadow.alpha = 0
                self?.cardShadow.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                [self?.leftBtn, self?.rightBtn]
                    .compactMap { $0 }
                    .forEach { $0.alpha = 0; $0.transform = CGAffineTransform(scaleX: 0.3, y: 0.3) }
            },
            completion: { [weak self] _ in
                UIView.animate(withDuration: 0.18) { pinView?.alpha = 1 }
                self?.removeFromSuperview()
                done?()
            }
        )
    }

    // MARK: - Helpers

    private func padded(view: UIView, insets: UIEdgeInsets) -> UIView {
        let wrapper = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: insets.top),
            view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -insets.right),
            view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -insets.bottom)
        ])
        return wrapper
    }
}

// MARK: - UITextFieldDelegate

extension PinCalloutView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textView.becomeFirstResponder(); return false
    }
}

// MARK: - CircleActionButton

private final class CircleActionButton: UIButton {

    func configure(systemName: String, tint: UIColor, background: UIColor) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        tintColor = tint
        backgroundColor = background
        layer.cornerRadius = 18   // half of 36pt size
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor

        // Subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    override var isHighlighted: Bool {
        didSet {
            // Use alpha only — transform would conflict with animateButtonSwap
            UIView.animate(withDuration: 0.08) {
                self.alpha = self.isHighlighted ? 0.55 : 1.0
            }
        }
    }
}
