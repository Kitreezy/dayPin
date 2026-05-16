import UIKit

protocol TopTabBarDelegate: AnyObject {
    func topTabBar(_ tabBar: TopTabBarView, didSelectIndex index: Int)
}

final class TopTabBarView: UIView {

    weak var delegate: TopTabBarDelegate?

    private(set) var selectedIndex: Int = 0

    private let tabs: [String]
    private var buttons: [UIButton] = []
    private let indicatorView = UIView()
    private let separatorView = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))

    // MARK: Init

    init(tabs: [String]) {
        self.tabs = tabs
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setup() {
        addSubview(blurView)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])

        for (i, title) in tabs.enumerated() {
            let btn = makeButton(title: title, tag: i)
            stack.addArrangedSubview(btn)
            buttons.append(btn)
        }

        // Indicator
        indicatorView.backgroundColor = .label
        indicatorView.layer.cornerRadius = 1.5
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicatorView)
        NSLayoutConstraint.activate([
            indicatorView.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
            indicatorView.heightAnchor.constraint(equalToConstant: 3)
        ])

        // Separator
        separatorView.backgroundColor = .separator
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)
        NSLayoutConstraint.activate([
            separatorView.topAnchor.constraint(equalTo: stack.bottomAnchor),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateSelection(animated: false)
    }

    private func makeButton(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.tag = tag
        btn.titleLabel?.font = .inter(ofSize: 15, weight: .medium)
        btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        return btn
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateIndicatorPosition(animated: false)
    }

    // MARK: Actions

    @objc private func tabTapped(_ sender: UIButton) {
        select(index: sender.tag, animated: true)
        delegate?.topTabBar(self, didSelectIndex: sender.tag)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func select(index: Int, animated: Bool) {
        selectedIndex = index
        updateSelection(animated: animated)
    }

    private func updateSelection(animated: Bool) {
        buttons.enumerated().forEach { i, btn in
            let isSelected = i == selectedIndex
            btn.tintColor = isSelected ? .label : .secondaryLabel
        }
        updateIndicatorPosition(animated: animated)
    }

    private func updateIndicatorPosition(animated: Bool) {
        guard !buttons.isEmpty, buttons[0].frame.width > 0 else { return }
        let tabWidth = bounds.width / CGFloat(tabs.count)
        let x = CGFloat(selectedIndex) * tabWidth
        let block = {
            self.indicatorView.frame = CGRect(x: x + 16, y: self.indicatorView.frame.origin.y, width: tabWidth - 32, height: 3)
        }
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3, animations: block)
        } else {
            block()
        }
    }

    var intrinsicContentHeight: CGFloat {
        return safeAreaInsets.top + 44 + 0.5
    }
}
