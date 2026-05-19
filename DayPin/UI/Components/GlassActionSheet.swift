import UIKit

// MARK: - GlassAction

struct GlassAction {
    enum Style { case `default`, destructive, cancel }
    let title: String
    let icon: String?
    let style: Style
    let handler: () -> Void

    init(_ title: String, icon: String? = nil, style: Style = .default, handler: @escaping () -> Void = {}) {
        self.title = title; self.icon = icon; self.style = style; self.handler = handler
    }
}

// MARK: - GlassActionSheet
// Compact dark card — Telegram-style, not full-width.

final class GlassActionSheet: UIView {

    // MARK: - Entry

    static func show(
        title: String? = nil,
        actions: [GlassAction],
        from viewController: UIViewController,
        sourceView: UIView? = nil
    ) {
        guard let window = viewController.view.window else { return }
        let sheet = GlassActionSheet(title: title, actions: actions, sourceView: sourceView, window: window)
        sheet.frame = window.bounds
        sheet.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(sheet)
        sheet.animateIn()
    }

    // MARK: - Private

    private let regularActions: [GlassAction]
    private let cancelAction: GlassAction?
    private let title: String?
    private let sourceView: UIView?
    private weak var parentWindow: UIWindow?

    private let dimView = UIView()
    private let mainCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let cancelCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

    private var mainCardBottomConstraint: NSLayoutConstraint!
    private var mainCardLeadingConstraint: NSLayoutConstraint!
    private var cancelCardBottomConstraint: NSLayoutConstraint!
    private var cancelCardLeadingConstraint: NSLayoutConstraint!
    private var titleHeight: CGFloat = 0

    // Compact width: ~265pt or 72% of screen, whichever is smaller
    private let cardWidth: CGFloat = min(265, UIScreen.main.bounds.width * 0.72)

    private init(title: String?, actions: [GlassAction], sourceView: UIView?, window: UIWindow) {
        self.title = title
        self.regularActions = actions.filter { $0.style != .cancel }
        self.cancelAction = actions.first { $0.style == .cancel }
        self.sourceView = sourceView
        self.parentWindow = window
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        // Dim background
        dimView.backgroundColor = UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.50)
                : UIColor.black.withAlphaComponent(0.35)
        })
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

        let safeBottom = parentWindow?.safeAreaInsets.bottom ?? 0
        let bottomPad = max(safeBottom, 12)
        let leadingPad: CGFloat = 16

        // MARK: Cancel card
        cancelCard.layer.cornerRadius = 14
        cancelCard.clipsToBounds = true
        cancelCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cancelCard)

        cancelCardLeadingConstraint = cancelCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingPad)
        cancelCardBottomConstraint = cancelCard.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 120)
        NSLayoutConstraint.activate([
            cancelCardLeadingConstraint,
            cancelCardBottomConstraint,
            cancelCard.widthAnchor.constraint(equalToConstant: cardWidth),
            cancelCard.heightAnchor.constraint(equalToConstant: 44)
        ])

        let cancelTitle = cancelAction?.title ?? L10n.cancel
        let cancelBtn = SheetButton(title: cancelTitle, icon: nil, isBold: true, isDestructive: false) { [weak self] in
            self?.animateOut()
            self?.cancelAction?.handler()
        }
        cancelCard.contentView.addSubview(cancelBtn)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cancelBtn.topAnchor.constraint(equalTo: cancelCard.contentView.topAnchor),
            cancelBtn.leadingAnchor.constraint(equalTo: cancelCard.contentView.leadingAnchor),
            cancelBtn.trailingAnchor.constraint(equalTo: cancelCard.contentView.trailingAnchor),
            cancelBtn.bottomAnchor.constraint(equalTo: cancelCard.contentView.bottomAnchor)
        ])

        // MARK: Main card
        mainCard.layer.cornerRadius = 14
        mainCard.clipsToBounds = true
        mainCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainCard)

        // Height estimate: title(36) + n*44 + separators
        titleHeight = title != nil ? 38 : 0
        let itemsHeight = CGFloat(regularActions.count) * 44
        let sepHeight = CGFloat(max(0, regularActions.count - 1)) * 0.5
        let totalHeight = titleHeight + itemsHeight + sepHeight

        mainCardLeadingConstraint = mainCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingPad)
        mainCardBottomConstraint = mainCard.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 120)
        NSLayoutConstraint.activate([
            mainCardLeadingConstraint,
            mainCardBottomConstraint,
            mainCard.widthAnchor.constraint(equalToConstant: cardWidth),
            mainCard.heightAnchor.constraint(equalToConstant: totalHeight)
        ])

        buildMainCardContent()
        _ = bottomPad // used in animateIn
    }

    private func buildMainCardContent() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        mainCard.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: mainCard.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: mainCard.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: mainCard.contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: mainCard.contentView.bottomAnchor)
        ])

        if let title {
            let lbl = UILabel()
            lbl.text = title
            lbl.font = .inter(ofSize: 12, weight: .regular)
            lbl.textColor = UIColor.secondaryLabel
            lbl.numberOfLines = 2
            let wrapper = UIView()
            lbl.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 10),
                lbl.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
                lbl.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
                lbl.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8)
            ])
            stack.addArrangedSubview(wrapper)
            stack.addArrangedSubview(makeSeparator())
        }

        for (i, action) in regularActions.enumerated() {
            let btn = SheetButton(
                title: action.title,
                icon: action.icon,
                isBold: false,
                isDestructive: action.style == .destructive
            ) { [weak self] in
                self?.animateOut()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { action.handler() }
            }
            stack.addArrangedSubview(btn)
            btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
            if i < regularActions.count - 1 {
                stack.addArrangedSubview(makeSeparator())
            }
        }
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    // MARK: - Animation

    private func animateIn() {
        layoutIfNeeded()

        if let sv = sourceView, let window = parentWindow {
            // ── Popover mode: grow from the source button ──────────────────
            cancelCard.isHidden = true

            // Switch mainCard to frame-based layout
            mainCardBottomConstraint.isActive   = false
            mainCardLeadingConstraint.isActive  = false
            mainCard.translatesAutoresizingMaskIntoConstraints = true

            let srcFrame   = sv.convert(sv.bounds, to: window)
            let cardHeight = titleHeight + CGFloat(regularActions.count) * 44
            let cardX      = max(12, min(srcFrame.maxX - cardWidth, window.bounds.width - cardWidth - 12))
            let cardY      = srcFrame.minY - cardHeight - 10

            mainCard.frame = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

            // Anchor bottom-right → scale from button position
            mainCard.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
            mainCard.layer.position    = CGPoint(x: cardX + cardWidth, y: cardY + cardHeight)
            mainCard.transform         = CGAffineTransform(scaleX: 0.05, y: 0.05)
            mainCard.alpha             = 0

            UIView.animate(withDuration: 0.36, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.2) {
                self.dimView.alpha      = 1
                self.mainCard.transform = .identity
                self.mainCard.alpha     = 1
            }
        } else {
            // ── Sheet mode: slide up from bottom ────────────────────────────
            let safeBottom = parentWindow?.safeAreaInsets.bottom ?? 0
            let bottomPad  = max(safeBottom, 12)

            mainCardBottomConstraint.constant   = -(bottomPad + 44 + 8 + 12)
            cancelCardBottomConstraint.constant = -(bottomPad + 12)

            UIView.animate(withDuration: 0.44, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.1) {
                self.dimView.alpha = 1
                self.layoutIfNeeded()
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func animateOut() {
        if sourceView != nil {
            // Collapse back toward anchor
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
                self.dimView.alpha      = 0
                self.mainCard.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
                self.mainCard.alpha     = 0
            } completion: { _ in self.removeFromSuperview() }
            return
        }

        let safeBottom = parentWindow?.safeAreaInsets.bottom ?? 0
        mainCardBottomConstraint.constant   = 300 + safeBottom
        cancelCardBottomConstraint.constant = 200 + safeBottom

        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.layoutIfNeeded()
        } completion: { _ in self.removeFromSuperview() }
    }
}

// MARK: - AddNoteAction

struct AddNoteAction {
    let title: String
    let icon:  String
    let badgeColor: UIColor
    let handler: () -> Void
}

// MARK: - AddNoteMenuSheet
// Wider, badge-style menu card that appears near the FAB button.

final class AddNoteMenuSheet: UIView {

    // MARK: Entry

    static func show(
        title: String,
        actions: [AddNoteAction],
        from viewController: UIViewController,
        sourceView: UIView? = nil
    ) {
        guard let window = viewController.view.window else { return }
        let sheet = AddNoteMenuSheet(title: title, actions: actions, sourceView: sourceView, window: window)
        sheet.frame = window.bounds
        sheet.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(sheet)
        sheet.animateIn()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: Private

    private let menuTitle: String
    private let actions: [AddNoteAction]
    private let sourceView: UIView?
    private weak var parentWindow: UIWindow?

    private let dimView = UIView()
    /// Solid surface card — avoids UIVisualEffectView vibrancy that kills badge colours
    private let card    = UIView()

    private let cardWidth: CGFloat    = min(260, UIScreen.main.bounds.width * 0.70)
    private let rowHeight: CGFloat    = 52
    private let headerHeight: CGFloat = 34

    private init(title: String, actions: [AddNoteAction], sourceView: UIView?, window: UIWindow) {
        self.menuTitle    = title
        self.actions      = actions
        self.sourceView   = sourceView
        self.parentWindow = window
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setup() {
        // Dim background
        dimView.backgroundColor = UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.50)
                : UIColor.black.withAlphaComponent(0.30)
        })
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

        // Card — opaque surface so badge colours render faithfully
        card.backgroundColor     = DayPinDesign.cardSurface
        card.layer.cornerRadius  = 16
        card.layer.masksToBounds = true
        card.layer.borderWidth   = 0.5
        card.layer.borderColor   = UIColor.separator.withAlphaComponent(0.45).cgColor
        addSubview(card)

        buildCardContent()
    }

    private func buildCardContent() {
        let cv = card

        // Section header
        let hdr = UILabel()
        hdr.text          = menuTitle
        hdr.font          = .inter(ofSize: 12, weight: .medium)
        hdr.textColor     = .secondaryLabel
        hdr.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(hdr)
        NSLayoutConstraint.activate([
            hdr.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            hdr.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            hdr.topAnchor.constraint(equalTo: cv.topAnchor, constant: 10),
            hdr.heightAnchor.constraint(equalToConstant: headerHeight - 10)
        ])

        // Separator under header
        let sep0 = makeSeparator()
        cv.addSubview(sep0)
        NSLayoutConstraint.activate([
            sep0.topAnchor.constraint(equalTo: cv.topAnchor, constant: headerHeight),
            sep0.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            sep0.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
        ])

        // Action rows
        for (idx, action) in actions.enumerated() {
            let rowY = headerHeight + CGFloat(idx) * rowHeight
            let row  = makeActionRow(action: action)
            cv.addSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                row.topAnchor.constraint(equalTo: cv.topAnchor, constant: rowY),
                row.heightAnchor.constraint(equalToConstant: rowHeight)
            ])

            if idx < actions.count - 1 {
                let sep = makeSeparator()
                cv.addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.topAnchor.constraint(equalTo: cv.topAnchor, constant: rowY + rowHeight),
                    sep.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
                    sep.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
                ])
            }
        }
    }

    private func makeActionRow(action: AddNoteAction) -> UIView {
        let container = UIButton(type: .system)
        container.tintColor = .label
        container.translatesAutoresizingMaskIntoConstraints = false

        // Highlight feedback
        container.addTarget(self, action: #selector(rowHighlighted(_:)), for: .touchDown)
        container.addTarget(self, action: #selector(rowUnhighlighted(_:)), for: [.touchUpOutside, .touchCancel])
        container.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
        container.accessibilityLabel = action.title

        // Store handler via associated object
        objc_setAssociatedObject(container, &handlerKey, action.handler, .OBJC_ASSOCIATION_COPY_NONATOMIC)

        // Badge
        let badge = UIView()
        badge.backgroundColor      = action.badgeColor
        badge.layer.cornerRadius   = 9
        badge.layer.masksToBounds  = true
        badge.isUserInteractionEnabled = false
        badge.translatesAutoresizingMaskIntoConstraints = false

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: action.icon, withConfiguration: iconCfg))
        iconView.tintColor    = UIColor(dynamicProvider: { _ in UIColor.white })
        iconView.contentMode  = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15)
        ])

        // Title
        let label = UILabel()
        label.text          = action.title
        label.font          = .inter(ofSize: 14, weight: .medium)
        label.textColor     = .label
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(badge)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            badge.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 32),
            badge.heightAnchor.constraint(equalToConstant: 32),

            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private var handlerKey: UInt8 = 0

    @objc private func rowHighlighted(_ sender: UIView) {
        UIView.animate(withDuration: 0.08) { sender.alpha = 0.4 }
    }
    @objc private func rowUnhighlighted(_ sender: UIView) {
        UIView.animate(withDuration: 0.15) { sender.alpha = 1 }
    }
    @objc private func rowTapped(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) { sender.alpha = 1 }
        guard let handler = objc_getAssociatedObject(sender, &handlerKey) as? (() -> Void) else { return }
        animateOut()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { handler() }
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    // MARK: Animation

    private func animateIn() {
        guard let sv = sourceView, let window = parentWindow else { return }

        let srcFrame   = sv.convert(sv.bounds, to: window)
        let cardHeight = headerHeight + CGFloat(actions.count) * rowHeight
        let cardX      = max(12, min(srcFrame.maxX - cardWidth, window.bounds.width - cardWidth - 12))
        let cardY      = max(8, srcFrame.minY - cardHeight - 10)

        card.frame = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

        // Scale from bottom-right corner (near FAB)
        card.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
        card.layer.position    = CGPoint(x: cardX + cardWidth, y: cardY + cardHeight)
        card.transform         = CGAffineTransform(scaleX: 0.05, y: 0.05)
        card.alpha             = 0

        UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.2) {
            self.dimView.alpha  = 1
            self.card.transform = .identity
            self.card.alpha     = 1
        }
    }

    @objc private func animateOut() {
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha  = 0
            self.card.transform = CGAffineTransform(scaleX: 0.05, y: 0.05)
            self.card.alpha     = 0
        } completion: { _ in self.removeFromSuperview() }
    }
}

// MARK: - SheetButton

private final class SheetButton: UIButton {
    private let action: () -> Void

    init(title: String, icon: String?, isBold: Bool, isDestructive: Bool, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)

        let color: UIColor = isDestructive ? .systemRed : .label
        setTitleColor(color, for: .normal)
        setTitleColor(color.withAlphaComponent(0.4), for: .highlighted)
        tintColor = color
        titleLabel?.font = .inter(ofSize: 15, weight: isBold ? .semibold : .regular)
        setTitle(title, for: .normal)
        contentHorizontalAlignment = isBold ? .center : .left
        contentEdgeInsets = isBold
            ? .zero
            : UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        if let icon, !isBold {
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
            imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
            titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: -10)
        }

        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addTarget(self, action: #selector(down), for: .touchDown)
        addTarget(self, action: #selector(up), for: [.touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { UIView.animate(withDuration: 0.1) { self.alpha = 1 }; action() }
    @objc private func down()   { UIView.animate(withDuration: 0.08) { self.alpha = 0.35 } }
    @objc private func up()     { UIView.animate(withDuration: 0.15) { self.alpha = 1 } }
}
