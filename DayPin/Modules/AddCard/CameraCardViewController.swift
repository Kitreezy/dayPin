import UIKit
import AVFoundation
import Photos
import PhotosUI

// MARK: - CameraCardViewController

/// Unified camera capture + image card editor in one screen.
///
/// Two start modes:
///   - `.camera`  — opens with live camera preview, capture → edit state
///   - `.gallery` — opens directly in edit state (no camera), bottom strip is prominent
///
/// Two internal states:
///   - `.camera` — live preview, capture button, flip/flash controls
///   - `.edit`   — captured/picked photo with annotation, title, tags, retake
final class CameraCardViewController: UIViewController {

    // MARK: - Public API

    enum StartMode { case camera, gallery }

    var onSave: ((ImageCard) -> Void)?

    // MARK: - Init

    init(startMode: StartMode, dayDate: Date, existingCard: ImageCard? = nil) {
        self.startMode = startMode
        self.dayDate = dayDate
        self.existingCard = existingCard
        // Existing card or gallery mode → skip camera state
        self.captureState = (existingCard != nil || startMode == .gallery) ? .edit : .camera
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Private types

    private enum CaptureState { case camera, edit }

    // MARK: - Config

    private let startMode: StartMode
    private let dayDate: Date
    private let existingCard: ImageCard?

    // MARK: - State

    private var captureState: CaptureState
    private var currentImageData: Data?
    private var annotations: [ImageAnnotation] = []

    // MARK: - AVFoundation

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.daypin.camera.session", qos: .userInteractive)
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var isFlashOn = false
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Views: Camera state

    private let previewContainer = UIView()
    private let captureButton    = UIButton()
    private let flipButton       = UIButton()
    private let flashButton      = UIButton()

    // MARK: - Views: Edit state

    private let zoomScrollView       = UIScrollView()
    private let annotationView       = ImageAnnotationView()
    private let changePhotoOverlayBtn = UIButton()
    private let retakeButton         = UIButton()

    // MARK: - Views: Shared (visible in both states)

    /// Glass top bar: cancel (left) | title field (center) | save (right).
    private let topBar       = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let cancelButton = UIButton()
    private let titleField   = UITextField()
    private let saveButton   = UIButton()
    private let bottomPanel  = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private var stripCollection: UICollectionView?

    /// Tags row lives inside bottomPanel (edit state only, height animates 0 <-> 44).
    private let tagsRowView  = UIView()
    private let tagsInputView = TagsInputView()
    private var tagsRowHeightConstraint: NSLayoutConstraint?

    // MARK: - Photo strip data

    private var recentAssets: [PHAsset] = []
    private let imageManager  = PHCachingImageManager()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSharedUI()
        setupCameraUI()
        setupEditUI()
        applyState(animated: false)
        loadRecentPhotosIfAuthorized()
        observeNotifications()
        addKeyboardDismissGesture()
        if captureState == .camera {
            requestCameraAccessAndSetup()
        } else {
            fillExistingCardIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureState == .camera {
            sessionQueue.async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            if self?.session.isRunning == true {
                self?.session.stopRunning()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewContainer.bounds
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        titleField.attributedPlaceholder = makeWhitePlaceholder(L10n.photoName)
    }

    @objc private func onColorSchemeChanged() {
        // Always dark UI on this screen — nothing to refresh
    }

    // MARK: - UI Setup: Shared

    private func setupSharedUI() {
        // ── Top bar: cancel | title | save ─────────────────────
        topBar.layer.cornerRadius = 0
        topBar.clipsToBounds = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        // Cancel (always visible)
        cancelButton.setImage(sysImage("xmark", size: 15, weight: .semibold), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.20)
        cancelButton.layer.cornerRadius = 18
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.contentView.addSubview(cancelButton)

        // Title field — centered between cancel and save (edit state only)
        titleField.attributedPlaceholder = makeWhitePlaceholder(L10n.photoName)
        titleField.font = .inter(ofSize: 15, weight: .medium)
        titleField.textColor = .white
        titleField.textAlignment = .center
        titleField.borderStyle = .none
        titleField.translatesAutoresizingMaskIntoConstraints = false
        topBar.contentView.addSubview(titleField)

        // Save (visible in edit state only)
        saveButton.setTitle(L10n.save, for: .normal)
        saveButton.setTitleColor(DayPinDesign.accentLight, for: .normal)
        saveButton.titleLabel?.font = .inter(ofSize: 15, weight: .semibold)
        saveButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        saveButton.layer.cornerRadius = 18
        saveButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.contentView.addSubview(saveButton)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),

            cancelButton.leadingAnchor.constraint(equalTo: topBar.contentView.leadingAnchor, constant: 16),
            cancelButton.bottomAnchor.constraint(equalTo: topBar.contentView.bottomAnchor, constant: -10),
            cancelButton.widthAnchor.constraint(equalToConstant: 36),
            cancelButton.heightAnchor.constraint(equalToConstant: 36),

            titleField.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            titleField.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),

            saveButton.trailingAnchor.constraint(equalTo: topBar.contentView.trailingAnchor, constant: -16),
            saveButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        // ── Bottom panel: tags row + hint + thumbnail strip ────
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomPanel)

        // Top divider
        let topSep = UIView()
        topSep.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        topSep.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(topSep)

        // Tags row (height animates 0 <-> 44 based on camera/edit state)
        tagsRowView.clipsToBounds = true
        tagsRowView.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(tagsRowView)

        tagsInputView.translatesAutoresizingMaskIntoConstraints = false
        tagsRowView.addSubview(tagsInputView)

        let tagsRowSep = UIView()
        tagsRowSep.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        tagsRowSep.translatesAutoresizingMaskIntoConstraints = false
        tagsRowView.addSubview(tagsRowSep)

        let tagsH = tagsRowView.heightAnchor.constraint(equalToConstant: 0)
        tagsRowHeightConstraint = tagsH

        // Hint label
        let hintLabel = UILabel()
        hintLabel.text = L10n.annotationHint
        hintLabel.font = .inter(ofSize: 11, weight: .regular)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(hintLabel)

        // All photos button
        let allBtn = makeIconButton(systemName: "photo.stack", size: 18)
        allBtn.addTarget(self, action: #selector(allPhotosTapped), for: .touchUpInside)
        allBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(allBtn)

        let vSep = UIView()
        vSep.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        vSep.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(vSep)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 66, height: 66)
        layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(CameraThumbCell.self, forCellWithReuseIdentifier: CameraThumbCell.reuseID)
        cv.dataSource = self
        cv.delegate   = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(cv)
        stripCollection = cv

        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topSep.topAnchor.constraint(equalTo: bottomPanel.contentView.topAnchor),
            topSep.leadingAnchor.constraint(equalTo: bottomPanel.contentView.leadingAnchor),
            topSep.trailingAnchor.constraint(equalTo: bottomPanel.contentView.trailingAnchor),
            topSep.heightAnchor.constraint(equalToConstant: 0.5),

            tagsRowView.topAnchor.constraint(equalTo: topSep.bottomAnchor),
            tagsRowView.leadingAnchor.constraint(equalTo: bottomPanel.contentView.leadingAnchor),
            tagsRowView.trailingAnchor.constraint(equalTo: bottomPanel.contentView.trailingAnchor),
            tagsH,

            tagsInputView.topAnchor.constraint(equalTo: tagsRowView.topAnchor, constant: 4),
            tagsInputView.leadingAnchor.constraint(equalTo: tagsRowView.leadingAnchor, constant: 8),
            tagsInputView.trailingAnchor.constraint(equalTo: tagsRowView.trailingAnchor, constant: -8),
            tagsInputView.bottomAnchor.constraint(equalTo: tagsRowSep.topAnchor, constant: -4),

            tagsRowSep.bottomAnchor.constraint(equalTo: tagsRowView.bottomAnchor),
            tagsRowSep.leadingAnchor.constraint(equalTo: tagsRowView.leadingAnchor),
            tagsRowSep.trailingAnchor.constraint(equalTo: tagsRowView.trailingAnchor),
            tagsRowSep.heightAnchor.constraint(equalToConstant: 0.5),

            hintLabel.topAnchor.constraint(equalTo: tagsRowView.bottomAnchor, constant: 8),
            hintLabel.centerXAnchor.constraint(equalTo: bottomPanel.contentView.centerXAnchor),

            allBtn.trailingAnchor.constraint(equalTo: bottomPanel.contentView.trailingAnchor),
            allBtn.widthAnchor.constraint(equalToConstant: 52),
            allBtn.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 6),
            allBtn.heightAnchor.constraint(equalToConstant: 66),

            vSep.topAnchor.constraint(equalTo: allBtn.topAnchor, constant: 8),
            vSep.bottomAnchor.constraint(equalTo: allBtn.bottomAnchor, constant: -8),
            vSep.trailingAnchor.constraint(equalTo: allBtn.leadingAnchor),
            vSep.widthAnchor.constraint(equalToConstant: 0.5),

            cv.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 6),
            cv.leadingAnchor.constraint(equalTo: bottomPanel.contentView.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: vSep.leadingAnchor),
            cv.heightAnchor.constraint(equalToConstant: 66),
            cv.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - UI Setup: Camera state

    private func setupCameraUI() {
        // Camera preview container
        previewContainer.backgroundColor = .black
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(previewContainer, at: 0)
        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor)
        ])

        // Capture button
        captureButton.layer.cornerRadius = 38
        captureButton.layer.borderWidth  = 4
        captureButton.layer.borderColor  = UIColor.white.cgColor
        captureButton.backgroundColor    = UIColor.white.withAlphaComponent(0.90)
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)

        // Flip button (switch front/back)
        flipButton.setImage(sysImage("arrow.triangle.2.circlepath.camera", size: 22, weight: .medium), for: .normal)
        flipButton.tintColor   = .white
        flipButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        flipButton.layer.cornerRadius = 24
        flipButton.addTarget(self, action: #selector(flipCamera), for: .touchUpInside)
        flipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flipButton)

        // Flash button
        flashButton.setImage(sysImage("bolt.slash.fill", size: 18, weight: .medium), for: .normal)
        flashButton.tintColor  = .white
        flashButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        flashButton.layer.cornerRadius = 24
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flashButton)

        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 76),
            captureButton.heightAnchor.constraint(equalToConstant: 76),

            flipButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            flipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            flipButton.widthAnchor.constraint(equalToConstant: 48),
            flipButton.heightAnchor.constraint(equalToConstant: 48),

            flashButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            flashButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            flashButton.widthAnchor.constraint(equalToConstant: 48),
            flashButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - UI Setup: Edit state

    private func setupEditUI() {
        // Full-screen zoom/annotation view
        zoomScrollView.minimumZoomScale = 1
        zoomScrollView.maximumZoomScale = 4
        zoomScrollView.delegate = self
        zoomScrollView.showsVerticalScrollIndicator   = false
        zoomScrollView.showsHorizontalScrollIndicator = false
        zoomScrollView.contentInsetAdjustmentBehavior = .never
        zoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(zoomScrollView, aboveSubview: previewContainer)

        annotationView.delegate       = self
        annotationView.zoomScrollView = zoomScrollView
        annotationView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.addSubview(annotationView)

        NSLayoutConstraint.activate([
            zoomScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            zoomScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zoomScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            annotationView.leadingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.leadingAnchor),
            annotationView.trailingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.trailingAnchor),
            annotationView.topAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.topAnchor),
            annotationView.bottomAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.bottomAnchor),
            annotationView.widthAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.widthAnchor),
            annotationView.heightAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.heightAnchor)
        ])

        // Change photo overlay — circle button, bottom-right above bottomPanel
        changePhotoOverlayBtn.setImage(sysImage("camera.badge.ellipsis", size: 18, weight: .medium), for: .normal)
        changePhotoOverlayBtn.tintColor = .white
        changePhotoOverlayBtn.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        changePhotoOverlayBtn.layer.cornerRadius = 22
        changePhotoOverlayBtn.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        changePhotoOverlayBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(changePhotoOverlayBtn)

        // Retake — pill button, bottom-left above bottomPanel (camera start mode only)
        retakeButton.setTitle(L10n.isRussian ? "Переснять" : "Retake", for: .normal)
        retakeButton.setTitleColor(.white, for: .normal)
        retakeButton.titleLabel?.font = .inter(ofSize: 14, weight: .medium)
        retakeButton.backgroundColor  = UIColor.white.withAlphaComponent(0.18)
        retakeButton.layer.cornerRadius = 20
        retakeButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        retakeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(retakeButton)

        NSLayoutConstraint.activate([
            changePhotoOverlayBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            changePhotoOverlayBtn.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -14),
            changePhotoOverlayBtn.widthAnchor.constraint(equalToConstant: 44),
            changePhotoOverlayBtn.heightAnchor.constraint(equalToConstant: 44),

            retakeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            retakeButton.centerYAnchor.constraint(equalTo: changePhotoOverlayBtn.centerYAnchor),
            retakeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    // MARK: - Fill existing card

    private func fillExistingCardIfNeeded() {
        if let card = existingCard {
            titleField.text = card.title
            annotations     = card.annotations
            tagsInputView.tagIDs = card.tagIDs
            currentImageData = card.imageData
            annotationView.image = card.imageData.flatMap { UIImage(data: $0) }
            annotationView.load(annotations: annotations)
        }
    }

    // MARK: - State transitions

    private func applyState(animated: Bool) {
        let isCam = captureState == .camera
        let dur: TimeInterval = animated ? 0.28 : 0

        // Save button only in edit state
        saveButton.isHidden = isCam

        // Animate tags row height (0 in camera, 44 in edit)
        tagsRowHeightConstraint?.constant = isCam ? 0 : 44

        let editAlpha: CGFloat = isCam ? 0 : 1
        let camAlpha:  CGFloat = isCam ? 1 : 0

        let block = {
            self.previewContainer.alpha    = camAlpha
            self.captureButton.alpha       = camAlpha
            self.flipButton.alpha          = camAlpha
            self.flashButton.alpha         = camAlpha

            self.zoomScrollView.alpha          = editAlpha
            self.titleField.alpha              = editAlpha
            self.changePhotoOverlayBtn.alpha   = editAlpha
            self.retakeButton.alpha            = editAlpha
            // Hide retake if gallery start mode
            if self.startMode == .gallery { self.retakeButton.alpha = 0 }

            // Animate tags row height together with other views
            self.view.layoutIfNeeded()

            // Disable interaction on invisible views so they don't intercept touches
            self.captureButton.isUserInteractionEnabled         = isCam
            self.flipButton.isUserInteractionEnabled            = isCam
            self.flashButton.isUserInteractionEnabled           = isCam
            self.zoomScrollView.isUserInteractionEnabled        = !isCam
            self.titleField.isUserInteractionEnabled            = !isCam
            self.changePhotoOverlayBtn.isUserInteractionEnabled = !isCam
            self.retakeButton.isUserInteractionEnabled          = !isCam && self.startMode == .camera
        }

        if animated {
            UIView.animate(withDuration: dur, delay: 0, options: .curveEaseInOut, animations: block)
        } else {
            block()
        }
    }

    private func transitionToEditState(image: UIImage) {
        annotationView.image = image
        annotations.removeAll()
        annotationView.load(annotations: [])
        captureState = .edit

        // Stop camera session off main thread
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.3) {
            self.applyState(animated: false)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func transitionToCameraState() {
        guard startMode == .camera else { return }
        captureState = .camera
        annotationView.image = nil
        annotations.removeAll()
        annotationView.load(annotations: [])
        currentImageData = nil

        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }

        UIView.animate(withDuration: 0.28) {
            self.applyState(animated: false)
        }
    }

    // MARK: - AVFoundation setup

    private func requestCameraAccessAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupCaptureSession() }
                }
            }
        default:
            // Camera not available — fall back to gallery mode
            captureState = .edit
            applyState(animated: false)
        }
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // Input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: self.currentCameraPosition),
                  let input  = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            // Output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()

            // Preview layer — must be on main thread
            DispatchQueue.main.async {
                let layer = AVCaptureVideoPreviewLayer(session: self.session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = self.previewContainer.bounds
                self.previewContainer.layer.insertSublayer(layer, at: 0)
                self.previewLayer = layer
            }
        }
    }

    // MARK: - Camera actions

    @objc private func capturePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Animate shutter flash
        let flash = UIView(frame: view.bounds)
        flash.backgroundColor = .white
        flash.alpha = 0
        view.addSubview(flash)
        UIView.animate(withDuration: 0.08, animations: { flash.alpha = 0.9 }) { _ in
            UIView.animate(withDuration: 0.20) { flash.alpha = 0 } completion: { _ in flash.removeFromSuperview() }
        }

        let settings = AVCapturePhotoSettings()
        if isFlashOn { settings.flashMode = .on }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func flipCamera() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        currentCameraPosition = currentCameraPosition == .back ? .front : .back

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            // Remove existing inputs
            self.session.inputs.forEach { self.session.removeInput($0) }
            // Add new input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: self.currentCameraPosition),
                  let input  = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)
            self.session.commitConfiguration()
        }
    }

    @objc private func toggleFlash() {
        isFlashOn.toggle()
        let name = isFlashOn ? "bolt.fill" : "bolt.slash.fill"
        flashButton.setImage(sysImage(name, size: 18, weight: .medium), for: .normal)
        flashButton.tintColor = isFlashOn ? DayPinDesign.accentLight : .white
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Edit actions

    @objc private func retakeTapped() {
        guard startMode == .camera else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        transitionToCameraState()
    }

    @objc private func changePhotoTapped() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera) && startMode == .camera
        var actions: [GlassAction] = [
            GlassAction(L10n.cardPhoto, icon: "photo.on.rectangle") { [weak self] in
                self?.presentAllPhotoPicker()
            }
        ]
        if hasCamera {
            actions.append(GlassAction(L10n.cardCamera, icon: "camera") { [weak self] in
                self?.transitionToCameraState()
            })
        }
        if currentImageData != nil {
            actions.append(GlassAction(L10n.delete, icon: "trash", style: .destructive) { [weak self] in
                self?.currentImageData = nil
                self?.annotationView.image = nil
                self?.annotations.removeAll()
                self?.annotationView.load(annotations: [])
            })
        }
        actions.append(GlassAction(L10n.cancel, style: .cancel))
        GlassActionSheet.show(actions: actions, from: self)
    }

    // MARK: - Photo library

    private func loadRecentPhotosIfAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited { fetchRecentAssets() }
    }

    private func fetchRecentAssets() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            opts.fetchLimit = 30
            let result = PHAsset.fetchAssets(with: .image, options: opts)
            var list: [PHAsset] = []
            result.enumerateObjects { a, _, _ in list.append(a) }
            DispatchQueue.main.async {
                self?.recentAssets = list
                self?.stripCollection?.reloadData()
            }
        }
    }

    private func applyAsset(_ asset: PHAsset) {
        let size = CGSize(width: 1080, height: 1080)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        imageManager.requestImage(for: asset, targetSize: size,
                                  contentMode: .aspectFit, options: opts) { [weak self] image, _ in
            guard let self, let image else { return }
            self.currentImageData = image.jpegData(compressionQuality: 0.85)
            if self.captureState == .edit {
                self.annotationView.image = image
                self.annotations.removeAll()
                self.annotationView.load(annotations: [])
            } else {
                self.transitionToEditState(image: image)
            }
        }
    }

    @objc private func allPhotosTapped() {
        presentAllPhotoPicker()
    }

    private func presentAllPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Global actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let title = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? L10n.newPhoto : title

        let card = existingCard ?? ImageCard(title: finalTitle, dayDate: dayDate)
        card.title     = finalTitle
        card.imageData = currentImageData
        card.annotations = annotations
        card.tagIDs    = tagsInputView.selectedTagIDs

        onSave?(card)
        dismiss(animated: true)
    }

    // MARK: - Helpers

    private func sysImage(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight) -> UIImage? {
        UIImage(systemName: name,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
    }

    private func makeIconButton(systemName: String, size: CGFloat) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(sysImage(systemName, size: size, weight: .medium), for: .normal)
        btn.tintColor = UIColor.white.withAlphaComponent(0.75)
        return btn
    }

    private func makeWhitePlaceholder(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text,
                           attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.4)])
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraCardViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data  = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        currentImageData = data

        DispatchQueue.main.async { [weak self] in
            self?.transitionToEditState(image: image)
        }
    }
}

// MARK: - UIScrollViewDelegate (zoom)

extension CameraCardViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView === zoomScrollView ? annotationView : nil
    }
}

// MARK: - ImageAnnotationViewDelegate

extension CameraCardViewController: ImageAnnotationViewDelegate {
    func annotationView(_ view: ImageAnnotationView, didAddAnnotation annotation: ImageAnnotation) {
        annotations.append(annotation)
    }
    func annotationView(_ view: ImageAnnotationView, didUpdateAnnotation annotation: ImageAnnotation) {
        if let i = annotations.firstIndex(where: { $0.id == annotation.id }) { annotations[i] = annotation }
    }
    func annotationView(_ view: ImageAnnotationView, didDeleteAnnotation annotation: ImageAnnotation) {
        annotations.removeAll { $0.id == annotation.id }
    }
}

// MARK: - UICollectionViewDataSource + Delegate (photo strip)

extension CameraCardViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int {
        recentAssets.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        guard let cell = cv.dequeueReusableCell(withReuseIdentifier: CameraThumbCell.reuseID,
                                                for: ip) as? CameraThumbCell else {
            return UICollectionViewCell()
        }
        let asset = recentAssets[ip.item]
        cell.representedID = asset.localIdentifier
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = false
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 132, height: 132),
                                  contentMode: .aspectFill, options: opts) { img, _ in
            guard cell.representedID == asset.localIdentifier else { return }
            cell.imageView.image = img
        }
        return cell
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        applyAsset(recentAssets[ip.item])
    }
}

// MARK: - PHPickerViewControllerDelegate

extension CameraCardViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.currentImageData = image.jpegData(compressionQuality: 0.85)
                if self?.captureState == .edit {
                    self?.annotationView.image = image
                    self?.annotations.removeAll()
                    self?.annotationView.load(annotations: [])
                } else {
                    self?.transitionToEditState(image: image)
                }
            }
        }
    }
}

// MARK: - CameraThumbCell

private final class CameraThumbCell: UICollectionViewCell {

    static let reuseID = "CameraThumbCell"
    let imageView = UIImageView()
    var representedID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet { UIView.animate(withDuration: 0.1) { self.alpha = self.isHighlighted ? 0.6 : 1 } }
    }
}
