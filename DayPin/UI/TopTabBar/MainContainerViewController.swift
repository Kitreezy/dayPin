import UIKit

final class MainContainerViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        ThemeManager.shared.apply()
    }

    private func setupTabs() {
        let today    = makeNav(root: TodayViewController(),    title: L10n.tabToday,    symbol: "sun.max")
        let calendar = makeNav(root: CalendarViewController(), title: L10n.tabCalendar, symbol: "calendar")
        let folders  = makeNav(root: FolderListViewController(), title: "Папки",        symbol: "folder")
        let all      = makeNav(root: TasksViewController(),    title: L10n.tabAll,      symbol: "tray.full")
        viewControllers = [today, calendar, folders, all]
    }

    private func makeNav(root: UIViewController, title: String, symbol: String) -> UINavigationController {
        root.title = title
        let nav = UINavigationController(rootViewController: root)
        nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: UIImage(systemName: "\(symbol).fill"))
        return nav
    }

    private func setupAppearance() {
        // ── Navigation Bar — Liquid Glass ──────────────────────────────────
        let navAppearance = DayPinDesign.makeNavBarAppearance()
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance    = navAppearance
        UINavigationBar.appearance().prefersLargeTitles   = false
        UINavigationBar.appearance().tintColor            = DayPinDesign.accent

        // ── Tab Bar — Liquid Glass ──────────────────────────────────────────
        let tabAppearance = DayPinDesign.makeTabBarAppearance()
        UITabBar.appearance().standardAppearance      = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance    = tabAppearance
        UITabBar.appearance().tintColor               = DayPinDesign.accent
        UITabBar.appearance().unselectedItemTintColor = .secondaryLabel
    }
}
