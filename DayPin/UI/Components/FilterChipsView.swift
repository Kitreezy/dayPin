import UIKit

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
    }

    var onFilterChange: ((Filter) -> Void)?
    private(set) var selectedFilter: Filter = .all

    private let scrollView = UIScrollView()
    private let stack      = UIStackView()
    private let indicator  = UIView()
    private var buttons: [Filter: UIButton] = [:]
    private var counts:  [Filter: Int]      = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil
        )
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

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

        stack.axis    = .horizontal
        stack.spacing = 22
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
            let btn = makeButton(filter)
            stack.addArrangedSubview(btn)
            buttons[filter] = btn
        }

        // Sliding underline
        indicator.backgroundColor = DayPinDesign.accent
        indicator.layer.cornerRadius = 1
        addSubview(indicator)

        refreshAllButtons()
    }

    private func makeButton(_ filter: Filter) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(filter.title, for: .normal)
        btn.titleLabel?.font = .inter(ofSize: 15, weight: .regular)
        btn.setTitleColor(.secondaryLabel, for: .normal)
        btn.tag = Filter.allCases.firstIndex(of: filter) ?? 0
        btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - Interaction

    @objc private func tabTapped(_ sender: UIButton) {
        let filter = Filter.allCases[sender.tag]
        guard filter != selectedFilter else { return }
        selectedFilter = filter
        refreshAllButtons()
        moveIndicator(animated: true)
        onFilterChange?(filter)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        scrollToReveal(filter)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        moveIndicator(animated: false)
    }

    private func moveIndicator(animated: Bool) {
        guard let btn = buttons[selectedFilter], btn.frame.width > 0 else { return }
        let btnInSelf = convert(btn.frame, from: stack)
        let target = CGRect(x: btnInSelf.minX, y: bounds.height - 2, width: btnInSelf.width, height: 2)
        let block = { self.indicator.frame = target }
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0,
                           usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3,
                           animations: block)
        } else {
            block()
        }
    }

    private func scrollToReveal(_ filter: Filter) {
        guard let btn = buttons[filter] else { return }
        let rect = scrollView.convert(btn.frame, from: stack)
        scrollView.scrollRectToVisible(rect.insetBy(dx: -20, dy: 0), animated: true)
    }

    // MARK: - Appearance

    private func refreshAllButtons() {
        for filter in Filter.allCases { refreshButton(filter) }
    }

    private func refreshButton(_ filter: Filter) {
        guard let btn = buttons[filter] else { return }
        let isSelected = filter == selectedFilter
        let count      = counts[filter] ?? 0
        let weight: UIFont.Weight = isSelected ? .semibold : .regular
        let titleColor: UIColor   = isSelected ? .label : .secondaryLabel

        if count > 0 {
            let str = NSMutableAttributedString(
                string: filter.title,
                attributes: [
                    .font: UIFont.inter(ofSize: 15, weight: weight),
                    .foregroundColor: titleColor
                ]
            )
            str.append(NSAttributedString(
                string: "  \(count)",
                attributes: [
                    .font: UIFont.inter(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.tertiaryLabel
                ]
            ))
            UIView.performWithoutAnimation {
                btn.setAttributedTitle(str, for: .normal)
                btn.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation {
                btn.setAttributedTitle(nil, for: .normal)
                btn.setTitle(filter.title, for: .normal)
                btn.setTitleColor(titleColor, for: .normal)
                btn.titleLabel?.font = .inter(ofSize: 15, weight: weight)
                btn.layoutIfNeeded()
            }
        }
    }

    @objc private func onSchemeChanged() {
        indicator.backgroundColor = DayPinDesign.accent
        refreshAllButtons()
    }

    // MARK: - Public API

    func reset() {
        selectedFilter = .all
        refreshAllButtons()
        setNeedsLayout()
    }

    func updateCounts(text: Int, image: Int, link: Int) {
        let total = text + image + link
        counts = [.all: total, .text: text, .image: image, .link: link]
        refreshAllButtons()
        setNeedsLayout()
    }
}
