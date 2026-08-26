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
    /// Called when the user taps a tag chip. `nil` means "no tag filter".
    var onTagFilterChange: ((UUID?) -> Void)?

    private(set) var selectedFilter: Filter = .all
    private(set) var selectedTagID: UUID? = nil

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let indicator = UIView()
    private var buttons: [Filter: UIButton] = [:]
    private var counts:  [Filter: Int] = [:]

    // MARK: - Tag chips row

    private let tagScrollView = UIScrollView()
    private let tagStack = UIStackView()
    private var tagButtons: [UUID: UIButton] = [:]
    private var tagHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupTagRow()
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil
        )
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup (type filters)

    private func setup() {
        backgroundColor = .clear

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 38)
        ])

        stack.axis = .horizontal
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

    // MARK: - Setup (tag chips row)

    private func setupTagRow() {
        tagScrollView.showsHorizontalScrollIndicator = false
        tagScrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tagScrollView)

        tagStack.axis = .horizontal
        tagStack.spacing = 8
        tagStack.alignment = .center
        tagStack.translatesAutoresizingMaskIntoConstraints = false
        tagScrollView.addSubview(tagStack)

        let heightConstraint = tagScrollView.heightAnchor.constraint(equalToConstant: 0)
        tagHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            tagScrollView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 0),
            tagScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tagScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tagScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint,

            tagStack.topAnchor.constraint(equalTo: tagScrollView.topAnchor),
            tagStack.bottomAnchor.constraint(equalTo: tagScrollView.bottomAnchor),
            tagStack.leadingAnchor.constraint(equalTo: tagScrollView.leadingAnchor, constant: 16),
            tagStack.trailingAnchor.constraint(equalTo: tagScrollView.trailingAnchor, constant: -16),
            tagStack.heightAnchor.constraint(equalTo: tagScrollView.heightAnchor)
        ])
    }

    private func makeTagChip(tag: Tag) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.layer.cornerRadius = 12
        btn.clipsToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

        // Dot + label
        let dot = UIView()
        dot.backgroundColor = tag.color
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let label = UILabel()
        label.text = tag.name
        label.font = .inter(ofSize: 12, weight: .medium)

        let row = UIStackView(arrangedSubviews: [dot, label])
        row.axis = .horizontal
        row.spacing = 5
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            row.topAnchor.constraint(equalTo: btn.topAnchor, constant: 5),
            row.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -5),
            row.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -10)
        ])

        refreshTagChip(btn, tag: tag)
        return btn
    }

    private func refreshTagChip(_ btn: UIButton, tag: Tag) {
        let isSelected = selectedTagID == tag.id
        let label = btn.subviews
            .compactMap { $0 as? UIStackView }.first?
            .arrangedSubviews.compactMap { $0 as? UILabel }.first
        if isSelected {
            btn.backgroundColor = tag.color.withAlphaComponent(0.22)
            btn.layer.borderWidth = 1.5
            btn.layer.borderColor = tag.color.cgColor
            label?.textColor = .label
        } else {
            btn.backgroundColor = UIColor.tertiarySystemFill
            btn.layer.borderWidth = 0
            label?.textColor = .secondaryLabel
        }
    }

    @objc private func tagChipTapped(_ sender: UIButton) {
        guard let tagID = tagButtons.first(where: { $0.value === sender })?.key,
              let tag = TagStore.shared.tag(for: tagID) else { return }
        let newSelection: UUID? = selectedTagID == tag.id ? nil : tag.id
        selectedTagID = newSelection
        refreshAllTagChips()
        onTagFilterChange?(newSelection)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func refreshAllTagChips() {
        for (id, btn) in tagButtons {
            guard let tag = TagStore.shared.tag(for: id) else { continue }
            refreshTagChip(btn, tag: tag)
        }
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
        // Indicator sits at the bottom of the type-filter scroll row (38pt)
        let target = CGRect(x: btnInSelf.minX, y: 36, width: btnInSelf.width, height: 2)
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
        let count = counts[filter] ?? 0
        let weight: UIFont.Weight = isSelected ? .semibold : .regular
        let titleColor: UIColor = isSelected ? .label : .secondaryLabel

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
        refreshAllTagChips()
    }

    @objc private func onLanguageChanged() {
        refreshAllButtons()
        setNeedsLayout()
    }

    // MARK: - Public API

    func reset() {
        selectedFilter = .all
        selectedTagID = nil
        refreshAllButtons()
        refreshAllTagChips()
        setNeedsLayout()
    }

    func updateCounts(text: Int, image: Int, link: Int) {
        let total = text + image + link
        counts = [.all: total, .text: text, .image: image, .link: link]
        refreshAllButtons()
        setNeedsLayout()
    }

    /// Rebuilds the tag chips row with the currently used tags.
    /// Pass IDs of all tags that appear on at least one card in the current context.
    func updateTags(_ tagIDs: [UUID]) {
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tagButtons.removeAll()

        let tags = tagIDs.compactMap { TagStore.shared.tag(for: $0) }
            .sorted { $0.name < $1.name }

        let hasContent = !tags.isEmpty
        let targetHeight: CGFloat = hasContent ? 32 : 0
        let topGap: CGFloat = hasContent ? 2 : 0

        // Update top constraint gap between type row and tag row
        if let existing = constraints.first(where: { ($0.firstItem as? UIScrollView) == tagScrollView && $0.firstAttribute == .top }) {
            existing.constant = topGap
        }

        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
            self.tagHeightConstraint?.constant = targetHeight
            self.superview?.layoutIfNeeded()
        }

        // If selected tag is no longer in the list, clear it
        if let sid = selectedTagID, !tagIDs.contains(sid) {
            selectedTagID = nil
            onTagFilterChange?(nil)
        }

        for tag in tags {
            let btn = makeTagChip(tag: tag)
            btn.addTarget(self, action: #selector(tagChipTapped(_:)), for: .touchUpInside)
            tagStack.addArrangedSubview(btn)
            tagButtons[tag.id] = btn
        }
    }
}
