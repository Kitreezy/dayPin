import UIKit

// MARK: - PillTabBar

private final class PillTabBar: UIView {

    var onSelect: ((Int) -> Void)?
    private(set) var selectedIndex = 0

    private let blur        = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let tintOverlay = UIView()
    private var btns: [UIButton] = []
    private let items: [(normal: String, filled: String)]

    init(items: [(String, String)]) {
        self.items = items
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Build

    private func build() {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius  = 20
        layer.shadowOffset  = CGSize(width: 0, height: 4)

        blur.layer.cornerRadius  = 26
        blur.layer.borderWidth   = 0.5
        blur.layer.borderColor   = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tintOverlay)
        NSLayoutConstraint.activate([
            tintOverlay.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        let stack = UIStackView()
        stack.axis         = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        for (i, _) in items.enumerated() {
            let btn = UIButton(type: .system)
            btn.tag = i
            btn.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
            btns.append(btn)
        }

        refresh(accent: DayPinDesign.accent)
    }

    // MARK: Public

    func select(index: Int, accent: UIColor) {
        selectedIndex = index
        refresh(accent: accent)
    }

    func refresh(accent: UIColor) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        for (i, btn) in btns.enumerated() {
            let isOn = i == selectedIndex
            let name = isOn ? items[i].filled : items[i].normal
            btn.setImage(
                UIImage(systemName: name, withConfiguration: cfg)
                    ?? UIImage(systemName: items[i].normal, withConfiguration: cfg),
                for: .normal
            )
            btn.tintColor = isOn ? accent : .secondaryLabel
        }

        let isDark = traitCollection.userInterfaceStyle == .dark
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        accent.getRed(&r, green: &g, blue: &b, alpha: nil)
        let base: UIColor = isDark
            ? UIColor(red: 0.05 + r * 0.10, green: 0.05 + g * 0.10, blue: 0.05 + b * 0.10, alpha: 1)
            : UIColor(red: 0.96 + r * 0.04, green: 0.96 + g * 0.04, blue: 0.96 + b * 0.04, alpha: 1)
        tintOverlay.backgroundColor = base.withAlphaComponent(isDark ? 0.33 : 0.24)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 26).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refresh(accent: DayPinDesign.accent)
        }
    }

    @objc private func tapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSelect?(sender.tag)
    }
}

// MARK: - AddActionGridView

private final class AddActionGridView: UIView {

    struct Item {
        let title: String
        let icon:  String
        let color: UIColor
        let handler: () -> Void
    }

    private let shadowWrapper = UIView()
    // systemThinMaterial is more visible than UltraThin on plain dark backgrounds
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private var stackView: UIStackView?
    private var items: [Item] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildShell()
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(items: [Item]) {
        self.items = items
        stackView?.removeFromSuperview()
        buildGrid()
    }

    // MARK: Shell (shadow + blur wrapper)

    private func buildShell() {
        translatesAutoresizingMaskIntoConstraints = false

        shadowWrapper.layer.cornerRadius  = 20
        shadowWrapper.layer.shadowColor   = UIColor.black.cgColor
        shadowWrapper.layer.shadowOpacity = 0.28
        shadowWrapper.layer.shadowRadius  = 22
        shadowWrapper.layer.shadowOffset  = CGSize(width: 0, height: 8)
        shadowWrapper.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shadowWrapper)
        NSLayoutConstraint.activate([
            shadowWrapper.topAnchor.constraint(equalTo: topAnchor),
            shadowWrapper.leadingAnchor.constraint(equalTo: leadingAnchor),
            shadowWrapper.trailingAnchor.constraint(equalTo: trailingAnchor),
            shadowWrapper.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Same border/clip style as PillTabBar
        blur.layer.cornerRadius = 20
        blur.layer.borderWidth  = 0.5
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.clipsToBounds      = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        shadowWrapper.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: shadowWrapper.topAnchor),
            blur.leadingAnchor.constraint(equalTo: shadowWrapper.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: shadowWrapper.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: shadowWrapper.bottomAnchor)
        ])

        // Tint overlay — UIColor(dynamicProvider:) updates automatically on light/dark switch.
        // Uses IDENTICAL accent-tinted formula as PillTabBar so colours always match.
        let tint = UIView()
        tint.backgroundColor = UIColor { _ in
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            let accent = DayPinDesign.accent
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            accent.getRed(&r, green: &g, blue: &b, alpha: nil)
            let base: UIColor = isDark
                ? UIColor(red: 0.05 + r * 0.10, green: 0.05 + g * 0.10, blue: 0.05 + b * 0.10, alpha: 1)
                : UIColor(red: 0.96 + r * 0.04, green: 0.96 + g * 0.04, blue: 0.96 + b * 0.04, alpha: 1)
            return base.withAlphaComponent(isDark ? 0.38 : 0.28)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])
    }

    // MARK: Grid layout — single row, all items side by side

    private func buildGrid() {
        stackView?.removeFromSuperview()

        let row = UIStackView()
        row.axis         = .horizontal
        row.distribution = .fillEqually
        row.spacing      = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: blur.contentView.topAnchor,     constant: 12),
            row.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor,   constant: 12),
            row.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor,    constant: -12)
        ])

        for (i, item) in items.enumerated() {
            row.addArrangedSubview(makeCell(item, tag: i))
        }
        stackView = row
    }

    private func makeCell(_ item: Item, tag: Int) -> UIView {
        // Transparent container — tap area covers icon + label
        let cell = UIView()
        cell.backgroundColor      = .clear
        cell.isUserInteractionEnabled = true
        cell.tag = tag

        // Dark rounded square (icon only, no text inside)
        let bgView = UIView()
        bgView.backgroundColor    = UIColor.white.withAlphaComponent(0.07)
        bgView.layer.cornerRadius = 16
        bgView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(bgView)

        // Icon centered inside square
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let iconView = UIImageView(image: UIImage(systemName: item.icon, withConfiguration: iconCfg))
        iconView.tintColor   = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(iconView)

        // Label sits BELOW the square, outside it
        let label = UILabel()
        label.text                      = item.title
        label.font                      = .systemFont(ofSize: 12, weight: .regular)
        label.textColor                 = UIColor.white.withAlphaComponent(0.82)
        label.textAlignment             = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor        = 0.75
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)

        NSLayoutConstraint.activate([
            // bgView fills cell width, 1:1 square — no internal gaps
            bgView.topAnchor.constraint(equalTo: cell.topAnchor),
            bgView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            bgView.heightAnchor.constraint(equalTo: bgView.widthAnchor),

            // Icon centered in square
            iconView.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: bgView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            // Label below square, outside bgView
            label.topAnchor.constraint(equalTo: bgView.bottomAnchor, constant: 7),
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(cellTapped(_:)))
        cell.addGestureRecognizer(tap)
        return cell
    }

    @objc private func cellTapped(_ gr: UITapGestureRecognizer) {
        guard let v = gr.view, v.tag < items.count else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        items[v.tag].handler()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowWrapper.layer.shadowPath =
            UIBezierPath(roundedRect: shadowWrapper.bounds, cornerRadius: 20).cgPath
    }
}

// MARK: - MainContainerViewController

final class MainContainerViewController: UITabBarController {

    // MARK: Views
    private var pillBar:         PillTabBar!
    private var addCircleView:   UIView!       // shadow wrapper for the "+" button
    private var addCircleInner:  UIButton!     // actual tappable button inside
    private var actionGrid:      AddActionGridView!

    // MARK: Constraints
    private var pillBottomConstraint:    NSLayoutConstraint!
    private var addBtnBottomConstraint:  NSLayoutConstraint!
    private var gridBottomConstraint:    NSLayoutConstraint!

    private var isGridOpen = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupNavBarAppearance()
        setupBottomBar()
        // Extra inset = pill (56) + gap below (14) = 70
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 70, right: 0)
        ThemeManager.shared.apply()
        delegate = self
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil
        )
    }

    // MARK: - Tabs

    private func setupTabs() {
        let today    = makeNav(root: TodayViewController(),      title: L10n.tabToday)
        let calendar = makeNav(root: CalendarViewController(),   title: L10n.tabCalendar)
        let folders  = makeNav(root: FolderListViewController(), title: "Папки")
        let all      = makeNav(root: TasksViewController(),      title: L10n.tabAll)
        viewControllers = [today, calendar, folders, all]
    }

    private func makeNav(root: UIViewController, title: String) -> UINavigationController {
        root.title = title
        return UINavigationController(rootViewController: root)
    }

    // MARK: - Nav bar appearance

    private func setupNavBarAppearance() {
        let app = DayPinDesign.makeNavBarAppearance()
        UINavigationBar.appearance().standardAppearance   = app
        UINavigationBar.appearance().scrollEdgeAppearance = app
        UINavigationBar.appearance().compactAppearance    = app
        UINavigationBar.appearance().prefersLargeTitles   = false
        UINavigationBar.appearance().tintColor            = DayPinDesign.accent
    }

    // MARK: - Bottom bar

    private func setupBottomBar() {
        tabBar.isHidden = true

        // 1. Pill (left portion)
        pillBar = PillTabBar(items: [
            ("sun.max",   "sun.max.fill"),
            ("calendar",  "calendar.fill"),
            ("folder",    "folder.fill"),
            ("tray.full", "tray.full.fill")
        ])
        pillBar.translatesAutoresizingMaskIntoConstraints = false
        pillBar.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectedIndex = index
            self.pillBar.select(index: index, accent: DayPinDesign.accent)
            if self.isGridOpen { self.closeGrid(animated: true) }
        }
        view.addSubview(pillBar)

        // 2. Circular add button (right side) — matches pill style
        buildAddCircleButton()
        view.addSubview(addCircleView)

        // 3. Action grid (hidden initially, same horizontal span as pill)
        actionGrid = AddActionGridView()
        actionGrid.alpha     = 0
        actionGrid.transform = CGAffineTransform(translationX: 0, y: 32)
        view.addSubview(actionGrid)
        refreshGrid()

        // Bottom constraints — all share the same constant, updated in viewSafeAreaInsetsDidChange
        pillBottomConstraint   = pillBar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
        addBtnBottomConstraint = addCircleView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
        gridBottomConstraint   = actionGrid.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)

        NSLayoutConstraint.activate([
            // Pill: leading edge → left of add button
            pillBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pillBar.trailingAnchor.constraint(equalTo: addCircleView.leadingAnchor, constant: -10),
            pillBar.heightAnchor.constraint(equalToConstant: 56),
            pillBottomConstraint,

            // Add button: fixed circle, right edge
            addCircleView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addCircleView.widthAnchor.constraint(equalToConstant: 56),
            addCircleView.heightAnchor.constraint(equalToConstant: 56),
            addBtnBottomConstraint,

            // Grid: same width as pill bar
            actionGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            actionGrid.trailingAnchor.constraint(equalTo: addCircleView.leadingAnchor, constant: -10),
            gridBottomConstraint
        ])
    }

    private func buildAddCircleButton() {
        // Shadow wrapper (no clip, so shadow renders outside rounded rect)
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.layer.cornerRadius  = 28
        wrapper.layer.shadowColor   = UIColor.black.cgColor
        wrapper.layer.shadowOpacity = 0.14
        wrapper.layer.shadowRadius  = 20
        wrapper.layer.shadowOffset  = CGSize(width: 0, height: 4)

        // Frosted glass inner — matches pill appearance
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.layer.cornerRadius = 28
        blur.layer.borderWidth  = 0.5
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.clipsToBounds      = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: wrapper.topAnchor),
            blur.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])

        // Tint overlay — dynamic color, identical accent formula as PillTabBar
        // UIColor(dynamicProvider:) re-evaluates on every light/dark switch automatically
        let tint = UIView()
        tint.backgroundColor = UIColor { _ in
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            let accent = DayPinDesign.accent
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            accent.getRed(&r, green: &g, blue: &b, alpha: nil)
            let base: UIColor = isDark
                ? UIColor(red: 0.05 + r * 0.10, green: 0.05 + g * 0.10, blue: 0.05 + b * 0.10, alpha: 1)
                : UIColor(red: 0.96 + r * 0.04, green: 0.96 + g * 0.04, blue: 0.96 + b * 0.04, alpha: 1)
            return base.withAlphaComponent(isDark ? 0.33 : 0.24)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        // Button (fills contentView, hit area = full circle)
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        btn.setImage(UIImage(systemName: "plus", withConfiguration: iconCfg), for: .normal)
        btn.tintColor = .label
        btn.addTarget(self, action: #selector(addBtnTapped), for: .touchUpInside)
        blur.contentView.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            btn.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            btn.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        addCircleView  = wrapper
        addCircleInner = btn
    }

    // MARK: - Grid content

    private func refreshGrid() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        // Short display names for the compact grid
        let titleText   = L10n.isRussian ? "Текст"    : "Text"
        let titlePhoto  = L10n.isRussian ? "Фотопин"  : "Photo Pin"
        let titleCamera = L10n.isRussian ? "Камера"   : "Camera"
        let titleLink   = L10n.isRussian ? "Ссылка"   : "Link"
        var rawItems: [(title: String, icon: String, color: UIColor, notif: Notification.Name)] = [
            (titleText,  "text.alignleft",     DayPinDesign.textCardTint,  .dayPinAddText),
            (titlePhoto, "photo.on.rectangle", DayPinDesign.imageCardTint, .dayPinAddPhoto)
        ]
        if hasCamera {
            rawItems.append((titleCamera, "camera", DayPinDesign.imageCardTint, .dayPinAddCamera))
        }
        rawItems.append((titleLink, "link", DayPinDesign.linkCardTint, .dayPinAddLink))

        let items = rawItems.map { raw in
            AddActionGridView.Item(title: raw.title, icon: raw.icon, color: raw.color) { [weak self] in
                self?.closeGrid(animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    NotificationCenter.default.post(name: raw.notif, object: nil)
                }
            }
        }
        actionGrid.configure(items: items)
    }

    // MARK: - Add button toggle

    @objc private func addBtnTapped() {
        isGridOpen ? closeGrid(animated: true) : openGrid()
    }

    private func openGrid() {
        guard !isGridOpen else { return }
        isGridOpen = true

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        UIView.animate(withDuration: 0.45, delay: 0,
                       usingSpringWithDamping: 0.72, initialSpringVelocity: 0.5) {
            self.pillBar.alpha     = 0
            self.pillBar.transform = CGAffineTransform(translationX: 0, y: 20)

            self.actionGrid.alpha     = 1
            self.actionGrid.transform = .identity

            self.addCircleInner.setImage(
                UIImage(systemName: "xmark", withConfiguration: iconCfg), for: .normal)
        }
    }

    private func closeGrid(animated: Bool) {
        guard isGridOpen else { return }
        isGridOpen = false

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let block = {
            self.pillBar.alpha     = 1
            self.pillBar.transform = .identity

            self.actionGrid.alpha     = 0
            self.actionGrid.transform = CGAffineTransform(translationX: 0, y: 32)

            self.addCircleInner.setImage(
                UIImage(systemName: "plus", withConfiguration: iconCfg), for: .normal)
        }

        if animated {
            UIView.animate(withDuration: 0.35, delay: 0,
                           usingSpringWithDamping: 0.80, initialSpringVelocity: 0.3,
                           animations: block)
        } else {
            block()
        }
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewControllers?.forEach { vc in
            if vc.view.frame != view.bounds {
                vc.view.frame = view.bounds
            }
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard pillBottomConstraint != nil else { return }
        let deviceSafe = max(0, view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom)
        let c = -(deviceSafe + 14)
        pillBottomConstraint.constant   = c
        addBtnBottomConstraint.constant = c
        gridBottomConstraint.constant   = c
    }

    // MARK: - Theme

    @objc private func onSchemeChanged() {
        let accent = DayPinDesign.accent
        pillBar.refresh(accent: accent)
        refreshGrid()

        let navApp = DayPinDesign.makeNavBarAppearance()
        viewControllers?.compactMap { $0 as? UINavigationController }.forEach { nav in
            nav.navigationBar.standardAppearance   = navApp
            nav.navigationBar.scrollEdgeAppearance = navApp
            nav.navigationBar.compactAppearance    = navApp
            nav.navigationBar.tintColor            = accent
            nav.navigationBar.setNeedsLayout()
            nav.navigationBar.layoutIfNeeded()
        }
    }
}

// MARK: - UITabBarControllerDelegate

extension MainContainerViewController: UITabBarControllerDelegate {
    func tabBarController(_ tc: UITabBarController, didSelect vc: UIViewController) {
        pillBar.select(index: tc.selectedIndex, accent: DayPinDesign.accent)
        if isGridOpen { closeGrid(animated: true) }
    }
}
