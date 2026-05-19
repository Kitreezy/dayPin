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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenCard(_:)),
            name: NSNotification.Name("daypin.openCard"),
            object: nil
        )

        // Handle URL if app was cold-launched from a widget tap
        if let url = connectionOptions.urlContexts.first?.url {
            handleURL(url)
        }
    }

    // MARK: - URL scheme (widget deep links)

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleURL(url)
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "daypin" else { return }

        switch url.host {

        case "today":
            // Switch to Today tab (index 0)
            (window?.rootViewController as? MainContainerViewController)?.selectedIndex = 0

        case "add":
            // Switch to Today tab and broadcast intent to show add sheet
            (window?.rootViewController as? MainContainerViewController)?.selectedIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: NSNotification.Name("daypin.triggerAdd"), object: nil)
            }

        case "open":
            // Open a specific card: daypin://open?cardID=<UUID>
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let cardIDStr  = components.queryItems?.first(where: { $0.name == "cardID" })?.value,
                let cardID     = UUID(uuidString: cardIDStr)
            else { return }
            openCardByID(cardID)

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

        // Switch to Today tab so the back stack is correct
        container.selectedIndex = 0

        // Pop to root so we don't stack duplicate detail VCs
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
