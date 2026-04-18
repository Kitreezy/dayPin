import UIKit

extension UIViewController {
    /// Presents a text or link editor as a bottom sheet (medium → large detent).
    func presentEditorSheet(_ editor: UIViewController) {
        let nav = UINavigationController(rootViewController: editor)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        present(nav, animated: true)
    }
}
