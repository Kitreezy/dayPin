import UIKit

// MARK: - Staggered card appearance animation

extension UICollectionViewCell {

    /// Animates the cell into view with a fade + slide-up effect.
    /// Call from `collectionView(_:willDisplay:forItemAt:)`.
    ///
    /// - Parameters:
    ///   - index: The flat item index used to calculate stagger delay (0-based).
    ///   - maxDelay: Cap so off-screen cells don't wait too long. Default 0.4 s.
    func animateCardAppearance(at index: Int, maxDelay: Double = 0.4) {
        let delay = min(Double(index) * 0.05, maxDelay)
        let offset: CGFloat = 18

        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: offset)

        UIView.animate(
            withDuration: 0.38,
            delay: delay,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.4,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            self.alpha = 1
            self.transform = .identity
        }
    }
}
