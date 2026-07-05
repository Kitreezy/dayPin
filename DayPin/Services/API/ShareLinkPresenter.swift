import UIKit

// MARK: - ShareLinkPresenter
// Shared entry point for "Share via Link" actions across card/folder screens.
// Handles the auth check, network call, and result presentation so each
// view controller only needs a single call site.

@MainActor
enum ShareLinkPresenter {

    static func shareCard(_ card: NoteCard, from vc: UIViewController) {
        guard AuthService.shared.isLoggedIn else {
            promptSignIn(from: vc)
            return
        }
        Task {
            do {
                let response = try await ShareService.shared.createCardShare(card: card, expiresInDays: nil)
                present(url: response.url, from: vc)
            } catch {
                GlassAlert.show(in: vc, title: L10n.shareLinkFailedTitle, message: error.localizedDescription)
            }
        }
    }

    static func shareCollection(title: String, cards: [NoteCard], folder: Folder?, from vc: UIViewController) {
        guard AuthService.shared.isLoggedIn else {
            promptSignIn(from: vc)
            return
        }
        Task {
            do {
                let response = try await ShareService.shared.createCollectionShare(
                    title: title, cards: cards, folder: folder, expiresInDays: nil
                )
                present(url: response.url, from: vc)
            } catch {
                GlassAlert.show(in: vc, title: L10n.shareLinkFailedTitle, message: error.localizedDescription)
            }
        }
    }

    // MARK: - Private

    private static func promptSignIn(from vc: UIViewController) {
        GlassAlert.confirm(
            in: vc,
            title: L10n.signInRequiredTitle,
            message: L10n.signInRequiredMessage,
            confirmTitle: L10n.signIn,
            isDestructive: false
        ) {
            let signIn = SignInViewController()
            let nav = UINavigationController(rootViewController: signIn)
            nav.modalPresentationStyle = .pageSheet
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            vc.present(nav, animated: true)
        }
    }

    private static func present(url: String, from vc: UIViewController) {
        UIPasteboard.general.string = url
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.present(activity, animated: true)
    }
}
