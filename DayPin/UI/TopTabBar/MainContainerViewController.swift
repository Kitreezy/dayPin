import UIKit

final class MainContainerViewController: UIViewController {

    private lazy var tabs = [L10n.tabToday, L10n.tabCalendar, L10n.tabAll]
    private lazy var tabBar = TopTabBarView(tabs: tabs)

    private lazy var pageVC = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )

    private lazy var pages: [UINavigationController] = {
        let today    = makeNav(TodayViewController())
        let calendar = makeNav(CalendarViewController())
        let tasks    = makeNav(TasksViewController())
        return [today, calendar, tasks]
    }()

    private func makeNav(_ root: UIViewController) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        nav.navigationBar.isHidden = true
        nav.delegate = self
        return nav
    }

    private var tabBarHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupTabBar()
        setupPageViewController()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        tabBarHeightConstraint?.constant = view.safeAreaInsets.top + 44 + 0.5
    }

    // MARK: - Layout

    private func setupTabBar() {
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)

        let h = view.safeAreaInsets.top + 44 + 0.5
        let hc = tabBar.heightAnchor.constraint(equalToConstant: h)
        tabBarHeightConstraint = hc

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc
        ])
    }

    private func setupPageViewController() {
        addChild(pageVC)
        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageVC.view)
        pageVC.didMove(toParent: self)
        pageVC.dataSource = self
        pageVC.delegate = self

        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        pageVC.setViewControllers([pages[0]], direction: .forward, animated: false)
        view.bringSubviewToFront(tabBar)
    }

    // MARK: - Page swipe control

    /// Called by child nav controllers when push/pop happens.
    /// Disables pageVC swipe so it doesn't conflict with nav swipe-back.
    func setPageSwipeEnabled(_ enabled: Bool) {
        pageVC.view.gestureRecognizers?.forEach { $0.isEnabled = enabled }
        tabBar.isUserInteractionEnabled = enabled
    }
}

// MARK: - TopTabBarDelegate

extension MainContainerViewController: TopTabBarDelegate {
    func topTabBar(_ tabBar: TopTabBarView, didSelectIndex index: Int) {
        let current = pages.firstIndex(where: { pageVC.viewControllers?.first === $0 }) ?? 0
        guard index != current else { return }
        let dir: UIPageViewController.NavigationDirection = index > current ? .forward : .reverse
        pageVC.setViewControllers([pages[index]], direction: dir, animated: true)
    }
}

// MARK: - UIPageViewController DS + Delegate

extension MainContainerViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: vc as! UINavigationController), i > 0 else { return nil }
        return pages[i - 1]
    }

    func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: vc as! UINavigationController), i < pages.count - 1 else { return nil }
        return pages[i + 1]
    }

    func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let cur = pvc.viewControllers?.first as? UINavigationController,
              let i = pages.firstIndex(of: cur) else { return }
        tabBar.select(index: i, animated: true)
    }
}

// MARK: - UINavigationControllerDelegate
// Disable page-swipe while any nav has a pushed VC

extension MainContainerViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        let isPushed = navigationController.viewControllers.count > 1
        setPageSwipeEnabled(!isPushed)
    }
}
