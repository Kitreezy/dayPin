import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = DayPinWindow(windowScene: windowScene)
        let rootVC = MainContainerViewController()
        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.window = window
        ThemeManager.shared.apply()
        _ = NetworkActivityHUD.shared

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenCard(_:)),
            name: NSNotification.Name("daypin.openCard"),
            object: nil
        )

        if let url = connectionOptions.urlContexts.first?.url {
            handleURL(url)
        }
    }

    // MARK: - URL scheme (widget deep links + shared content)

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleURL(url)
    }

    private func openSharedContent(shareID: String) {
        guard let root = window?.rootViewController else { return }
        let presenter = root.presentedViewController ?? root
        let vc = SharedContentViewController(shareID: shareID)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        presenter.present(nav, animated: true)
    }

    // MARK: - Background push
    // Best-effort backup on backgrounding so a signed-in user's data isn't
    // lost if they never remember to tap "Push" manually. SyncService.push()
    // skips the network call entirely if local content hasn't changed since
    // the last successful push, so this is cheap to call on every single
    // backgrounding - it won't hammer the server's limited free-tier storage
    // with redundant re-uploads of an unchanged backup.

    func sceneDidEnterBackground(_ scene: UIScene) {
        performBackgroundPush()
    }

    private func performBackgroundPush() {
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "daypin.backgroundPush") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        Task { @MainActor in
            defer {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
            guard AuthService.shared.isLoggedIn else { return }
            _ = await SyncService.shared.push()
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "daypin" else { return }

        switch url.host {

        case "today":
            (window?.rootViewController as? MainContainerViewController)?.selectedIndex = 0

        case "add":
            (window?.rootViewController as? MainContainerViewController)?.selectedIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: NSNotification.Name("daypin.triggerAdd"), object: nil)
            }

        case "open":
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let cardIDStr = components.queryItems?.first(where: { $0.name == "cardID" })?.value,
                let cardID = UUID(uuidString: cardIDStr)
            else { return }
            openCardByID(cardID)

        case "s":
            // daypin://s/<shareID> - opened from the "Open in DayPin" button
            // on the server's share page (used instead of Universal Links,
            // which require a paid Apple Developer account we don't have).
            let shareID = url.lastPathComponent
            guard !shareID.isEmpty else { return }
            openSharedContent(shareID: shareID)

        default:
            break
        }
    }

    // MARK: - Deep link: open card from notification tap or widget

    @objc private func handleOpenCard(_ note: Notification) {
        guard
            let cardIDString = note.userInfo?["cardID"] as? String,
            let cardID = UUID(uuidString: cardIDString)
        else { return }
        openCardByID(cardID)
    }

    private func openCardByID(_ cardID: UUID) {
        guard
            let card = CardStore.shared.allCards().first(where: { $0.id == cardID }),
            let container = window?.rootViewController as? MainContainerViewController,
            let navVC = container.selectedViewController as? UINavigationController
        else { return }

        container.selectedIndex = 0
        navVC.popToRootViewController(animated: false)

        let detailVC: UIViewController
        switch card.type {
        case .text:
            guard let text = card as? TextCard else { return }
            detailVC = CardDetailViewController(card: text)
        case .image:
            guard let image = card as? ImageCard else { return }
            detailVC = ImageCardOverviewViewController(card: image)
        case .link:
            guard let link = card as? LinkCard else { return }
            detailVC = LinkCardDetailViewController(card: link)
        }
        navVC.pushViewController(detailVC, animated: true)
    }
}
