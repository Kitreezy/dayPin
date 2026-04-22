import UIKit

// MARK: - PillTabBar

private final class PillTabBar: UIView {

    var onSelect: ((Int) -> Void)?
    private(set) var selectedIndex = 0

    // Ultra-thin blur = maximum transparency
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
        // Shadow on self (clipsToBounds = false so shadow renders outside)
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius  = 20
        layer.shadowOffset  = CGSize(width: 0, height: 4)

        // Rounded blur pill
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

        // Accent tint overlay — sits between blur and buttons
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tintOverlay)
        NSLayoutConstraint.activate([
            tintOverlay.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        // Buttons in horizontal stack, on top of overlay
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
        // Icons
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
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

        // Tint overlay: base color blended with accent, low opacity
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

// MARK: - MainContainerViewController

final class MainContainerViewController: UITabBarController {

    private var pillBar: PillTabBar!
    private var pillBottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupNavBarAppearance()
        setupPillBar()
        // Extra bottom inset = pill height (60) + gap below pill (10) = 70
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

    // MARK: - Floating pill

    private func setupPillBar() {
        // Hide system tab bar — pill handles all visual + interaction
        tabBar.isHidden = true

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
        }
        view.addSubview(pillBar)

        // Initial constant — corrected in viewSafeAreaInsetsDidChange
        pillBottomConstraint = pillBar.bottomAnchor.constraint(
            equalTo: view.bottomAnchor, constant: -10
        )
        NSLayoutConstraint.activate([
            pillBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pillBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            pillBar.heightAnchor.constraint(equalToConstant: 60),
            pillBottomConstraint
        ])
    }

    // Ensure child views fill the full height when system tab bar is hidden
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewControllers?.forEach { vc in
            if vc.view.frame != view.bounds {
                vc.view.frame = view.bounds
            }
        }
    }

    // Called whenever safe area changes (including first layout and rotation)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard pillBottomConstraint != nil else { return }
        // view.safeAreaInsets.bottom = device safe area + additionalSafeAreaInsets.bottom
        // We only want the device portion for pill positioning
        let deviceSafe = max(0, view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom)
        pillBottomConstraint.constant = -(deviceSafe + 10)
    }

    // MARK: - Theme

    @objc private func onSchemeChanged() {
        let accent = DayPinDesign.accent
        pillBar.refresh(accent: accent)

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
    }
}
