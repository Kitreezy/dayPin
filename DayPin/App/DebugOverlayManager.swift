import UIKit

// MARK: - DayPinWindow
// DEBUG only — shake triggers the layout inspector.
// RELEASE — plain UIWindow, zero overhead.

#if DEBUG

final class DayPinWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            DebugOverlayManager.shared.toggle(in: self)
        }
    }
}

// MARK: - DebugOverlayManager

final class DebugOverlayManager {

    static let shared = DebugOverlayManager()
    private init() {}

    private var overlayWindow: UIWindow?
    var isActive: Bool { overlayWindow != nil }

    func toggle(in window: UIWindow) {
        isActive ? hide() : show(in: window)
    }

    func show(in window: UIWindow) {
        guard !isActive, let scene = window.windowScene else { return }

        let topVC = Self.topVC(window.rootViewController)
        let vcName = topVC.map { String(describing: type(of: $0)) } ?? "Unknown"
        // Walk the VC and its custom subviews via Mirror to build a property-name → UIView map
        var nameMap: [ObjectIdentifier: String] = [:]
        if let vc = topVC { nameMap = Self.buildNameMap(for: vc) }

        let overlayWin = UIWindow(windowScene: scene)
        overlayWin.windowLevel = .statusBar + 200
        overlayWin.backgroundColor = .clear
        overlayWin.rootViewController = DebugOverlayViewController(
            sourceWindow: window,
            vcName:       vcName,
            nameMap:      nameMap
        )
        overlayWin.isHidden = false
        self.overlayWindow = overlayWin

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func hide() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: Helpers

    static func topVC(_ root: UIViewController?) -> UIViewController? {
        guard let root else { return nil }
        if let nav = root as? UINavigationController { return topVC(nav.visibleViewController) }
        if let tab = root as? UITabBarController     { return topVC(tab.selectedViewController) }
        if let pr = root.presentedViewController    { return topVC(pr) }
        return root
    }

    /// Recursively enumerate stored properties via Mirror; recurses into custom UIView subclasses
    /// so nested views like PinCardView.titleLbl are resolved to their variable name.
    static func buildNameMap(for root: AnyObject) -> [ObjectIdentifier: String] {
        var map = [ObjectIdentifier: String]()
        var visited = Set<ObjectIdentifier>()
        scanProperties(of: root, map: &map, visited: &visited)
        return map
    }

    private static func scanProperties(
        of object: AnyObject,
        map:     inout [ObjectIdentifier: String],
        visited: inout Set<ObjectIdentifier>
    ) {
        let oid = ObjectIdentifier(object)
        guard !visited.contains(oid) else { return }
        visited.insert(oid)

        var mirror: Mirror? = Mirror(reflecting: object)
        while let m = mirror {
            for child in m.children {
                guard let raw = child.label else { continue }
                // Lazy-var backing storage appears as "_propName" in Mirror
                let name = raw.hasPrefix("_") ? String(raw.dropFirst()) : raw
                guard !name.isEmpty else { continue }

                if let view = child.value as? UIView {
                    let vid = ObjectIdentifier(view)
                    if map[vid] == nil { map[vid] = name }
                    let cls = String(describing: type(of: view))
                    if !cls.hasPrefix("UI") && !cls.hasPrefix("_UI") {
                        scanProperties(of: view, map: &map, visited: &visited)
                    }
                }
            }
            mirror = m.superclassMirror
        }
    }
}

// MARK: - DebugFilter

struct DebugFilter: Equatable {
    let id:    String
    let label: String
    let match: (UIView) -> Bool

    static func == (l: DebugFilter, r: DebugFilter) -> Bool { l.id == r.id }

    static let all: [DebugFilter] = [
        DebugFilter(id: "All",    label: "All",     match: { _ in true }),
        DebugFilter(id: "Label",  label: "Label",   match: { $0 is UILabel }),
        DebugFilter(id: "Button", label: "Button",  match: { $0 is UIButton }),
        DebugFilter(id: "Image",  label: "Image",   match: { $0 is UIImageView }),
        DebugFilter(id: "Input",  label: "Input",   match: { $0 is UITextField || $0 is UITextView }),
        DebugFilter(id: "Stack",  label: "Stack",   match: { $0 is UIStackView }),
        DebugFilter(id: "View",   label: "UIView",  match: { type(of: $0) == UIView.self }),
        DebugFilter(id: "Custom", label: "Custom",  match: {
            let c = String(describing: type(of: $0))
            return !c.hasPrefix("UI") && !c.hasPrefix("_UI")
        })
    ]
}

// MARK: - DebugOverlayViewController

private final class DebugOverlayViewController: UIViewController {

    private enum DebugMode { case layout, network }

    private let sourceWindow: UIWindow
    private let vcName:       String
    private let nameMap:      [ObjectIdentifier: String]

    private var mode: DebugMode = .layout

    private var canvas:          DebugCanvasView!
    private var filterBar:       UIView!
    private var networkVC:       NetworkLogViewController!
    private var filterChipStack: UIStackView?
    private var activeFilterIDs: Set<String> = ["All"]
    private var layoutModeButton:  ModeChipButton?
    private var networkModeButton: ModeChipButton?

    init(sourceWindow: UIWindow, vcName: String, nameMap: [ObjectIdentifier: String]) {
        self.sourceWindow = sourceWindow
        self.vcName = vcName
        self.nameMap = nameMap
        self.networkVC = NetworkLogViewController()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.10)
        buildUI()
    }

    // MARK: - Build UI

    private func buildUI() {
        canvas = DebugCanvasView(sourceWindow: sourceWindow, overlayView: view, nameMap: nameMap)
        canvas.isUserInteractionEnabled = false
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        let banner = makeBanner()
        let modeSwitcher = makeModeSwitcher()
        filterBar = makeFilterBar()
        let exitBtn = makeExitButton()
        let hint = makeHintLabel()

        addChild(networkVC)
        networkVC.view.translatesAutoresizingMaskIntoConstraints = false
        networkVC.view.isHidden = true
        networkVC.onSelectEntry = { [weak self] entry in
            let detail = NetworkLogDetailViewController(entry: entry)
            let nav = UINavigationController(rootViewController: detail)
            self?.present(nav, animated: true)
        }
        view.addSubview(networkVC.view)
        networkVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: modeSwitcher.bottomAnchor, constant: 8),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            networkVC.view.topAnchor.constraint(equalTo: modeSwitcher.bottomAnchor, constant: 8),
            networkVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            networkVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            networkVC.view.bottomAnchor.constraint(equalTo: exitBtn.topAnchor, constant: -10),

            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48),

            modeSwitcher.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 8),
            modeSwitcher.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 36),
            filterBar.bottomAnchor.constraint(equalTo: exitBtn.topAnchor, constant: -10),

            exitBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exitBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            exitBtn.heightAnchor.constraint(equalToConstant: 38),
            exitBtn.widthAnchor.constraint(equalToConstant: 148),

            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.topAnchor.constraint(equalTo: exitBtn.bottomAnchor, constant: 4)
        ])

        DispatchQueue.main.async { self.applyFilter() }
    }

    // MARK: - Mode switcher

    private func makeModeSwitcher() -> UIView {
        let layoutBtn = ModeChipButton(title: "Layout")
        let networkBtn = ModeChipButton(title: "Network")
        layoutBtn.isOn = true
        layoutBtn.addTarget(self, action: #selector(layoutModeTapped), for: .touchUpInside)
        networkBtn.addTarget(self, action: #selector(networkModeTapped), for: .touchUpInside)

        self.layoutModeButton = layoutBtn
        self.networkModeButton = networkBtn

        let stack = UIStackView(arrangedSubviews: [layoutBtn, networkBtn])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        return stack
    }

    @objc private func layoutModeTapped() { setMode(.layout) }
    @objc private func networkModeTapped() { setMode(.network) }

    private func setMode(_ newMode: DebugMode) {
        guard mode != newMode else { return }
        mode = newMode
        layoutModeButton?.isOn = (newMode == .layout)
        networkModeButton?.isOn = (newMode == .network)
        canvas.isHidden = (newMode != .layout)
        filterBar.isHidden = (newMode != .layout)
        networkVC.view.isHidden = (newMode != .network)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func makeBanner() -> UIView {
        let outer = UIView()
        outer.layer.cornerRadius = 16
        outer.layer.shadowColor = UIColor.black.cgColor
        outer.layer.shadowOpacity = 0.30
        outer.layer.shadowRadius = 8
        outer.layer.shadowOffset = CGSize(width: 0, height: 3)
        outer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outer)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.layer.cornerRadius = 16
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: outer.topAnchor),
            blur.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: outer.bottomAnchor)
        ])

        let tint = UIView()
        tint.backgroundColor = UIColor(red: 0.25, green: 0.06, blue: 0.60, alpha: 0.58)
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        let dot = UIView()
        dot.backgroundColor = UIColor(red: 0.72, green: 0.45, blue: 1.0, alpha: 1)
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let nameLabel = UILabel()
        nameLabel.text = vcName
        nameLabel.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeLbl = UILabel()
        badgeLbl.text = "DEBUG"
        badgeLbl.font = .monospacedSystemFont(ofSize: 8, weight: .semibold)
        badgeLbl.textColor = UIColor(red: 0.80, green: 0.55, blue: 1.0, alpha: 1)
        badgeLbl.translatesAutoresizingMaskIntoConstraints = false

        let badge = UIView()
        badge.backgroundColor = UIColor(red: 0.72, green: 0.45, blue: 1.0, alpha: 0.22)
        badge.layer.cornerRadius = 4
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeLbl)
        NSLayoutConstraint.activate([
            badgeLbl.topAnchor.constraint(equalTo: badge.topAnchor,          constant: 2),
            badgeLbl.leadingAnchor.constraint(equalTo: badge.leadingAnchor,  constant: 5),
            badgeLbl.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -5),
            badgeLbl.bottomAnchor.constraint(equalTo: badge.bottomAnchor,    constant: -2)
        ])

        let row = UIStackView(arrangedSubviews: [dot, nameLabel, badge])
        row.axis = .horizontal
        row.spacing = 7
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: blur.contentView.topAnchor,       constant: 9),
            row.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -9),
            row.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor,  constant: 14),
            row.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -14)
        ])

        return outer
    }

    private func makeFilterBar() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        for filter in DebugFilter.all {
            let chip = FilterChipButton(filter: filter)
            chip.isOn = (filter.id == "All")
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(chip)
        }

        filterChipStack = stack
        return scroll
    }

    private func makeExitButton() -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle("✕  Exit Debug", for: .normal)
        btn.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        btn.layer.cornerRadius = 19
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.28
        btn.layer.shadowRadius = 6
        btn.layer.shadowOffset = CGSize(width: 0, height: 3)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        view.addSubview(btn)
        return btn
    }

    private func makeHintLabel() -> UILabel {
        let l = UILabel()
        l.text = "shake again to exit"
        l.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.40)
        l.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(l)
        return l
    }

    // MARK: - Filter logic

    @objc private func chipTapped(_ sender: FilterChipButton) {
        let id = sender.filter.id

        if id == "All" {
            activeFilterIDs = ["All"]
        } else {
            activeFilterIDs.remove("All")
            if activeFilterIDs.contains(id) {
                activeFilterIDs.remove(id)
                if activeFilterIDs.isEmpty { activeFilterIDs = ["All"] }
            } else {
                activeFilterIDs.insert(id)
            }
        }

        filterChipStack?.arrangedSubviews
            .compactMap { $0 as? FilterChipButton }
            .forEach { $0.isOn = activeFilterIDs.contains($0.filter.id) }

        applyFilter()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func applyFilter() {
        let active = DebugFilter.all.filter { activeFilterIDs.contains($0.id) }
        canvas.populate(matching: active)
    }

    // MARK: - Actions

    @objc private func exitTapped() { DebugOverlayManager.shared.hide() }

    override var canBecomeFirstResponder: Bool { true }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); becomeFirstResponder() }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { DebugOverlayManager.shared.hide() }
    }
}

// MARK: - FilterChipButton

private final class FilterChipButton: UIButton {

    let filter: DebugFilter
    var isOn: Bool = false { didSet { updateAppearance() } }

    private static let onBg = UIColor.white.withAlphaComponent(0.92)
    private static let offBg = UIColor.white.withAlphaComponent(0.12)
    private static let onText = UIColor(red: 0.30, green: 0.10, blue: 0.70, alpha: 1)
    private static let offText = UIColor.white

    init(filter: DebugFilter) {
        self.filter = filter
        super.init(frame: .zero)
        setTitle(filter.label, for: .normal)
        titleLabel?.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateAppearance() {
        backgroundColor = isOn ? Self.onBg   : Self.offBg
        setTitleColor(isOn ? Self.onText : Self.offText, for: .normal)
        layer.borderColor = isOn
            ? UIColor.white.cgColor
            : UIColor.white.withAlphaComponent(0.30).cgColor
    }
}

// MARK: - ModeChipButton
// Layout / Network toggle at the top of the shake-debug overlay.

private final class ModeChipButton: UIButton {

    var isOn: Bool = false { didSet { updateAppearance() } }

    private static let onBg = UIColor(red: 0.72, green: 0.45, blue: 1.0, alpha: 0.90)
    private static let offBg = UIColor.white.withAlphaComponent(0.12)
    private static let onText = UIColor.white
    private static let offText = UIColor.white.withAlphaComponent(0.65)

    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateAppearance() {
        backgroundColor = isOn ? Self.onBg   : Self.offBg
        setTitleColor(isOn ? Self.onText : Self.offText, for: .normal)
        layer.borderColor = isOn
            ? UIColor.white.cgColor
            : UIColor.white.withAlphaComponent(0.30).cgColor
    }
}

// MARK: - DebugCanvasView

private final class DebugCanvasView: UIView {

    private let sourceWindow: UIWindow
    private let overlayView:  UIView
    private let nameMap:      [ObjectIdentifier: String]

    private let palette: [UIColor] = [
        .systemBlue, .systemGreen, .systemOrange,
        .systemPink, UIColor(red: 0, green: 0.80, blue: 0.75, alpha: 1),
        .systemYellow, .systemPurple, .systemIndigo
    ]

    init(sourceWindow: UIWindow, overlayView: UIView, nameMap: [ObjectIdentifier: String]) {
        self.sourceWindow = sourceWindow
        self.overlayView = overlayView
        self.nameMap = nameMap
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    func populate(matching filters: [DebugFilter]) {
        subviews.forEach { $0.removeFromSuperview() }
        var depth = 0
        for sub in sourceWindow.subviews {
            walk(sub, depth: &depth, filters: filters)
        }
    }

    private func walk(_ v: UIView, depth: inout Int, filters: [DebugFilter]) {
        guard v !== overlayView,
              !v.isHidden,
              v.alpha > 0.02,
              v.bounds.width >= 8 || v.bounds.height >= 8
        else { return }

        let frame = v.convert(v.bounds, to: self)
        guard !frame.isNull,
              frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.size.width.isFinite, frame.size.height.isFinite
        else { return }

        if filters.contains(where: { $0.match(v) }) {
            let color = palette[depth % palette.count]

            let box = UIView(frame: frame)
            box.backgroundColor = color.withAlphaComponent(0.05)
            box.layer.borderColor = color.withAlphaComponent(0.60).cgColor
            box.layer.borderWidth = 1
            box.isUserInteractionEnabled = false
            addSubview(box)

            let lbl = DebugLabel()
            lbl.text = labelText(for: v)
            lbl.font = .monospacedSystemFont(ofSize: 7, weight: .medium)
            lbl.textColor = color
            lbl.backgroundColor = UIColor.black.withAlphaComponent(0.62)
            lbl.layer.cornerRadius = 2
            lbl.clipsToBounds = true
            lbl.isUserInteractionEnabled = false
            lbl.sizeToFit()
            let ox = min(max(frame.minX + 2, 2), bounds.width  - lbl.frame.width  - 2)
            let oy = min(max(frame.minY + 2, 2), bounds.height - lbl.frame.height - 2)
            lbl.frame.origin = CGPoint(x: ox, y: oy)
            addSubview(lbl)
        }

        depth += 1
        for sub in v.subviews { walk(sub, depth: &depth, filters: filters) }
        depth -= 1
    }

    private func labelText(for v: UIView) -> String {
        let cls = String(describing: type(of: v))
        if let name = nameMap[ObjectIdentifier(v)] { return "\(name) · \(cls)" }
        if let aid = v.accessibilityIdentifier, !aid.isEmpty { return "\(aid) · \(cls)" }
        return cls
    }
}

// MARK: - DebugLabel

private final class DebugLabel: UILabel {
    private let pad = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: pad)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + pad.left + pad.right,
                      height: s.height + pad.top + pad.bottom)
    }
    override func sizeToFit() { super.sizeToFit(); frame.size = intrinsicContentSize }
}

#else

typealias DayPinWindow = UIWindow

#endif
