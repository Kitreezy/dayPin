import UIKit
import PhotosUI
import Photos

// MARK: - PhotoThumbCell

private final class PhotoThumbCell: UICollectionViewCell {
    static let reuseID = "PhotoThumbCell"
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

// MARK: - ImageCardEditorViewController

final class ImageCardEditorViewController: UIViewController {

    var onSave: ((ImageCard) -> Void)?

    private var currentImageData: Data?
    private let dayDate: Date
    private let existingCard: ImageCard?

    private let titleField     = UITextField()
    private let tagsInputView  = TagsInputView()
    private let zoomScrollView = UIScrollView()
    private let annotationView = ImageAnnotationView()
    private var annotations: [ImageAnnotation] = []

    private var recentAssets: [PHAsset] = []
    private var stripCollection: UICollectionView!
    private var stripContainer: UIView!
    private let imageManager = PHCachingImageManager()

    init(imageData: Data?, dayDate: Date, existingCard: ImageCard?) {
        self.currentImageData = imageData ?? existingCard?.imageData
        self.dayDate          = dayDate
        self.existingCard     = existingCard
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Extend view behind nav bar so photo fills edge-to-edge
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        view.backgroundColor = .black
        setupNav()
        setupUI()
        fillIfEditing()
        stripContainer.isHidden = false
        loadRecentPhotosIfAuthorized()
    }

    // MARK: - Nav

    private func setupNav() {
        // Transparent nav bar for this screen
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance   = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance    = appearance

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain, target: self, action: #selector(cancel)
        )
        navigationItem.leftBarButtonItem?.tintColor = .white

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.save, style: .done, target: self, action: #selector(save)
        )
        navigationItem.rightBarButtonItem?.tintColor = DayPinDesign.accentLight
    }

    // MARK: - UI

    private func setupUI() {
        // ── Zoom scroll view — full screen ──────────────────────
        zoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.minimumZoomScale = 1
        zoomScrollView.maximumZoomScale = 4
        zoomScrollView.delegate = self
        zoomScrollView.showsVerticalScrollIndicator   = false
        zoomScrollView.showsHorizontalScrollIndicator = false
        zoomScrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(zoomScrollView)

        annotationView.translatesAutoresizingMaskIntoConstraints = false
        annotationView.layer.cornerRadius = 0
        annotationView.delegate = self
        annotationView.zoomScrollView = zoomScrollView
        if let data = currentImageData {
            annotationView.image = UIImage(data: data)
        }
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

        // ── Title overlay pill — just below nav bar ─────────────
        let titleBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        titleBlur.layer.cornerRadius = 12
        titleBlur.clipsToBounds = true
        titleBlur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBlur)

        titleField.attributedPlaceholder = NSAttributedString(
            string: L10n.photoName,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        )
        titleField.font        = .inter(ofSize: 15, weight: .medium)
        titleField.textColor   = .white
        titleField.borderStyle = .none
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleBlur.contentView.addSubview(titleField)

        let changeBtn = UIButton(type: .system)
        let btnCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        changeBtn.setImage(UIImage(systemName: "photo.badge.arrow.down", withConfiguration: btnCfg), for: .normal)
        changeBtn.tintColor = UIColor.white.withAlphaComponent(0.75)
        changeBtn.addTarget(self, action: #selector(imageActionsTapped), for: .touchUpInside)
        changeBtn.translatesAutoresizingMaskIntoConstraints = false
        titleBlur.contentView.addSubview(changeBtn)

        NSLayoutConstraint.activate([
            titleBlur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            titleBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleBlur.heightAnchor.constraint(equalToConstant: 42),

            changeBtn.trailingAnchor.constraint(equalTo: titleBlur.contentView.trailingAnchor, constant: -12),
            changeBtn.centerYAnchor.constraint(equalTo: titleBlur.contentView.centerYAnchor),
            changeBtn.widthAnchor.constraint(equalToConstant: 30),

            titleField.leadingAnchor.constraint(equalTo: titleBlur.contentView.leadingAnchor, constant: 14),
            titleField.trailingAnchor.constraint(equalTo: changeBtn.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: titleBlur.contentView.centerYAnchor)
        ])

        // ── Tags row — floating blur pill above strip ─────────────
        let tagsBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        tagsBlur.layer.cornerRadius = 12
        tagsBlur.clipsToBounds = true
        tagsBlur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tagsBlur)

        tagsInputView.translatesAutoresizingMaskIntoConstraints = false
        tagsBlur.contentView.addSubview(tagsInputView)
        NSLayoutConstraint.activate([
            tagsInputView.topAnchor.constraint(equalTo: tagsBlur.contentView.topAnchor, constant: 4),
            tagsInputView.leadingAnchor.constraint(equalTo: tagsBlur.contentView.leadingAnchor, constant: 8),
            tagsInputView.trailingAnchor.constraint(equalTo: tagsBlur.contentView.trailingAnchor, constant: -8),
            tagsInputView.bottomAnchor.constraint(equalTo: tagsBlur.contentView.bottomAnchor, constant: -4)
        ])

        // ── Combined bottom panel: hint + photo strip ────────────
        let bottomPanel = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        bottomPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomPanel)
        stripContainer = bottomPanel

        // Top separator line
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        sep.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(sep)

        // Hint label
        let hintLabel = UILabel()
        hintLabel.text      = L10n.annotationHint
        hintLabel.font      = .inter(ofSize: 11, weight: .regular)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.50)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(hintLabel)

        // "Все фото" button — fixed on the right
        let allPhotosBtn = UIButton(type: .system)
        let allCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        allPhotosBtn.setImage(UIImage(systemName: "photo.stack", withConfiguration: allCfg), for: .normal)
        allPhotosBtn.tintColor = UIColor.white.withAlphaComponent(0.65)
        allPhotosBtn.addTarget(self, action: #selector(presentImagePicker), for: .touchUpInside)
        allPhotosBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(allPhotosBtn)

        // Strip divider (vertical, between strip and "Все фото" button)
        let vSep = UIView()
        vSep.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        vSep.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(vSep)

        // Horizontal photo strip
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 66, height: 66)
        layout.minimumLineSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)

        stripCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        stripCollection.backgroundColor = .clear
        stripCollection.showsHorizontalScrollIndicator = false
        stripCollection.register(PhotoThumbCell.self, forCellWithReuseIdentifier: PhotoThumbCell.reuseID)
        stripCollection.dataSource = self
        stripCollection.delegate   = self
        stripCollection.translatesAutoresizingMaskIntoConstraints = false
        bottomPanel.contentView.addSubview(stripCollection)

        NSLayoutConstraint.activate([
            // Tags row — just above bottom panel
            tagsBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tagsBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tagsBlur.bottomAnchor.constraint(equalTo: bottomPanel.topAnchor, constant: -8),
            tagsBlur.heightAnchor.constraint(equalToConstant: 44),

            // Panel sits just above the home indicator area
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Top separator
            sep.topAnchor.constraint(equalTo: bottomPanel.contentView.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bottomPanel.contentView.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: bottomPanel.contentView.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),

            // Hint label — top of panel
            hintLabel.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 8),
            hintLabel.centerXAnchor.constraint(equalTo: bottomPanel.contentView.centerXAnchor),

            // "Все фото" — fixed right, vertically centered in strip row
            allPhotosBtn.trailingAnchor.constraint(equalTo: bottomPanel.contentView.trailingAnchor),
            allPhotosBtn.widthAnchor.constraint(equalToConstant: 52),
            allPhotosBtn.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 6),
            allPhotosBtn.heightAnchor.constraint(equalToConstant: 66),

            // Vertical divider
            vSep.topAnchor.constraint(equalTo: allPhotosBtn.topAnchor, constant: 8),
            vSep.bottomAnchor.constraint(equalTo: allPhotosBtn.bottomAnchor, constant: -8),
            vSep.trailingAnchor.constraint(equalTo: allPhotosBtn.leadingAnchor),
            vSep.widthAnchor.constraint(equalToConstant: 0.5),

            // Strip collection
            stripCollection.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 6),
            stripCollection.leadingAnchor.constraint(equalTo: bottomPanel.contentView.leadingAnchor),
            stripCollection.trailingAnchor.constraint(equalTo: vSep.leadingAnchor),
            stripCollection.heightAnchor.constraint(equalToConstant: 66),
            stripCollection.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func fillIfEditing() {
        guard let card = existingCard else { return }
        titleField.text = card.title
        annotationView.image = card.imageData.flatMap { UIImage(data: $0) }
        annotations = card.annotations
        annotationView.load(annotations: annotations)
        tagsInputView.tagIDs = card.tagIDs
    }

    // MARK: - Recent Photos

    private func loadRecentPhotosIfAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            fetchRecentAssets()
        }
    }

    private func fetchRecentAssets() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 30
            let result = PHAsset.fetchAssets(with: .image, options: options)
            var assets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in assets.append(asset) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.recentAssets = assets
                self.stripCollection.reloadData()
            }
        }
    }

    private func applyAsset(_ asset: PHAsset) {
        let size = CGSize(width: 1080, height: 1080)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: opts) { [weak self] image, _ in
            guard let self, let image else { return }
            self.currentImageData = image.jpegData(compressionQuality: 0.85)
            self.annotationView.image = image
            self.annotations.removeAll()
            self.annotationView.load(annotations: [])
        }
    }

    // MARK: - Actions

    @objc private func imageActionsTapped() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        var actions: [GlassAction] = [
            GlassAction(L10n.cardPhoto, icon: "photo.on.rectangle") { [weak self] in self?.presentImagePicker() }
        ]
        if hasCamera {
            actions.append(GlassAction(L10n.cardCamera, icon: "camera") { [weak self] in self?.presentCamera() })
        }
        actions.append(GlassAction(L10n.delete, icon: "trash", style: .destructive) { [weak self] in
            self?.currentImageData = nil
            self?.annotationView.image = nil
            self?.annotations.removeAll()
            self?.annotationView.load(annotations: [])
        })
        actions.append(GlassAction(L10n.cancel, style: .cancel))
        GlassActionSheet.show(actions: actions, from: self)
    }

    @objc private func presentImagePicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = self
        present(picker, animated: true)
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let title = (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? L10n.newPhoto : title
        let saved = existingCard ?? ImageCard(title: finalTitle, dayDate: dayDate)
        saved.title       = finalTitle
        saved.imageData   = currentImageData
        saved.annotations = annotations
        saved.tagIDs      = tagsInputView.selectedTagIDs
        onSave?(saved)
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource (photo strip)

extension ImageCardEditorViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { recentAssets.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: PhotoThumbCell.reuseID, for: ip) as! PhotoThumbCell
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
}

// MARK: - UICollectionViewDelegate (photo strip)

extension ImageCardEditorViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        applyAsset(recentAssets[ip.item])
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - ImageAnnotationViewDelegate

extension ImageCardEditorViewController: ImageAnnotationViewDelegate {
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

// MARK: - UIScrollViewDelegate

extension ImageCardEditorViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView === zoomScrollView ? annotationView : nil
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ImageCardEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.currentImageData = image.jpegData(compressionQuality: 0.85)
                self?.annotationView.image = image
                self?.annotations.removeAll()
                self?.annotationView.load(annotations: [])
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ImageCardEditorViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        currentImageData = image?.jpegData(compressionQuality: 0.85)
        annotationView.image = image
        annotations.removeAll()
        annotationView.load(annotations: [])
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
