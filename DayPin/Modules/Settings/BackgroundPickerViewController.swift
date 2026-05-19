import UIKit

// MARK: - BackgroundPickerViewController

final class BackgroundPickerViewController: UIViewController {

    // MARK: - State

    private var currentBg      = BackgroundManager.shared.current
    private var solidColor:    UIColor = .init(hex: "#1C1C1E") ?? .systemBackground
    private var gradStartColor: UIColor = .init(hex: "#6366F1") ?? .systemIndigo
    private var gradEndColor:   UIColor = .init(hex: "#8B5CF6") ?? .systemPurple
    private var gradAngle:      Float   = 135

    // MARK: - UI roots

    private let scrollView   = UIScrollView()
    private let contentView  = UIView()
    private let segmentCtrl  = UISegmentedControl(items: ["Default", "Color", "Gradient"])
    private let previewView  = GradientBackgroundView()
    private let applyBtn     = UIButton(type: .system)

    // Solid mode
    private let solidSection = UIView()
    private let colorSwatch  = UIButton()

    // Gradient mode
    private let gradSection  = UIView()
    private let startSwatch  = UIButton()
    private let endSwatch    = UIButton()
    private let angleSlider  = UISlider()
    private let angleLabel   = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.background
        view.backgroundColor = DayPinDesign.cardSurface
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeTapped))

        loadCurrentValues()
        buildUI()
        syncUI(animated: false)
        observeNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        title = L10n.background
        segmentCtrl.setTitle(L10n.bgStandard, forSegmentAt: 0)
        segmentCtrl.setTitle(L10n.bgColor,    forSegmentAt: 1)
        segmentCtrl.setTitle(L10n.bgGradient, forSegmentAt: 2)
        applyBtn.setTitle(L10n.apply, for: .normal)
    }

    @objc private func onColorSchemeChanged() {
        applyBtn.backgroundColor = DayPinDesign.accent
        angleSlider.tintColor = DayPinDesign.accent
    }

    // MARK: - Load current values

    private func loadCurrentValues() {
        switch currentBg {
        case .system: break
        case .solidColor(let hex):
            solidColor = UIColor(hex: hex) ?? solidColor
        case .gradient(let s, let e, let a):
            gradStartColor = UIColor(hex: s) ?? gradStartColor
            gradEndColor   = UIColor(hex: e) ?? gradEndColor
            gradAngle      = a
        }
        segmentCtrl.selectedSegmentIndex = {
            switch currentBg {
            case .system:     return 0
            case .solidColor: return 1
            case .gradient:   return 2
            }
        }()
    }

    // MARK: - Build UI

    private func buildUI() {
        // Segment
        segmentCtrl.setTitle(L10n.bgStandard, forSegmentAt: 0)
        segmentCtrl.setTitle(L10n.bgColor,    forSegmentAt: 1)
        segmentCtrl.setTitle(L10n.bgGradient, forSegmentAt: 2)
        segmentCtrl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentCtrl.translatesAutoresizingMaskIntoConstraints = false

        // Preview card
        let previewCard = UIView()
        previewCard.layer.cornerRadius  = 20
        previewCard.layer.masksToBounds = true
        previewCard.translatesAutoresizingMaskIntoConstraints = false
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewCard.addSubview(previewView)
        previewView.pinToEdges(of: previewCard)

        // Apply button
        applyBtn.setTitle(L10n.apply, for: .normal)
        applyBtn.titleLabel?.font    = .inter(ofSize: 17, weight: .semibold)
        applyBtn.backgroundColor     = DayPinDesign.accent
        applyBtn.setTitleColor(UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }, for: .normal)
        applyBtn.layer.cornerRadius  = 14
        applyBtn.translatesAutoresizingMaskIntoConstraints = false
        applyBtn.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)

        // Solid section
        buildSolidSection()

        // Gradient section
        buildGradientSection()

        // Scroll + content view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(applyBtn)
        scrollView.addSubview(contentView)

        for v in [segmentCtrl, previewCard, solidSection, gradSection] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
        }

        NSLayoutConstraint.activate([
            // Apply button — pinned at bottom
            applyBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            applyBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            applyBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            applyBtn.heightAnchor.constraint(equalToConstant: 52),

            // Scroll view fills above apply button
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: applyBtn.topAnchor, constant: -8),

            // Content view matches scroll width
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Segment
            segmentCtrl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            segmentCtrl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segmentCtrl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Preview
            previewCard.topAnchor.constraint(equalTo: segmentCtrl.bottomAnchor, constant: 20),
            previewCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewCard.heightAnchor.constraint(equalToConstant: 160),

            // Solid section
            solidSection.topAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: 24),
            solidSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            solidSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Gradient section
            gradSection.topAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: 24),
            gradSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            gradSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Content bottom = whichever section is visible + padding
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: solidSection.bottomAnchor, constant: 24),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: gradSection.bottomAnchor, constant: 24)
        ])
    }

    // MARK: - Solid section

    private func buildSolidSection() {
        solidSection.translatesAutoresizingMaskIntoConstraints = false

        let label = makeLabel(L10n.bgColorLabel)
        colorSwatch.backgroundColor    = solidColor
        colorSwatch.layer.cornerRadius = 12
        colorSwatch.layer.borderWidth  = 1
        colorSwatch.layer.borderColor  = UIColor.separator.cgColor
        colorSwatch.addTarget(self, action: #selector(pickSolidColor), for: .touchUpInside)
        colorSwatch.translatesAutoresizingMaskIntoConstraints = false

        solidSection.addSubview(label)
        solidSection.addSubview(colorSwatch)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: solidSection.topAnchor),
            label.leadingAnchor.constraint(equalTo: solidSection.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: colorSwatch.centerYAnchor),

            colorSwatch.topAnchor.constraint(equalTo: solidSection.topAnchor),
            colorSwatch.trailingAnchor.constraint(equalTo: solidSection.trailingAnchor),
            colorSwatch.widthAnchor.constraint(equalToConstant: 44),
            colorSwatch.heightAnchor.constraint(equalToConstant: 44),
            colorSwatch.bottomAnchor.constraint(equalTo: solidSection.bottomAnchor)
        ])
    }

    // MARK: - Gradient section

    private func buildGradientSection() {
        gradSection.translatesAutoresizingMaskIntoConstraints = false

        let startLabel = makeLabel(L10n.bgStartColor)
        startSwatch.backgroundColor    = gradStartColor
        startSwatch.layer.cornerRadius = 12
        startSwatch.layer.borderWidth  = 1
        startSwatch.layer.borderColor  = UIColor.separator.cgColor
        startSwatch.addTarget(self, action: #selector(pickStartColor), for: .touchUpInside)
        startSwatch.translatesAutoresizingMaskIntoConstraints = false

        let endLabel = makeLabel(L10n.bgEndColor)
        endSwatch.backgroundColor    = gradEndColor
        endSwatch.layer.cornerRadius = 12
        endSwatch.layer.borderWidth  = 1
        endSwatch.layer.borderColor  = UIColor.separator.cgColor
        endSwatch.addTarget(self, action: #selector(pickEndColor), for: .touchUpInside)
        endSwatch.translatesAutoresizingMaskIntoConstraints = false

        let angleTitle = makeLabel(L10n.bgAngle)
        angleLabel.font      = .inter(ofSize: 13)
        angleLabel.textColor = .secondaryLabel
        angleLabel.text      = "\(Int(gradAngle))°"
        angleLabel.translatesAutoresizingMaskIntoConstraints = false

        angleSlider.minimumValue = 0
        angleSlider.maximumValue = 360
        angleSlider.value        = gradAngle
        angleSlider.tintColor    = DayPinDesign.accent
        angleSlider.addTarget(self, action: #selector(angleChanged), for: .valueChanged)
        angleSlider.translatesAutoresizingMaskIntoConstraints = false

        [startLabel, startSwatch, endLabel, endSwatch,
         angleTitle, angleLabel, angleSlider].forEach { gradSection.addSubview($0) }

        NSLayoutConstraint.activate([
            // Start color row
            startLabel.topAnchor.constraint(equalTo: gradSection.topAnchor),
            startLabel.leadingAnchor.constraint(equalTo: gradSection.leadingAnchor),
            startLabel.centerYAnchor.constraint(equalTo: startSwatch.centerYAnchor),

            startSwatch.topAnchor.constraint(equalTo: gradSection.topAnchor),
            startSwatch.trailingAnchor.constraint(equalTo: gradSection.trailingAnchor),
            startSwatch.widthAnchor.constraint(equalToConstant: 44),
            startSwatch.heightAnchor.constraint(equalToConstant: 44),

            // End color row
            endLabel.topAnchor.constraint(equalTo: startSwatch.bottomAnchor, constant: 16),
            endLabel.leadingAnchor.constraint(equalTo: gradSection.leadingAnchor),
            endLabel.centerYAnchor.constraint(equalTo: endSwatch.centerYAnchor),

            endSwatch.topAnchor.constraint(equalTo: startSwatch.bottomAnchor, constant: 16),
            endSwatch.trailingAnchor.constraint(equalTo: gradSection.trailingAnchor),
            endSwatch.widthAnchor.constraint(equalToConstant: 44),
            endSwatch.heightAnchor.constraint(equalToConstant: 44),

            // Angle row
            angleTitle.topAnchor.constraint(equalTo: endSwatch.bottomAnchor, constant: 20),
            angleTitle.leadingAnchor.constraint(equalTo: gradSection.leadingAnchor),

            angleLabel.centerYAnchor.constraint(equalTo: angleTitle.centerYAnchor),
            angleLabel.trailingAnchor.constraint(equalTo: gradSection.trailingAnchor),

            angleSlider.topAnchor.constraint(equalTo: angleTitle.bottomAnchor, constant: 8),
            angleSlider.leadingAnchor.constraint(equalTo: gradSection.leadingAnchor),
            angleSlider.trailingAnchor.constraint(equalTo: gradSection.trailingAnchor),
            angleSlider.bottomAnchor.constraint(equalTo: gradSection.bottomAnchor)
        ])
    }

    // MARK: - Sync visible sections

    private func syncUI(animated: Bool) {
        let idx = segmentCtrl.selectedSegmentIndex
        let block = {
            self.solidSection.isHidden = idx != 1
            self.gradSection.isHidden  = idx != 2
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: block)
        } else {
            block()
        }
        previewCurrentSelection()
    }

    private func previewCurrentSelection() {
        let idx = segmentCtrl.selectedSegmentIndex
        switch idx {
        case 1: previewView.preview(.solidColor(hex: solidColor.hexString))
        case 2: previewView.preview(.gradient(startHex: gradStartColor.hexString,
                                              endHex:   gradEndColor.hexString,
                                              angle:    gradAngle))
        default: previewView.preview(.system)
        }
    }

    // MARK: - Actions

    @objc private func segmentChanged() { syncUI(animated: true) }

    @objc private func pickSolidColor() { presentColorPicker(tag: 1, current: solidColor) }
    @objc private func pickStartColor() { presentColorPicker(tag: 2, current: gradStartColor) }
    @objc private func pickEndColor()   { presentColorPicker(tag: 3, current: gradEndColor) }

    private func presentColorPicker(tag: Int, current: UIColor) {
        let picker = UIColorPickerViewController()
        picker.selectedColor = current
        picker.view.tag      = tag
        picker.delegate      = self
        present(picker, animated: true)
    }

    @objc private func angleChanged() {
        gradAngle       = angleSlider.value
        angleLabel.text = "\(Int(gradAngle))°"
        previewCurrentSelection()
    }

    @objc private func applyTapped() {
        let idx = segmentCtrl.selectedSegmentIndex
        switch idx {
        case 1: currentBg = .solidColor(hex: solidColor.hexString)
        case 2: currentBg = .gradient(startHex: gradStartColor.hexString,
                                      endHex:   gradEndColor.hexString,
                                      angle:    gradAngle)
        default: currentBg = .system
        }
        BackgroundManager.shared.current = currentBg

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let done = L10n.bgApplied
        let orig = L10n.apply
        applyBtn.setTitle(done, for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.applyBtn.setTitle(orig, for: .normal)
        }
    }

    @objc private func closeTapped() { dismiss(animated: true) }

    // MARK: - Helpers

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text      = text
        l.font      = .inter(ofSize: 15, weight: .medium)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}

// MARK: - UIColorPickerViewControllerDelegate

extension BackgroundPickerViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewController(_ vc: UIColorPickerViewController,
                                   didSelect color: UIColor, continuously: Bool) {
        switch vc.view.tag {
        case 1:
            solidColor = color
            colorSwatch.backgroundColor = color
        case 2:
            gradStartColor = color
            startSwatch.backgroundColor = color
        case 3:
            gradEndColor = color
            endSwatch.backgroundColor = color
        default: break
        }
        previewCurrentSelection()
    }
}

// MARK: - UIView helper

private extension UIView {
    func pinToEdges(of container: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: container.topAnchor),
            leadingAnchor.constraint(equalTo: container.leadingAnchor),
            trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}
