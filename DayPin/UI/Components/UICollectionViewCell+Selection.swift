import UIKit

extension UICollectionViewCell {

    private static let overlayTag = 88881

    /// Показывает/скрывает чекбокс в правом верхнем углу ячейки.
    func applySelectionOverlay(isSelecting: Bool, isSelected: Bool) {
        // Удаляем старый оверлей
        contentView.viewWithTag(Self.overlayTag)?.removeFromSuperview()
        guard isSelecting else { return }

        let circle = UIView()
        circle.tag = Self.overlayTag
        circle.layer.cornerRadius = 11
        circle.layer.masksToBounds = true
        circle.isUserInteractionEnabled = false
        circle.translatesAutoresizingMaskIntoConstraints = false

        if isSelected {
            circle.backgroundColor = DayPinDesign.accent
            circle.layer.borderWidth = 0

            let cfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            let check = UIImageView(image: UIImage(systemName: "checkmark", withConfiguration: cfg))
            check.tintColor = UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }
            check.contentMode = .scaleAspectFit
            check.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(check)
            NSLayoutConstraint.activate([
                check.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                check.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
                check.widthAnchor.constraint(equalToConstant: 11),
                check.heightAnchor.constraint(equalToConstant: 11)
            ])
        } else {
            circle.backgroundColor = UIColor { trait in UIColor.black.withAlphaComponent(0.30) }
            circle.layer.borderWidth = 1.5
            circle.layer.borderColor = UIColor { trait in UIColor.white.withAlphaComponent(0.8) }.cgColor
        }

        contentView.addSubview(circle)
        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            circle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            circle.widthAnchor.constraint(equalToConstant: 22),
            circle.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
}
