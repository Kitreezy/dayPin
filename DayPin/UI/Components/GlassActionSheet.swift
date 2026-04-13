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
    private let mainCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let cancelCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    private var mainCardBottomConstraint: NSLayoutConstraint!
    private var mainCardLeadingConstraint: NSLayoutConstraint!
    private var cancelCardBottomConstraint: NSLayoutConstraint!
    private var cancelCardLeadingConstraint: NSLayoutConstraint!

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
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
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
            cancelCard.heightAnchor.constraint(equalToConstant: 52)
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

        // Height estimate: title(36) + n*52 + separators
        let titleHeight: CGFloat = title != nil ? 42 : 0
        let itemsHeight = CGFloat(regularActions.count) * 52
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
            lbl.font = .systemFont(ofSize: 12, weight: .regular)
            lbl.textColor = UIColor.white.withAlphaComponent(0.45)
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
            btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
            if i < regularActions.count - 1 {
                stack.addArrangedSubview(makeSeparator())
            }
        }
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    // MARK: - Animation

    private func animateIn() {
        layoutIfNeeded()
        let safeBottom = parentWindow?.safeAreaInsets.bottom ?? 0
        let bottomPad = max(safeBottom, 12)

        mainCardBottomConstraint.constant = -(bottomPad + 52 + 8 + 12)   // above cancel
        cancelCardBottomConstraint.constant = -(bottomPad + 12)

        UIView.animate(withDuration: 0.44, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.1) {
            self.dimView.alpha = 1
            self.layoutIfNeeded()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func animateOut() {
        let safeBottom = parentWindow?.safeAreaInsets.bottom ?? 0
        mainCardBottomConstraint.constant = 300 + safeBottom
        cancelCardBottomConstraint.constant = 200 + safeBottom

        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.layoutIfNeeded()
        } completion: { _ in self.removeFromSuperview() }
    }
}

// MARK: - SheetButton

private final class SheetButton: UIButton {
    private let action: () -> Void

    init(title: String, icon: String?, isBold: Bool, isDestructive: Bool, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)

        let color: UIColor = isDestructive ? .systemRed : .white
        setTitleColor(color, for: .normal)
        setTitleColor(color.withAlphaComponent(0.4), for: .highlighted)
        tintColor = color
        titleLabel?.font = .systemFont(ofSize: 17, weight: isBold ? .semibold : .regular)
        setTitle(title, for: .normal)
        contentHorizontalAlignment = isBold ? .center : .left
        contentEdgeInsets = isBold
            ? .zero
            : UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)

        if let icon, !isBold {
            let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
            setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
            imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)
            titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: -12)
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
