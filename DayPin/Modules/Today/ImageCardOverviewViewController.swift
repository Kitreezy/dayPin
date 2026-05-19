import UIKit

// MARK: - ImageCardOverviewViewController

final class ImageCardOverviewViewController: UIViewController {

    // MARK: - Model

    private let card: ImageCard
    private var annotations: [ImageAnnotation]

    // MARK: - State

    private var activePinID: UUID? { didSet { syncActivePin(deactivating: oldValue) } }
    private var isPlacingPin = false

    // Placing-mode gesture — stored as property so we can enable/disable it.
    // Disabled by default so it never interferes with the regular tap gesture.
    private lazy var placingLongPress: UILongPressGestureRecognizer = {
        let gr = UILongPressGestureRecognizer(target: self, action: #selector(placingGesture(_:)))
        gr.minimumPressDuration = 0
        gr.cancelsTouchesInView = false
        gr.isEnabled = false
        return gr
    }()

    // MARK: - Custom nav bar

    private let navBarView    = UIView()
    private let backButton    = UIButton(type: .system)
    private let navTitleLabel = UILabel()
    private let bellNavBtn    = UIButton(type: .system)
    private let editNavBtn    = UIButton(type: .system)

    // MARK: - Photo zone

    private let photoContainer  = UIView()
    private let photoImageView  = UIImageView()
    private var photoGradient:  CAGradientLayer?
    private var pinDotViews:    [UUID: OverviewPinDotView] = [:]
    private var photoHeightConstraint: NSLayoutConstraint?

    private let pinCountBadge   = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let pinCountLabel   = UILabel()
    private let tapHintBadge    = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let placingHintBadge = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    // Crosshair cursor — frame-based, moves with finger
    private let placingCursor   = UIView()

    // MARK: - Scroll + content

    private let scrollView      = UIScrollView()
    private let contentView     = UIView()

    // Note card — always visible, editable
    private let noteCardGlass       = GlassCardView(style: .thinLight)
    private let noteNormalContainer = UIView()
    private let noteEditContainer   = UIView()
    private let noteCommentLabel    = UILabel()
    private let noteTextView        = UITextView()

    // Pins section
    private let pinsHeaderView  = UIView()
    private let pinsCountLabel  = UILabel()
    private let pinCardsStack   = UIStackView()
    private var pinCardViews:   [UUID: PinCardView] = [:]

    // MARK: - Fixed bottom button

    private let addPinButton                = UIButton(type: .system)
    private var addPinPillView: UIView?          // outer floating pill (shadow + dash border)
    private var scrollViewBottomConstraint: NSLayoutConstraint?
    private var baseScrollInset: CGFloat = 0     // content inset that clears the floating button
    private var isKeyboardVisible        = false // guards against layout resetting keyboard inset

    // MARK: - Init

    init(card: ImageCard) {
        self.card        = card
        self.annotations = card.annotations
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        addStandardBackground()
        buildCustomNavBar()
        buildPhotoZone()
        buildScrollContent()
        buildFixedAddPinButton()
        loadAnnotations()
        observeKeyboard()
        observeNotifications()

        // Tap anywhere on the scroll content → dismiss keyboard
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(dismissTap)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Fix 5 (navBar): hide system bar without animation to prevent "navbar slides in" glitch
        navigationController?.setNavigationBarHidden(true, animated: false)
        annotations = card.annotations
        loadAnnotations()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info    = n.userInfo,
              let kbFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        isKeyboardVisible = true

        // Shrink the scrollView so its bottom edge is flush with the keyboard top.
        // Unlike contentInset, this physically reduces the visible area, which means
        // scrollRectToVisible always has room to work regardless of content length.
        scrollViewBottomConstraint?.isActive = false
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor, constant: -kbFrame.height)
        scrollViewBottomConstraint?.isActive = true

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.scrollToActiveInput()
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double)
        else { return }
        isKeyboardVisible = false

        // Restore scrollView to full height
        scrollViewBottomConstraint?.isActive = false
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        scrollViewBottomConstraint?.isActive = true

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    /// Walk the contentView hierarchy to find the active input and scroll to it.
    private func scrollToActiveInput() {
        func findFirstResponder(in view: UIView) -> UIView? {
            if view.isFirstResponder { return view }
            for sub in view.subviews {
                if let found = findFirstResponder(in: sub) { return found }
            }
            return nil
        }
        guard let responder = findFirstResponder(in: contentView) else { return }
        // 20 pt breathing room so the field isn't flush with the keyboard edge
        let rect = responder.convert(responder.bounds, to: scrollView).insetBy(dx: 0, dy: -20)
        scrollView.scrollRectToVisible(rect, animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        let displayTitle = card.title.isEmpty ? L10n.cardTypePhoto : card.title
        navTitleLabel.text = displayTitle
        backButton.setTitle(" \(L10n.back)", for: .normal)
        addPinButton.setTitle(L10n.addPinButton, for: .normal)
        loadAnnotations()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        backButton.tintColor = DayPinDesign.accent
        backButton.setTitleColor(DayPinDesign.accent, for: .normal)
        addPinButton.setTitleColor(DayPinDesign.accent, for: .normal)
        refreshBell()
    }

    // MARK: - Custom nav bar (above photo, standard colors)

    private func buildCustomNavBar() {
        navBarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBarView)
        NSLayoutConstraint.activate([
            navBarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBarView.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Back button
        let chevronCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: chevronCfg), for: .normal)
        backButton.setTitle(" \(L10n.back)", for: .normal)
        backButton.tintColor = DayPinDesign.accent
        backButton.setTitleColor(DayPinDesign.accent, for: .normal)
        backButton.titleLabel?.font = .inter(ofSize: 16, weight: .regular)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        // Title
        let displayTitle = card.title.isEmpty ? L10n.cardTypePhoto : card.title
        navTitleLabel.text          = displayTitle
        navTitleLabel.font          = .inter(ofSize: 17, weight: .semibold)
        navTitleLabel.textColor     = .label
        navTitleLabel.textAlignment = .center
        navTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Right buttons
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let hasReminder = card.reminderDate.map { $0 > Date() } ?? false
        bellNavBtn.setImage(UIImage(systemName: hasReminder ? "bell.fill" : "bell",
                                    withConfiguration: iconCfg), for: .normal)
        bellNavBtn.tintColor = hasReminder ? DayPinDesign.accent : .label
        bellNavBtn.translatesAutoresizingMaskIntoConstraints = false
        bellNavBtn.addTarget(self, action: #selector(bellTapped), for: .touchUpInside)

        editNavBtn.setImage(UIImage(systemName: "pencil", withConfiguration: iconCfg), for: .normal)
        editNavBtn.tintColor = .label
        editNavBtn.translatesAutoresizingMaskIntoConstraints = false
        editNavBtn.addTarget(self, action: #selector(editCardTapped), for: .touchUpInside)

        navBarView.addSubview(backButton)
        navBarView.addSubview(navTitleLabel)
        navBarView.addSubview(editNavBtn)
        navBarView.addSubview(bellNavBtn)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: navBarView.leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: navBarView.centerYAnchor),

            navTitleLabel.centerXAnchor.constraint(equalTo: navBarView.centerXAnchor),
            navTitleLabel.centerYAnchor.constraint(equalTo: navBarView.centerYAnchor),
            navTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            navTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: bellNavBtn.leadingAnchor, constant: -8),

            editNavBtn.trailingAnchor.constraint(equalTo: navBarView.trailingAnchor, constant: -12),
            editNavBtn.centerYAnchor.constraint(equalTo: navBarView.centerYAnchor),
            editNavBtn.widthAnchor.constraint(equalToConstant: 36),
            editNavBtn.heightAnchor.constraint(equalToConstant: 36),

            bellNavBtn.trailingAnchor.constraint(equalTo: editNavBtn.leadingAnchor, constant: -2),
            bellNavBtn.centerYAnchor.constraint(equalTo: navBarView.centerYAnchor),
            bellNavBtn.widthAnchor.constraint(equalToConstant: 36),
            bellNavBtn.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Separator below navBar
        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        sep.translatesAutoresizingMaskIntoConstraints = false
        navBarView.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.bottomAnchor.constraint(equalTo: navBarView.bottomAnchor),
            sep.leadingAnchor.constraint(equalTo: navBarView.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: navBarView.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    private func refreshBell() {
        let has = card.reminderDate.map { $0 > Date() } ?? false
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        bellNavBtn.setImage(UIImage(systemName: has ? "bell.fill" : "bell", withConfiguration: cfg), for: .normal)
        bellNavBtn.tintColor = has ? DayPinDesign.accent : .label
    }

    // MARK: - Photo zone

    private func buildPhotoZone() {
        // Fix 1: black background prevents white flash while image loads
        photoContainer.backgroundColor = UIColor { trait in trait.userInterfaceStyle == .dark ? .black : .black }
        photoContainer.clipsToBounds   = true
        photoContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(photoContainer)

        photoImageView.contentMode   = .scaleAspectFill
        photoImageView.clipsToBounds = true
        // Fix 1: set placeholder color
        photoImageView.backgroundColor = UIColor { trait in trait.userInterfaceStyle == .dark ? .black : .black }
        photoImageView.image = card.imageData.flatMap { UIImage(data: $0) }
        // Low compression resistance so container constraints always win
        photoImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        photoImageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoContainer.addSubview(photoImageView)

        let photoH = computedPhotoHeight()
        // Fix 6: dynamic height based on image aspect ratio
        let hc = photoContainer.heightAnchor.constraint(equalToConstant: photoH)
        photoHeightConstraint = hc
        NSLayoutConstraint.activate([
            // Fix 2: photo starts BELOW navBar (not behind it)
            photoContainer.topAnchor.constraint(equalTo: navBarView.bottomAnchor),
            photoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            photoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc,

            photoImageView.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor)
        ])

        // Bottom gradient — blends photo into scroll content
        let grad = CAGradientLayer()
        grad.colors     = [UIColor.clear.cgColor, UIColor { trait in UIColor.black.withAlphaComponent(0.55) }.cgColor]
        grad.startPoint = CGPoint(x: 0.5, y: 0.45)
        grad.endPoint   = CGPoint(x: 0.5, y: 1.0)
        photoContainer.layer.addSublayer(grad)
        photoGradient = grad

        buildPinCountBadge()

        placeBadge(tapHintBadge, text: L10n.tapForFullView)
        tapHintBadge.isUserInteractionEnabled = false

        placeBadge(placingHintBadge, text: L10n.annotationHint)
        placingHintBadge.alpha = 0
        placingHintBadge.isUserInteractionEnabled = false

        buildPlacingCursor()

        // Regular tap: dot activation + lightbox. Works always when long-press is disabled.
        let tap = UITapGestureRecognizer(target: self, action: #selector(photoTapped(_:)))
        photoContainer.addGestureRecognizer(tap)

        // Placing-mode touch tracker — starts disabled, enabled only in startPlacingMode()
        photoContainer.addGestureRecognizer(placingLongPress)
    }

    // Compute photo height: natural aspect ratio capped so content below always fits.
    private func computedPhotoHeight() -> CGFloat {
        guard let data = card.imageData,
              let img  = UIImage(data: data), img.size.width > 0 else { return 200 }
        let w     = UIScreen.main.bounds.width
        let ratio = img.size.height / img.size.width
        if ratio >= 1 {
            // Portrait / square — cap at 55% of width so scroll content is always visible
            return min(w * ratio, w * 0.55)
        } else {
            // Landscape — show natural height, max 50% of width (16:9 → ~219pt on 390w)
            return min(w * ratio, w * 0.50)
        }
    }

    private func buildPinCountBadge() {
        pinCountBadge.layer.cornerRadius = 14
        pinCountBadge.clipsToBounds      = true
        pinCountBadge.translatesAutoresizingMaskIntoConstraints = false

        let dot = makeDot(size: 8, color: DayPinDesign.accent)
        pinCountLabel.font      = .inter(ofSize: 12, weight: .semibold)
        pinCountLabel.textColor = UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }
        pinCountLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [dot, pinCountLabel])
        row.axis = .horizontal; row.spacing = 5; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        pinCountBadge.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: pinCountBadge.contentView.topAnchor,      constant: 6),
            row.leadingAnchor.constraint(equalTo: pinCountBadge.contentView.leadingAnchor,   constant: 10),
            row.trailingAnchor.constraint(equalTo: pinCountBadge.contentView.trailingAnchor, constant: -10),
            row.bottomAnchor.constraint(equalTo: pinCountBadge.contentView.bottomAnchor, constant: -6)
        ])

        photoContainer.addSubview(pinCountBadge)
        NSLayoutConstraint.activate([
            pinCountBadge.topAnchor.constraint(equalTo: photoContainer.topAnchor, constant: 10),
            pinCountBadge.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor, constant: -12)
        ])
    }

    private func placeBadge(_ blur: UIVisualEffectView, text: String) {
        blur.layer.cornerRadius = 14; blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        let lbl = UILabel()
        lbl.text = text; lbl.font = .inter(ofSize: 12)
        lbl.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.88)
                : UIColor.white.withAlphaComponent(0.88)
        }
        lbl.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: blur.contentView.topAnchor,      constant: 7),
            lbl.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor,   constant: 14),
            lbl.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -14),
            lbl.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor,  constant: -7)
        ])
        photoContainer.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.centerXAnchor.constraint(equalTo: photoContainer.centerXAnchor),
            blur.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: -14)
        ])
    }

    // Fix 5: frame-based cursor — can be moved freely with `.center = pt`
    private func buildPlacingCursor() {
        // NOTE: intentionally NOT using translatesAutoresizingMaskIntoConstraints = false
        // so we can control center directly without constraint conflicts.
        placingCursor.isUserInteractionEnabled = false
        placingCursor.alpha = 0
        placingCursor.bounds = CGRect(origin: .zero, size: CGSize(width: 50, height: 50))
        placingCursor.center = CGPoint(x: UIScreen.main.bounds.width / 2, y: 120)
        photoContainer.addSubview(placingCursor)

        let ring = UIView()
        ring.layer.borderColor  = UIColor { trait in UIColor.white.withAlphaComponent(0.9) }.cgColor
        ring.layer.borderWidth  = 1.5
        ring.layer.cornerRadius = 25
        ring.frame = placingCursor.bounds
        ring.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        placingCursor.addSubview(ring)

        let hLine = UIView(); hLine.backgroundColor = UIColor { trait in UIColor.white.withAlphaComponent(0.9) }
        hLine.frame = CGRect(x: 11, y: 24.5, width: 28, height: 1)
        hLine.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth]
        placingCursor.addSubview(hLine)

        let vLine = UIView(); vLine.backgroundColor = UIColor { trait in UIColor.white.withAlphaComponent(0.9) }
        vLine.frame = CGRect(x: 24.5, y: 11, width: 1, height: 28)
        vLine.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleHeight]
        placingCursor.addSubview(vLine)
    }

    // MARK: - Photo gestures

    @objc private func photoTapped(_ gr: UITapGestureRecognizer) {
        // Fix 5: when placing, long-press gesture handles everything
        guard !isPlacingPin else { return }

        let pt = gr.location(in: photoContainer)

        // Hit-test pin dot pills (use frame.insetBy for easier tap)
        for (id, dot) in pinDotViews where !dot.isHidden {
            if dot.frame.insetBy(dx: -10, dy: -10).contains(pt) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                activePinID = (activePinID == id) ? nil : id
                return
            }
        }

        if activePinID != nil {
            activePinID = nil
        } else {
            openLightbox()
        }
    }

    // Fix 5: long-press tracks finger → moves crosshair → places pin on lift
    @objc private func placingGesture(_ gr: UILongPressGestureRecognizer) {
        guard isPlacingPin else { return }

        let pt = gr.location(in: photoContainer)
        switch gr.state {
        case .began, .changed:
            // Move cursor with finger — no animation for instantaneous response
            placingCursor.center = pt

        case .ended:
            endPlacingMode()
            guard photoImageContentFrame.contains(pt) else { return }
            let norm     = normalizedPoint(from: pt)
            let windowPt = photoContainer.convert(pt, to: view.window)
            showPinPlacedIndicator(at: pt)
            presentPinInput(at: norm, windowPoint: windowPt)

        case .cancelled, .failed:
            endPlacingMode()

        default: break
        }
    }

    private func showPinPlacedIndicator(at pt: CGPoint) {
        let sz: CGFloat = 18
        let flash = UIView()
        flash.backgroundColor    = UIColor { trait in UIColor.white.withAlphaComponent(0.6) }
        flash.layer.cornerRadius = sz / 2
        flash.frame = CGRect(x: pt.x - sz/2, y: pt.y - sz/2, width: sz, height: sz)
        photoContainer.addSubview(flash)
        UIView.animate(withDuration: 0.45, delay: 0.05, options: .curveEaseOut) {
            flash.alpha     = 0
            flash.transform = CGAffineTransform(scaleX: 2.2, y: 2.2)
        } completion: { _ in flash.removeFromSuperview() }
    }

    // MARK: - Placing mode

    private func startPlacingMode() {
        isPlacingPin = true
        placingLongPress.isEnabled = true    // allow cursor tracking
        // Reset cursor to photo center
        placingCursor.center = CGPoint(x: photoContainer.bounds.midX, y: photoContainer.bounds.midY)
        photoContainer.bringSubviewToFront(placingCursor)
        photoContainer.bringSubviewToFront(placingHintBadge)
        UIView.animate(withDuration: 0.2) {
            self.tapHintBadge.alpha     = 0
            self.placingHintBadge.alpha = 1
            self.placingCursor.alpha    = 1
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func endPlacingMode() {
        isPlacingPin = false
        placingLongPress.isEnabled = false   // restore normal tap behaviour
        UIView.animate(withDuration: 0.2) {
            self.tapHintBadge.alpha     = 1
            self.placingHintBadge.alpha = 0
            self.placingCursor.alpha    = 0
        }
    }

    private func presentPinInput(at normalized: CGPoint, windowPoint: CGPoint) {
        PinCalloutView.show(
            pinWindowPoint: windowPoint,
            title: "", text: "", colorHex: "#007AFF",
            startInEditMode: true,
            sourcePinView: nil,
            onEdit: { [weak self] title, text, colorHex in
                guard let self else { return }
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let x = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty || !x.isEmpty else { return }
                let ann = ImageAnnotation(x: normalized.x, y: normalized.y,
                                         title: t, text: x, colorHex: colorHex)
                self.annotations.append(ann)
                self.persist()
                self.loadAnnotations()
                self.activePinID = ann.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if let cv = self.pinCardViews[ann.id] {
                        self.scrollView.scrollRectToVisible(
                            cv.convert(cv.bounds, to: self.scrollView), animated: true)
                    }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            },
            onDelete: nil
        )
    }

    // MARK: - Coordinate helpers

    private var photoImageContentFrame: CGRect {
        guard let img = photoImageView.image, img.size.width > 0 else { return photoContainer.bounds }
        let c = photoContainer.bounds
        let s = max(c.width / img.size.width, c.height / img.size.height)
        return CGRect(x: (c.width  - img.size.width  * s) / 2,
                      y: (c.height - img.size.height * s) / 2,
                      width:  img.size.width  * s,
                      height: img.size.height * s)
    }

    private func screenPt(for ann: ImageAnnotation) -> CGPoint {
        let f = photoImageContentFrame
        return CGPoint(x: f.minX + CGFloat(ann.x) * f.width,
                       y: f.minY + CGFloat(ann.y) * f.height)
    }

    private func normalizedPoint(from pt: CGPoint) -> CGPoint {
        let f = photoImageContentFrame
        guard f.width > 0, f.height > 0 else { return .zero }
        return CGPoint(x: max(0, min(1, (pt.x - f.minX) / f.width)),
                       y: max(0, min(1, (pt.y - f.minY) / f.height)))
    }

    // MARK: - Load / refresh

    private func loadAnnotations() {
        pinDotViews.values.forEach { $0.removeFromSuperview() }
        pinDotViews.removeAll()
        pinCardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        pinCardViews.removeAll()

        for ann in annotations {
            addPinDot(for: ann)
            addPinCard(for: ann)
        }
        updatePinCountBadge()

        if let id = activePinID {
            pinDotViews[id]?.isActive  = true
            pinCardViews[id]?.isActive = true
        }
    }

    private func addPinDot(for ann: ImageAnnotation) {
        let dot = OverviewPinDotView(annotation: ann)
        photoContainer.addSubview(dot)
        [pinCountBadge, tapHintBadge, placingHintBadge, placingCursor].forEach {
            photoContainer.bringSubviewToFront($0)
        }
        pinDotViews[ann.id] = dot
    }

    private func repositionPinDots() {
        for ann in annotations {
            guard let dot = pinDotViews[ann.id] else { continue }
            let center  = screenPt(for: ann)
            let size    = OverviewPinDotView.pillSize(for: ann)
            let anchorX = OverviewPinDotView.dotCenterXInPill
            let pillX   = center.x - anchorX
            let pillY   = center.y - size.height / 2
            let clamped = CGRect(
                x: max(2, min(photoContainer.bounds.width  - size.width  - 2, pillX)),
                y: max(2, min(photoContainer.bounds.height - size.height - 2, pillY)),
                width: size.width, height: size.height)
            dot.isHidden = !photoContainer.bounds.insetBy(dx: 6, dy: 6).contains(center)
            dot.frame = clamped
        }
    }

    private func updatePinCountBadge() {
        let n = annotations.count
        pinCountLabel.text     = L10n.annotationCount(n)
        pinCountBadge.isHidden = (n == 0)
        pinsCountLabel.text    = "\(n)"
    }

    // MARK: - Active pin sync

    private func syncActivePin(deactivating old: UUID?) {
        if let old { pinDotViews[old]?.isActive = false; pinCardViews[old]?.isActive = false }
        if let id = activePinID {
            pinDotViews[id]?.isActive  = true
            pinCardViews[id]?.isActive = true
            if let cv = pinCardViews[id] {
                DispatchQueue.main.async {
                    self.scrollView.scrollRectToVisible(
                        cv.convert(cv.bounds, to: self.scrollView), animated: true)
                }
            }
        }
    }

    // MARK: - Persistence

    private func persist() {
        card.annotations = annotations
        CardStore.shared.save(card: card)
    }

    // MARK: - Lightbox

    private func openLightbox() {
        let vc = ImageCardDetailViewController(card: card)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Scroll content

    private func buildScrollContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints  = false
        scrollView.showsVerticalScrollIndicator = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Temporary bottom constraint — will be replaced in buildFixedAddPinButton
        let scrollBottom = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        scrollViewBottomConstraint = scrollBottom

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: photoContainer.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollBottom,

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        buildNoteCard()
        buildPinsSection()
    }

    // Floating glass "Add pin" pill — hovers above scroll content, no rectangular background
    private func buildFixedAddPinButton() {
        // ── Outer pill ───────────────────────────────────────────────────
        // Does NOT clip so shadow and dashed border are fully visible.
        let pill = UIView()
        pill.layer.cornerRadius  = 22
        pill.layer.shadowColor   = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.18
        pill.layer.shadowRadius  = 10
        pill.layer.shadowOffset  = CGSize(width: 0, height: 4)
        pill.translatesAutoresizingMaskIntoConstraints = false

        // Dashed accent border lives on the outer pill layer (not clipped)
        let dash = CAShapeLayer()
        dash.strokeColor     = DayPinDesign.accent.withAlphaComponent(0.5).cgColor
        dash.fillColor       = UIColor.clear.cgColor
        dash.lineWidth       = 1.5
        dash.lineDashPattern = [6, 4]
        dash.name = "dashBorder"
        pill.layer.addSublayer(dash)

        // ── Inner glass ──────────────────────────────────────────────────
        // UIBlurEffect with cornerRadius + clipsToBounds gives the frosted look.
        let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        glass.layer.cornerRadius = 22
        glass.clipsToBounds = true
        glass.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: pill.topAnchor),
            glass.leadingAnchor.constraint(equalTo: pill.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: pill.trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: pill.bottomAnchor)
        ])

        // ── Button inside glass ──────────────────────────────────────────
        addPinButton.setTitle(L10n.addPinButton, for: .normal)
        addPinButton.titleLabel?.font = .inter(ofSize: 15, weight: .semibold)
        addPinButton.setTitleColor(DayPinDesign.accent, for: .normal)
        addPinButton.backgroundColor = .clear
        addPinButton.translatesAutoresizingMaskIntoConstraints = false
        addPinButton.addTarget(self, action: #selector(addPinTapped), for: .touchUpInside)
        glass.contentView.addSubview(addPinButton)
        NSLayoutConstraint.activate([
            addPinButton.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            addPinButton.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            addPinButton.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
            addPinButton.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor)
        ])

        view.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            pill.leadingAnchor.constraint(equalTo: view.leadingAnchor,   constant: 24),
            pill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            pill.heightAnchor.constraint(equalToConstant: 44)
        ])

        addPinPillView = pill

        // ScrollView goes full height; content inset is set in viewDidLayoutSubviews
        scrollViewBottomConstraint?.isActive = false
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        scrollViewBottomConstraint?.isActive = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Update dashed border path on the floating pill
        if let pill = addPinPillView,
           let dash  = pill.layer.sublayers?.first(where: { $0.name == "dashBorder" }) as? CAShapeLayer {
            dash.frame = pill.bounds
            dash.path  = UIBezierPath(roundedRect: pill.bounds,
                                      cornerRadius: pill.layer.cornerRadius).cgPath
        }

        // Keep the content inset in sync with the floating pill position so the last
        // pin card is never hidden behind it. Keyboard avoidance is now frame-based
        // (scrollViewBottomConstraint), so contentInset is only for the pill.
        if let pill = addPinPillView {
            let newInset = max(view.bounds.height - pill.frame.minY + 8, 0)
            if abs(newInset - baseScrollInset) > 1 {
                baseScrollInset = newInset
                scrollView.contentInset.bottom            = baseScrollInset
                scrollView.verticalScrollIndicatorInsets.bottom = baseScrollInset
            }
        }

        photoGradient?.frame = photoContainer.bounds
        repositionPinDots()
        if !isPlacingPin {
            placingCursor.center = CGPoint(x: photoContainer.bounds.midX, y: photoContainer.bounds.midY)
        }
    }

    // MARK: - Note card (always shown, editable)

    private func buildNoteCard() {
        noteCardGlass.cornerRadius = 14
        noteCardGlass.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(noteCardGlass)

        let cv = noteCardGlass.glass.contentView

        // ── Normal container ─────────────────────────────────────────
        noteNormalContainer.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(noteNormalContainer)
        NSLayoutConstraint.activate([
            noteNormalContainer.topAnchor.constraint(equalTo: cv.topAnchor),
            noteNormalContainer.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            noteNormalContainer.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            noteNormalContainer.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
        ])

        let sectionLbl = makeCaptionLabel(L10n.noteSection)

        let isEmpty = card.comment.isEmpty
        noteCommentLabel.text          = isEmpty
            ? L10n.tapToAddNote
            : card.comment
        noteCommentLabel.font          = .inter(ofSize: 14)
        noteCommentLabel.textColor     = isEmpty ? .tertiaryLabel : .secondaryLabel
        noteCommentLabel.numberOfLines = 0
        noteCommentLabel.translatesAutoresizingMaskIntoConstraints = false

        let pencilCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let pencilBtn = UIButton(type: .system)
        pencilBtn.setImage(UIImage(systemName: "pencil", withConfiguration: pencilCfg), for: .normal)
        pencilBtn.tintColor = .tertiaryLabel
        pencilBtn.translatesAutoresizingMaskIntoConstraints = false
        pencilBtn.addTarget(self, action: #selector(editNoteTapped), for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [sectionLbl, UIView(), pencilBtn])
        headerRow.axis = .horizontal; headerRow.spacing = 8; headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        noteNormalContainer.addSubview(headerRow)
        noteNormalContainer.addSubview(noteCommentLabel)
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: noteNormalContainer.topAnchor,        constant: 12),
            headerRow.leadingAnchor.constraint(equalTo: noteNormalContainer.leadingAnchor,    constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: noteNormalContainer.trailingAnchor, constant: -10),
            pencilBtn.widthAnchor.constraint(equalToConstant: 28),
            pencilBtn.heightAnchor.constraint(equalToConstant: 28),

            noteCommentLabel.topAnchor.constraint(equalTo: headerRow.bottomAnchor,            constant: 6),
            noteCommentLabel.leadingAnchor.constraint(equalTo: noteNormalContainer.leadingAnchor,    constant: 14),
            noteCommentLabel.trailingAnchor.constraint(equalTo: noteNormalContainer.trailingAnchor,  constant: -14),
            noteCommentLabel.bottomAnchor.constraint(equalTo: noteNormalContainer.bottomAnchor,      constant: -14)
        ])

        // ── Edit container ───────────────────────────────────────────
        noteEditContainer.translatesAutoresizingMaskIntoConstraints = false
        noteEditContainer.isHidden = true
        cv.addSubview(noteEditContainer)
        NSLayoutConstraint.activate([
            noteEditContainer.topAnchor.constraint(equalTo: cv.topAnchor),
            noteEditContainer.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            noteEditContainer.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            noteEditContainer.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
        ])

        let editCaption = makeCaptionLabel(L10n.noteSection)

        noteTextView.text               = card.comment
        noteTextView.font               = .inter(ofSize: 14)
        noteTextView.textColor          = .label
        noteTextView.backgroundColor    = .clear
        noteTextView.isScrollEnabled    = false
        noteTextView.textContainerInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        noteTextView.translatesAutoresizingMaskIntoConstraints = false

        let sep = makeSeparator()

        let saveBtn = UIButton(type: .system)
        saveBtn.setTitle(L10n.save, for: .normal)
        saveBtn.titleLabel?.font  = .inter(ofSize: 13, weight: .semibold)
        saveBtn.backgroundColor   = DayPinDesign.accent
        saveBtn.setTitleColor(UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }, for: .normal)
        saveBtn.layer.cornerRadius = 8
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.addTarget(self, action: #selector(saveNoteTapped), for: .touchUpInside)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle(L10n.cancel, for: .normal)
        cancelBtn.titleLabel?.font = .inter(ofSize: 13)
        cancelBtn.setTitleColor(.secondaryLabel, for: .normal)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(cancelNoteTapped), for: .touchUpInside)

        let btnRow = UIStackView(arrangedSubviews: [saveBtn, cancelBtn])
        btnRow.axis = .horizontal; btnRow.spacing = 8; btnRow.distribution = .fillEqually
        btnRow.translatesAutoresizingMaskIntoConstraints = false

        noteEditContainer.addSubview(editCaption)
        noteEditContainer.addSubview(noteTextView)
        noteEditContainer.addSubview(sep)
        noteEditContainer.addSubview(btnRow)
        noteTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        NSLayoutConstraint.activate([
            editCaption.topAnchor.constraint(equalTo: noteEditContainer.topAnchor,       constant: 12),
            editCaption.leadingAnchor.constraint(equalTo: noteEditContainer.leadingAnchor,    constant: 14),
            editCaption.trailingAnchor.constraint(equalTo: noteEditContainer.trailingAnchor, constant: -14),

            noteTextView.topAnchor.constraint(equalTo: editCaption.bottomAnchor,  constant: 6),
            noteTextView.leadingAnchor.constraint(equalTo: noteEditContainer.leadingAnchor),
            noteTextView.trailingAnchor.constraint(equalTo: noteEditContainer.trailingAnchor),

            sep.topAnchor.constraint(equalTo: noteTextView.bottomAnchor, constant: 4),
            sep.leadingAnchor.constraint(equalTo: noteEditContainer.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: noteEditContainer.trailingAnchor),

            btnRow.topAnchor.constraint(equalTo: sep.bottomAnchor,               constant: 8),
            btnRow.leadingAnchor.constraint(equalTo: noteEditContainer.leadingAnchor,   constant: 12),
            btnRow.trailingAnchor.constraint(equalTo: noteEditContainer.trailingAnchor, constant: -12),
            btnRow.heightAnchor.constraint(equalToConstant: 34),
            btnRow.bottomAnchor.constraint(equalTo: noteEditContainer.bottomAnchor, constant: -10)
        ])

        NSLayoutConstraint.activate([
            noteCardGlass.topAnchor.constraint(equalTo: contentView.topAnchor,       constant: 14),
            noteCardGlass.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,    constant: 16),
            noteCardGlass.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    @objc private func editNoteTapped() {
        noteTextView.text = card.comment
        UIView.transition(with: noteCardGlass.glass.contentView, duration: 0.2,
                          options: .transitionCrossDissolve) {
            self.noteNormalContainer.isHidden = true
            self.noteEditContainer.isHidden   = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.noteTextView.becomeFirstResponder() }
    }

    @objc private func saveNoteTapped() {
        let newText = noteTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        noteTextView.resignFirstResponder()
        card.comment = newText
        CardStore.shared.save(card: card)
        let isEmpty = newText.isEmpty
        noteCommentLabel.text      = isEmpty
            ? L10n.tapToAddNote
            : newText
        noteCommentLabel.textColor = isEmpty ? .tertiaryLabel : .secondaryLabel
        UIView.transition(with: noteCardGlass.glass.contentView, duration: 0.2,
                          options: .transitionCrossDissolve) {
            self.noteNormalContainer.isHidden = false
            self.noteEditContainer.isHidden   = true
        }
    }

    @objc private func cancelNoteTapped() {
        noteTextView.resignFirstResponder()
        UIView.transition(with: noteCardGlass.glass.contentView, duration: 0.2,
                          options: .transitionCrossDissolve) {
            self.noteNormalContainer.isHidden = false
            self.noteEditContainer.isHidden   = true
        }
    }

    // MARK: - Pins section

    private func buildPinsSection() {
        pinsHeaderView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pinsHeaderView)

        let accentDot    = makeDot(size: 10, color: DayPinDesign.accent)
        let pinsTitleLbl = UILabel()
        pinsTitleLbl.attributedText = NSAttributedString(
            string: L10n.pinsSection,
            attributes: [.font: UIFont.inter(ofSize: 11, weight: .semibold),
                         .foregroundColor: UIColor.secondaryLabel, .kern: 0.5])

        let countBg = UIView()
        countBg.backgroundColor    = DayPinDesign.accent
        countBg.layer.cornerRadius = 6
        countBg.translatesAutoresizingMaskIntoConstraints = false

        pinsCountLabel.font = .inter(ofSize: 11, weight: .semibold)
        pinsCountLabel.textColor = UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }
        pinsCountLabel.translatesAutoresizingMaskIntoConstraints = false
        countBg.addSubview(pinsCountLabel)
        NSLayoutConstraint.activate([
            pinsCountLabel.topAnchor.constraint(equalTo: countBg.topAnchor,      constant: 2),
            pinsCountLabel.leadingAnchor.constraint(equalTo: countBg.leadingAnchor,   constant: 6),
            pinsCountLabel.trailingAnchor.constraint(equalTo: countBg.trailingAnchor, constant: -6),
            pinsCountLabel.bottomAnchor.constraint(equalTo: countBg.bottomAnchor, constant: -2)
        ])

        let spacer    = UIView()
        let headerRow = UIStackView(arrangedSubviews: [accentDot, pinsTitleLbl, countBg, spacer])
        headerRow.axis = .horizontal; headerRow.spacing = 6; headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        pinsHeaderView.addSubview(headerRow)
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: pinsHeaderView.topAnchor),
            headerRow.leadingAnchor.constraint(equalTo: pinsHeaderView.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: pinsHeaderView.trailingAnchor),
            headerRow.bottomAnchor.constraint(equalTo: pinsHeaderView.bottomAnchor)
        ])

        pinCardsStack.axis = .vertical; pinCardsStack.spacing = 6
        pinCardsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pinCardsStack)

        NSLayoutConstraint.activate([
            pinsHeaderView.topAnchor.constraint(equalTo: noteCardGlass.bottomAnchor, constant: 18),
            pinsHeaderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,    constant: 16),
            pinsHeaderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            pinCardsStack.topAnchor.constraint(equalTo: pinsHeaderView.bottomAnchor,  constant: 8),
            pinCardsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,    constant: 16),
            pinCardsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            pinCardsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Pin cards

    private func addPinCard(for ann: ImageAnnotation) {
        let cv = PinCardView(annotation: ann)
        cv.onActivate = { [weak self] in
            guard let self else { return }
            self.activePinID = (self.activePinID == ann.id) ? nil : ann.id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        cv.onSave = { [weak self] title, text, colorHex in
            guard let self else { return }
            if let i = self.annotations.firstIndex(where: { $0.id == ann.id }) {
                self.annotations[i].title    = title
                self.annotations[i].text     = text
                self.annotations[i].colorHex = colorHex
                self.persist()
                self.loadAnnotations()
            }
        }
        cv.onDelete = { [weak self] in
            guard let self else { return }
            if self.activePinID == ann.id { self.activePinID = nil }
            self.annotations.removeAll { $0.id == ann.id }
            self.persist()
            self.loadAnnotations()
        }
        pinCardsStack.addArrangedSubview(cv)
        pinCardViews[ann.id] = cv
    }

    // MARK: - Actions

    @objc private func addPinTapped() {
        startPlacingMode()
        scrollView.setContentOffset(.zero, animated: true)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func bellTapped() {
        let picker = ReminderPickerViewController(existingDate: card.reminderDate)
        picker.onConfirm = { [weak self] date in
            guard let self else { return }
            ReminderManager.shared.schedule(for: self.card, at: date) { [weak self] id in
                guard let self else { return }
                self.card.reminderDate           = date
                self.card.reminderNotificationID = id
                self.persist(); self.refreshBell()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        if card.reminderDate != nil {
            picker.onRemove = { [weak self] in
                guard let self else { return }
                ReminderManager.shared.cancel(for: self.card)
                self.card.reminderDate = nil; self.card.reminderNotificationID = nil
                self.persist(); self.refreshBell()
            }
        }
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium()]; sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(picker, animated: true)
    }

    @objc private func editCardTapped() {
        let vc = ImageCardEditorViewController(imageData: card.imageData, dayDate: card.dayDate, existingCard: card)
        vc.onSave = { [weak self] saved in
            guard let self else { return }
            self.card.title       = saved.title
            self.card.imageData   = saved.imageData
            self.card.annotations = saved.annotations
            self.annotations      = saved.annotations
            self.navTitleLabel.text = saved.title
            self.photoImageView.image = saved.imageData.flatMap { UIImage(data: $0) }
            self.persist(); self.loadAnnotations()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    // MARK: - Helpers

    private func makeDot(size: CGFloat, color: UIColor) -> UIView {
        let v = UIView()
        v.backgroundColor    = color
        v.layer.cornerRadius = size / 2
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: size).isActive  = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }

    private func makeCaptionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.inter(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.tertiaryLabel, .kern: 0.5
        ])
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }
}

// MARK: - OverviewPinDotView
// Always-visible pill: [● Title] on the photo. Active = highlight border.

private final class OverviewPinDotView: UIView {

    var isActive: Bool = false { didSet { updateState() } }

    private let annotation: ImageAnnotation
    private let pinColor:   UIColor

    private let pillBg   = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let innerDot = UIView()
    private let pulseLayer = CAShapeLayer()
    private var hasPillBg: Bool { !annotation.title.isEmpty }

    // ── Layout constants ──────────────────────────────────────────
    static let dotSize:          CGFloat = 10
    static let pillHeight:       CGFloat = 26
    static let hPad:             CGFloat = 8
    static let dotGap:           CGFloat = 5
    static var dotCenterXInPill: CGFloat { hPad + dotSize / 2 }

    static func pillSize(for ann: ImageAnnotation) -> CGSize {
        let h: CGFloat = pillHeight
        guard !ann.title.isEmpty else { return CGSize(width: hPad * 2 + dotSize, height: h) }
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.inter(ofSize: 12, weight: .semibold)]
        let textW = ceil((ann.title as NSString).size(withAttributes: attrs).width)
        return CGSize(width: min(hPad + dotSize + dotGap + textW + hPad, 200), height: h)
    }

    init(annotation: ImageAnnotation) {
        self.annotation = annotation
        self.pinColor   = UIColor(hex: annotation.colorHex) ?? DayPinDesign.accent
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        clipsToBounds = false

        // ── Dot first (title label constraints reference its anchor) ──
        innerDot.backgroundColor    = pinColor
        innerDot.layer.cornerRadius  = Self.dotSize / 2
        innerDot.layer.borderWidth   = 1.5
        innerDot.layer.borderColor   = UIColor.white.cgColor
        innerDot.translatesAutoresizingMaskIntoConstraints = false

        if hasPillBg {
            pillBg.layer.cornerRadius = Self.pillHeight / 2
            pillBg.clipsToBounds      = true
            pillBg.layer.borderWidth  = 1
            pillBg.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor
            pillBg.translatesAutoresizingMaskIntoConstraints = false
            addSubview(pillBg)
            NSLayoutConstraint.activate([
                pillBg.topAnchor.constraint(equalTo: topAnchor),
                pillBg.leadingAnchor.constraint(equalTo: leadingAnchor),
                pillBg.trailingAnchor.constraint(equalTo: trailingAnchor),
                pillBg.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])

            // Add dot to pill.contentView first, then set up title constraints against it
            pillBg.contentView.addSubview(innerDot)
            NSLayoutConstraint.activate([
                innerDot.centerYAnchor.constraint(equalTo: pillBg.contentView.centerYAnchor),
                innerDot.leadingAnchor.constraint(equalTo: pillBg.contentView.leadingAnchor, constant: Self.hPad),
                innerDot.widthAnchor.constraint(equalToConstant: Self.dotSize),
                innerDot.heightAnchor.constraint(equalToConstant: Self.dotSize)
            ])

            let titleLbl = UILabel()
            titleLbl.text      = annotation.title
            titleLbl.font      = .inter(ofSize: 12, weight: .semibold)
            titleLbl.textColor = UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }
            titleLbl.translatesAutoresizingMaskIntoConstraints = false
            pillBg.contentView.addSubview(titleLbl)
            NSLayoutConstraint.activate([
                titleLbl.leadingAnchor.constraint(equalTo: innerDot.trailingAnchor,           constant: Self.dotGap),
                titleLbl.centerYAnchor.constraint(equalTo: pillBg.contentView.centerYAnchor),
                titleLbl.trailingAnchor.constraint(equalTo: pillBg.contentView.trailingAnchor, constant: -Self.hPad)
            ])
        } else {
            addSubview(innerDot)
            NSLayoutConstraint.activate([
                innerDot.centerXAnchor.constraint(equalTo: centerXAnchor),
                innerDot.centerYAnchor.constraint(equalTo: centerYAnchor),
                innerDot.widthAnchor.constraint(equalToConstant: Self.dotSize),
                innerDot.heightAnchor.constraint(equalToConstant: Self.dotSize)
            ])
        }

        layer.shadowColor   = pinColor.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius  = 4
        layer.shadowOffset  = .zero

        pulseLayer.fillColor   = UIColor.clear.cgColor
        pulseLayer.strokeColor = pinColor.withAlphaComponent(0.65).cgColor
        pulseLayer.lineWidth   = 1.5
        layer.insertSublayer(pulseLayer, at: 0)

        startPulse()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r  = Self.dotSize / 2
        let cx = hasPillBg ? Self.dotCenterXInPill : bounds.midX
        let cy = bounds.midY
        pulseLayer.frame = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        pulseLayer.path  = UIBezierPath(arcCenter: CGPoint(x: r, y: r), radius: r,
                                        startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
    }

    private func startPulse() {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0; scale.toValue = 2.8
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.7; opacity.toValue = 0.0
        let group = CAAnimationGroup()
        group.animations = [scale, opacity]; group.duration = 2.2; group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulseLayer.add(group, forKey: "pulse")
        pulseLayer.opacity = 1
    }

    private func stopPulse() { pulseLayer.removeAllAnimations(); pulseLayer.opacity = 0 }

    private func updateState() {
        if isActive {
            stopPulse()
            UIView.animate(withDuration: 0.15) {
                self.innerDot.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                if self.hasPillBg {
                    self.pillBg.layer.borderColor = self.pinColor.withAlphaComponent(0.55).cgColor
                }
            }
        } else {
            UIView.animate(withDuration: 0.15) {
                self.innerDot.transform = .identity
                if self.hasPillBg {
                    self.pillBg.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
                }
            }
            startPulse()
        }
    }
}

// MARK: - PinCardView (compact)

private final class PinCardView: UIView {

    let annotationID: UUID
    var isActive: Bool = false { didSet { applyActiveState() } }

    var onActivate: (() -> Void)?
    var onSave:     ((String, String, String) -> Void)?
    var onDelete:   (() -> Void)?

    private var annotation: ImageAnnotation
    private let pinColor: UIColor

    private let cardBg          = GlassCardView(style: .thinLight)
    private let normalContainer = UIView()
    private let editContainer   = UIView()

    // Only one of these is active at a time — avoids the card being sized to the taller container
    private var normalBottomConstraint: NSLayoutConstraint?
    private var editBottomConstraint:   NSLayoutConstraint?

    private let colorDot   = UIView()
    private let titleLbl   = UILabel()
    private let descLbl    = UILabel()
    private let editBtn    = UIButton(type: .system)

    private let titleField = UITextField()
    private let descField  = UITextView()
    private let saveBtn    = UIButton(type: .system)
    private let cancelBtn  = UIButton(type: .system)
    private let deleteBtn  = UIButton(type: .system)

    init(annotation: ImageAnnotation) {
        self.annotation   = annotation
        self.annotationID = annotation.id
        self.pinColor     = UIColor(hex: annotation.colorHex) ?? DayPinDesign.accent
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        cardBg.cornerRadius = 12
        cardBg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardBg)
        NSLayoutConstraint.activate([
            cardBg.topAnchor.constraint(equalTo: topAnchor),
            cardBg.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardBg.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardBg.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        buildNormalMode()
        buildEditMode()
        editContainer.isHidden = true
    }

    private func buildNormalMode() {
        let cv = cardBg.glass.contentView
        normalContainer.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(normalContainer)
        // Bottom constraint stored separately — deactivated when switching to edit mode
        let nb = normalContainer.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
        nb.isActive = true
        normalBottomConstraint = nb
        NSLayoutConstraint.activate([
            normalContainer.topAnchor.constraint(equalTo: cv.topAnchor),
            normalContainer.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            normalContainer.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
        ])

        colorDot.backgroundColor    = pinColor
        colorDot.layer.cornerRadius  = 5
        colorDot.translatesAutoresizingMaskIntoConstraints = false

        titleLbl.text = annotation.title.isEmpty ? "-" : annotation.title
        titleLbl.font = .inter(ofSize: 13, weight: .semibold)
        titleLbl.textColor = .label; titleLbl.numberOfLines = 1
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        descLbl.text = annotation.text
        descLbl.font = .inter(ofSize: 12); descLbl.textColor = .secondaryLabel
        descLbl.numberOfLines = 1; descLbl.lineBreakMode = .byTruncatingTail
        descLbl.isHidden = annotation.text.isEmpty
        descLbl.translatesAutoresizingMaskIntoConstraints = false

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        editBtn.setImage(UIImage(systemName: "pencil", withConfiguration: iconCfg), for: .normal)
        editBtn.tintColor = .tertiaryLabel
        editBtn.translatesAutoresizingMaskIntoConstraints = false
        editBtn.addTarget(self, action: #selector(editTapped), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [titleLbl, descLbl])
        textStack.axis = .vertical; textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false

        normalContainer.addSubview(colorDot)
        normalContainer.addSubview(textStack)
        normalContainer.addSubview(editBtn)
        NSLayoutConstraint.activate([
            colorDot.leadingAnchor.constraint(equalTo: normalContainer.leadingAnchor, constant: 12),
            colorDot.centerYAnchor.constraint(equalTo: normalContainer.centerYAnchor),
            colorDot.widthAnchor.constraint(equalToConstant: 10),
            colorDot.heightAnchor.constraint(equalToConstant: 10),

            textStack.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor,     constant: 10),
            textStack.topAnchor.constraint(equalTo: normalContainer.topAnchor,       constant: 8),
            textStack.bottomAnchor.constraint(equalTo: normalContainer.bottomAnchor, constant: -8),
            textStack.trailingAnchor.constraint(equalTo: editBtn.leadingAnchor,      constant: -6),

            editBtn.trailingAnchor.constraint(equalTo: normalContainer.trailingAnchor, constant: -10),
            editBtn.centerYAnchor.constraint(equalTo: normalContainer.centerYAnchor),
            editBtn.widthAnchor.constraint(equalToConstant: 26),
            editBtn.heightAnchor.constraint(equalToConstant: 26)
        ])

        normalContainer.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(cardTapped)))
    }

    private func buildEditMode() {
        let cv = cardBg.glass.contentView
        editContainer.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(editContainer)
        // Bottom constraint stored separately — activated only when entering edit mode
        let eb = editContainer.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
        // NOT active initially — normalBottomConstraint drives the card height
        editBottomConstraint = eb
        NSLayoutConstraint.activate([
            editContainer.topAnchor.constraint(equalTo: cv.topAnchor),
            editContainer.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            editContainer.trailingAnchor.constraint(equalTo: cv.trailingAnchor)
        ])

        titleField.text = annotation.title; titleField.placeholder = L10n.pinTitlePlaceholder
        titleField.font = .inter(ofSize: 13, weight: .semibold); titleField.textColor = .label
        titleField.borderStyle = .none; titleField.returnKeyType = .next
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let sep1 = makeSep()

        descField.text = annotation.text; descField.font = .inter(ofSize: 13)
        descField.textColor = .label; descField.backgroundColor = .clear
        descField.isScrollEnabled = false
        descField.textContainerInset = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        descField.translatesAutoresizingMaskIntoConstraints = false

        let sep2 = makeSep()

        saveBtn.setTitle(L10n.save, for: .normal)
        saveBtn.titleLabel?.font = .inter(ofSize: 13, weight: .semibold)
        saveBtn.backgroundColor = DayPinDesign.accent; saveBtn.setTitleColor(UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }, for: .normal)
        saveBtn.layer.cornerRadius = 8
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        cancelBtn.setTitle(L10n.cancel, for: .normal)
        cancelBtn.titleLabel?.font = .inter(ofSize: 13)
        cancelBtn.setTitleColor(.secondaryLabel, for: .normal)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(cancelEditTapped), for: .touchUpInside)

        let btnRow = UIStackView(arrangedSubviews: [saveBtn, cancelBtn])
        btnRow.axis = .horizontal; btnRow.spacing = 8; btnRow.distribution = .fillEqually
        btnRow.translatesAutoresizingMaskIntoConstraints = false

        deleteBtn.setTitle(L10n.deletePin, for: .normal)
        deleteBtn.titleLabel?.font = .inter(ofSize: 12)
        deleteBtn.setTitleColor(.systemRed, for: .normal)
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        editContainer.addSubview(titleField); editContainer.addSubview(sep1)
        editContainer.addSubview(descField);  editContainer.addSubview(sep2)
        editContainer.addSubview(btnRow);     editContainer.addSubview(deleteBtn)
        descField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: editContainer.topAnchor,       constant: 8),
            titleField.leadingAnchor.constraint(equalTo: editContainer.leadingAnchor,    constant: 12),
            titleField.trailingAnchor.constraint(equalTo: editContainer.trailingAnchor,  constant: -12),
            titleField.heightAnchor.constraint(equalToConstant: 28),

            sep1.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 6),
            sep1.leadingAnchor.constraint(equalTo: editContainer.leadingAnchor),
            sep1.trailingAnchor.constraint(equalTo: editContainer.trailingAnchor),

            descField.topAnchor.constraint(equalTo: sep1.bottomAnchor),
            descField.leadingAnchor.constraint(equalTo: editContainer.leadingAnchor),
            descField.trailingAnchor.constraint(equalTo: editContainer.trailingAnchor),

            sep2.topAnchor.constraint(equalTo: descField.bottomAnchor),
            sep2.leadingAnchor.constraint(equalTo: editContainer.leadingAnchor),
            sep2.trailingAnchor.constraint(equalTo: editContainer.trailingAnchor),

            btnRow.topAnchor.constraint(equalTo: sep2.bottomAnchor,               constant: 8),
            btnRow.leadingAnchor.constraint(equalTo: editContainer.leadingAnchor,      constant: 12),
            btnRow.trailingAnchor.constraint(equalTo: editContainer.trailingAnchor,   constant: -12),
            btnRow.heightAnchor.constraint(equalToConstant: 32),

            deleteBtn.topAnchor.constraint(equalTo: btnRow.bottomAnchor,           constant: 4),
            deleteBtn.centerXAnchor.constraint(equalTo: editContainer.centerXAnchor),
            deleteBtn.bottomAnchor.constraint(equalTo: editContainer.bottomAnchor,  constant: -8)
        ])
    }

    private func makeSep() -> UIView {
        let v = UIView(); v.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true; return v
    }

    private func applyActiveState() {
        UIView.animate(withDuration: 0.2) {
            self.cardBg.glass.layer.borderColor = self.isActive
                ? self.pinColor.withAlphaComponent(0.5).cgColor
                : DayPinDesign.cardBorderColor.cgColor
            self.cardBg.glass.layer.borderWidth = self.isActive
                ? 1.5
                : DayPinDesign.cardBorderWidth(for: self.traitCollection)
        }
    }

    @objc private func cardTapped()      { onActivate?() }

    @objc private func editTapped() {
        titleField.text = annotation.title; descField.text = annotation.text
        // Swap bottom constraints so the card resizes to fit edit content
        normalBottomConstraint?.isActive = false
        editBottomConstraint?.isActive   = true
        UIView.transition(with: cardBg.glass.contentView, duration: 0.2, options: .transitionCrossDissolve) {
            self.normalContainer.isHidden = true; self.editContainer.isHidden = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.titleField.becomeFirstResponder() }
    }

    @objc private func saveTapped() {
        let newTitle = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newText  = descField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        titleField.resignFirstResponder(); descField.resignFirstResponder()
        closeEditMode(); onSave?(newTitle, newText, annotation.colorHex)
    }

    @objc private func cancelEditTapped() {
        titleField.resignFirstResponder(); descField.resignFirstResponder(); closeEditMode()
    }

    @objc private func deleteTapped() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        titleField.resignFirstResponder(); descField.resignFirstResponder(); onDelete?()
    }

    private func closeEditMode() {
        // Swap back so card shrinks to normal-mode height
        editBottomConstraint?.isActive   = false
        normalBottomConstraint?.isActive = true
        UIView.transition(with: cardBg.glass.contentView, duration: 0.2, options: .transitionCrossDissolve) {
            self.normalContainer.isHidden = false; self.editContainer.isHidden = true
        }
    }
}
