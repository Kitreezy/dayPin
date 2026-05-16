import UIKit

// MARK: - Shared gradient background helper
//
// Call `addStandardBackground()` in viewDidLoad() instead of
// manually constructing GradientBackgroundView in each screen.

extension UIViewController {

    /// Inserts a full-screen GradientBackgroundView behind all other subviews.
    /// Safe to call multiple times — adds only once (checks for existing instance).
    func addStandardBackground() {
        guard !view.subviews.contains(where: { $0 is GradientBackgroundView }) else { return }
        let bg = GradientBackgroundView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bg, at: 0)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: view.topAnchor),
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

}
