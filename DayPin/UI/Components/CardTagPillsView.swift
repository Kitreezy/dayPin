import UIKit

/// A compact horizontal row of tag color-dot + name pills.
/// Designed to sit at the bottom of any card cell.
/// Shows at most `maxVisible` tags, then a "+N" overflow chip.
final class CardTagPillsView: UIView {

    var maxVisible: Int = 3

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public

    /// Pass the tag IDs stored on the card. Resolves names and colors from TagStore.
    func configure(tagIDs: [UUID], style: Style = .light) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let tags = tagIDs.compactMap { TagStore.shared.tag(for: $0) }
        guard !tags.isEmpty else {
            isHidden = true
            return
        }
        isHidden = false

        let visible = Array(tags.prefix(maxVisible))
        for tag in visible {
            stack.addArrangedSubview(makePill(tag: tag, style: style))
        }

        let overflow = tags.count - visible.count
        if overflow > 0 {
            stack.addArrangedSubview(makeOverflow(count: overflow, style: style))
        }
    }

    // MARK: - Private builders

    private func makePill(tag: Tag, style: Style) -> UIView {
        let dot = UIView()
        dot.backgroundColor = tag.color
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let label = UILabel()
        label.text = tag.name
        label.font = .inter(ofSize: 10, weight: .medium)
        label.textColor = style == .light ? UIColor.secondaryLabel : UIColor.white.withAlphaComponent(0.75)

        let row = UIStackView(arrangedSubviews: [dot, label])
        row.axis = .horizontal
        row.spacing = 4
        row.alignment = .center

        let pill = UIView()
        pill.layer.cornerRadius = 8
        pill.backgroundColor = style == .light
            ? tag.color.withAlphaComponent(0.12)
            : tag.color.withAlphaComponent(0.22)
        pill.translatesAutoresizingMaskIntoConstraints = false

        row.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: pill.topAnchor, constant: 3),
            row.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -3),
            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6)
        ])
        return pill
    }

    private func makeOverflow(count: Int, style: Style) -> UIView {
        let label = UILabel()
        label.text = "+\(count)"
        label.font = .inter(ofSize: 10, weight: .medium)
        label.textColor = style == .light ? UIColor.tertiaryLabel : UIColor.white.withAlphaComponent(0.5)

        let pill = UIView()
        pill.layer.cornerRadius = 8
        pill.backgroundColor = style == .light
            ? UIColor.tertiarySystemFill
            : UIColor.white.withAlphaComponent(0.10)
        pill.translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -6)
        ])
        return pill
    }

    // MARK: - Style

    enum Style {
        /// For glass cards with light/white background (TextCard, LinkCard)
        case light
        /// For dark/image cards (ImageCard)
        case dark
    }
}
