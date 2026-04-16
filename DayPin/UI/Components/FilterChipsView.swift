import UIKit

/// Horizontal scrollable chip filter bar.
/// Chips: All / Text / Image / Link
final class FilterChipsView: UIView {

    enum Filter: CaseIterable {
        case all, text, image, link

        var title: String {
            switch self {
            case .all:   return L10n.filterAll
            case .text:  return L10n.filterText
            case .image: return L10n.filterImage
            case .link:  return L10n.filterLink
            }
        }
        var icon: String {
            switch self {
            case .all:   return "square.grid.2x2"
            case .text:  return "text.alignleft"
            case .image: return "photo"
            case .link:  return "link"
            }
        }
    }

    var onFilterChange: ((Filter) -> Void)?
    private(set) var selectedFilter: Filter = .all

    private let scrollView = UIScrollView()
    private var buttons: [Filter: UIButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        for filter in Filter.allCases {
            let btn = makeChip(filter)
            stack.addArrangedSubview(btn)
            buttons[filter] = btn
        }

        updateSelection()
    }

    private func makeChip(_ filter: Filter) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        btn.setImage(UIImage(systemName: filter.icon, withConfiguration: cfg), for: .normal)
        btn.setTitle(filter.title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        btn.contentEdgeInsets = UIEdgeInsets(top: 7, left: 13, bottom: 7, right: 13)
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.tag = Filter.allCases.firstIndex(of: filter) ?? 0
        btn.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func chipTapped(_ sender: UIButton) {
        let filter = Filter.allCases[sender.tag]
        guard filter != selectedFilter else { return }
        selectedFilter = filter
        updateSelection()
        onFilterChange?(filter)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func updateSelection() {
        for (filter, btn) in buttons {
            let selected = filter == selectedFilter
            UIView.animate(withDuration: 0.18) {
                btn.backgroundColor = selected
                    ? DayPinDesign.accent
                    : UIColor.secondarySystemFill
                btn.tintColor  = selected ? .white : .secondaryLabel
                btn.setTitleColor(selected ? .white : .secondaryLabel, for: .normal)
            }
        }
    }

    func reset() {
        selectedFilter = .all
        updateSelection()
    }
}
