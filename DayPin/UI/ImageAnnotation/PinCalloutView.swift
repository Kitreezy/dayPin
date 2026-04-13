import UIKit

// MARK: - PinCalloutView
//
// Compact speech-bubble callout that grows directly FROM the pin.
// View mode  → text + ✏️ / 🗑️ icon buttons
// Edit mode  → multiline UITextView + ✓ / ✕ icon buttons at top
//
// BUG FIX: callbacks stored as non-optional properties to avoid
//           weak-self dealloc before completion fires.

final class PinCalloutView: UIView {

    // MARK: - Public entry

    static func show(
        pinWindowPoint: CGPoint,
        text: String,
        onEdit: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: \.isKeyWindow) else { return }

        // Dismiss any existing callout first
        window.subviews.compactMap { $0 as? PinCalloutView }.forEach { $0.animateOut() }

        let c = PinCalloutView(pin: pinWindowPoint, text: text, onEdit: onEdit, onDelete: onDelete)
        c.frame = window.bounds
        c.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(c)
        c.animateIn()
    }

    // MARK: - Private storage (no optionals — avoids weak-self dealloc bug)

    private let pinPoint: CGPoint
    private let storedText: String
    private let editCallback: (String) -> Void
    private let deleteCallback: () -> Void

    private init(pin: CGPoint, text: String, onEdit: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        pinPoint  = pin
        storedText = text
        editCallback   = onEdit
        deleteCallback = onDelete
        super.init(frame: .zero)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Geometry

    private let width: CGFloat   = min(230, UIScreen.main.bounds.width - 32)
    private let viewHeight: CGFloat = 110  // approximate view-mode height
    private let editHeight: CGFloat = 168  // approximate edit-mode height

    private var cardAbovePin: Bool {
        pinPoint.y > UIScreen.main.bounds.height * 0.45
    }

    /// Card origin.x — centred on pin but clamped to screen edges
    private var cardOriginX: CGFloat {
        max(12, min(UIScreen.main.bounds.width - width - 12, pinPoint.x - width / 2))
    }

    /// Card origin.y when showing view mode
    private func cardOriginY(height: CGFloat) -> CGFloat {
        cardAbovePin
            ? pinPoint.y - height - 10
            : pinPoint.y + 10
    }

    // MARK: - UI

    private let dimView   = UIView()
    private let card      = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    // View mode
    private let viewStack = UIStackView()
    private let textLabel = UILabel()

    // Edit mode
    private let editStack = UIStackView()
    private let textView  = UITextView()

    private func buildUI() {
        // Light tap-to-dismiss overlay (no heavy dim)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        dimView.alpha = 0
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(animateOut)))

        // Position card manually (not auto-layout) so we can animate from pin
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.25
        card.layer.shadowRadius = 20
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.frame = CGRect(x: cardOriginX, y: cardOriginY(height: viewHeight), width: width, height: viewHeight)
        addSubview(card)

        buildViewMode()
        buildEditMode()
        showMode(edit: false, animated: false)
    }

    // MARK: View mode

    private func buildViewMode() {
        textLabel.text = storedText
        textLabel.font = .systemFont(ofSize: 14, weight: .regular)
        textLabel.textColor = .white
        textLabel.numberOfLines = 5
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        let sep = makeSep()

        let editBtn   = iconButton(systemName: "pencil",        tint: .white,      sel: #selector(enterEdit))
        let deleteBtn = iconButton(systemName: "trash",         tint: .systemRed,  sel: #selector(confirmDelete))

        let btnRow = UIStackView(arrangedSubviews: [editBtn, makeSepV(), deleteBtn])
        btnRow.axis = .horizontal
        btnRow.distribution = .fillEqually
        btnRow.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let textWrapper = padded(view: textLabel, insets: UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))

        viewStack.axis = .vertical
        viewStack.spacing = 0
        [textWrapper, sep, btnRow].forEach { viewStack.addArrangedSubview($0) }

        viewStack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(viewStack)
        NSLayoutConstraint.activate([
            viewStack.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            viewStack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            viewStack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            viewStack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])
    }

    // MARK: Edit mode

    private func buildEditMode() {
        let saveBtn   = iconButton(systemName: "checkmark",     tint: .systemGreen, sel: #selector(saveTapped))
        let cancelBtn = iconButton(systemName: "xmark",         tint: .secondaryLabel.withAlphaComponent(2), sel: #selector(cancelEdit))

        let topRow = UIStackView(arrangedSubviews: [cancelBtn, UIView(), saveBtn])
        topRow.axis = .horizontal
        topRow.spacing = 0
        topRow.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let topWrapper = padded(view: topRow, insets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))

        let sep = makeSep()

        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .white
        textView.text = storedText
        textView.isScrollEnabled = false
        textView.returnKeyType = .default
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let ph = UILabel()
        ph.text = L10n.annotationPlaceholder
        ph.font = .systemFont(ofSize: 14)
        ph.textColor = UIColor.white.withAlphaComponent(0.35)
        ph.translatesAutoresizingMaskIntoConstraints = false
        ph.isHidden = !storedText.isEmpty
        textView.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.topAnchor.constraint(equalTo: textView.topAnchor, constant: 12),
            ph.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 14)
        ])
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

        NotificationCenter.default.addObserver(forName: UITextView.textDidChangeNotification, object: textView, queue: .main) { [weak ph, weak self] _ in
            ph?.isHidden = !(self?.textView.text.isEmpty ?? true)
        }

        editStack.axis = .vertical
        editStack.spacing = 0
        [topWrapper, sep, textView].forEach { editStack.addArrangedSubview($0) }

        editStack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(editStack)
        NSLayoutConstraint.activate([
            editStack.topAnchor.constraint(equalTo: card.contentView.topAnchor),
            editStack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
            editStack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
            editStack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
        ])
    }

    // MARK: - Mode switch

    private func showMode(edit: Bool, animated: Bool) {
        let block = {
            self.viewStack.isHidden = edit
            self.editStack.isHidden = !edit
        }
        if animated {
            UIView.transition(with: card, duration: 0.2, options: [.transitionCrossDissolve], animations: block)
        } else {
            block()
        }
    }

    @objc private func enterEdit() {
        showMode(edit: true, animated: true)
        textView.text = textLabel.text
        // Resize card for edit mode
        animateCardHeight(editHeight)
        UIView.animate(withDuration: 0.25, delay: 0.1, options: .curveEaseOut) {
            self.card.frame.origin.y = self.cardOriginY(height: self.editHeight)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.textView.becomeFirstResponder() }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func cancelEdit() {
        textView.resignFirstResponder()
        showMode(edit: false, animated: true)
        animateCardHeight(viewHeight)
        UIView.animate(withDuration: 0.25, options: .curveEaseOut) {
            self.card.frame.origin.y = self.cardOriginY(height: self.viewHeight)
        }
    }

    @objc private func saveTapped() {
        let newText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            textView.shake()
            return
        }
        textView.resignFirstResponder()
        // Capture callback locally BEFORE removeFromSuperview to avoid dealloc
        let callback = editCallback
        animateOut { callback(newText) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func confirmDelete() {
        let callback = deleteCallback
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        UIView.animate(withDuration: 0.12, animations: {
            self.card.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            self.animateOut { callback() }
        }
    }

    private func animateCardHeight(_ h: CGFloat) {
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0) {
            self.card.frame.size.height = h
        }
    }

    // MARK: - Animate in/out

    private func animateIn() {
        // Grow from pin: set anchor to the edge nearest pin, scale from 0
        let anchorY: CGFloat = cardAbovePin ? 1.0 : 0.0
        card.layer.anchorPoint = CGPoint(x: 0.5, y: anchorY)
        // Recalculate position (anchorPoint change shifts the view)
        let anchorAbsY = card.frame.origin.y + anchorY * card.frame.height
        card.layer.position = CGPoint(x: card.frame.midX, y: anchorAbsY)

        card.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        card.alpha = 0

        UIView.animate(withDuration: 0.36, delay: 0, usingSpringWithDamping: 0.68, initialSpringVelocity: 0.4) {
            self.dimView.alpha = 1
            self.card.transform = .identity
            self.card.alpha = 1
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc func animateOut(completion: (() -> Void)? = nil) {
        textView.resignFirstResponder()
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    // MARK: - Helpers

    private func iconButton(systemName: String, tint: UIColor, sel: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        btn.tintColor = tint
        btn.addTarget(self, action: sel, for: .touchUpInside)
        return btn
    }

    private func makeSep() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    private func makeSepV() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        v.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

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
