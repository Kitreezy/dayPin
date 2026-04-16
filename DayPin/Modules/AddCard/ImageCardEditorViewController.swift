import UIKit
import PhotosUI

final class ImageCardEditorViewController: UIViewController {

    var onSave: ((ImageCard) -> Void)?

    private var currentImageData: Data?
    private let dayDate: Date
    private let existingCard: ImageCard?

    private let titleField      = UITextField()
    private let zoomScrollView  = UIScrollView()
    private let annotationView  = ImageAnnotationView()
    private var annotations: [ImageAnnotation] = []

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
        title = existingCard == nil ? L10n.newPhoto : L10n.edit
        view.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark ? .black : UIColor(white: 0.10, alpha: 1)
        }
        setupNav()
        setupUI()
        fillIfEditing()
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(cancel)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.save,
            style: .done,
            target: self,
            action: #selector(save)
        )
    }

    // MARK: - UI

    private func setupUI() {
        // Full-screen zoom scroll view — same layout as detail view
        zoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.minimumZoomScale = 1
        zoomScrollView.maximumZoomScale = 4
        zoomScrollView.delegate = self
        zoomScrollView.showsVerticalScrollIndicator   = false
        zoomScrollView.showsHorizontalScrollIndicator = false
        view.addSubview(zoomScrollView)

        annotationView.translatesAutoresizingMaskIntoConstraints = false
        annotationView.layer.cornerRadius = 0
        annotationView.delegate = self
        annotationView.zoomScrollView = zoomScrollView
        if let data = currentImageData {
            annotationView.image = UIImage(data: data)
        }
        zoomScrollView.addSubview(annotationView)

        // Title overlay bar — blur pill below nav bar
        let titleBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        titleBlurView.layer.cornerRadius = 12
        titleBlurView.clipsToBounds = true
        titleBlurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBlurView)

        titleField.placeholder = L10n.photoName
        titleField.attributedPlaceholder = NSAttributedString(
            string: L10n.photoName,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        )
        titleField.font        = .systemFont(ofSize: 15, weight: .medium)
        titleField.textColor   = .white
        titleField.borderStyle = .none
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleBlurView.contentView.addSubview(titleField)

        // Change image button inside title bar
        let changeBtn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        changeBtn.setImage(UIImage(systemName: "photo.badge.arrow.down", withConfiguration: cfg), for: .normal)
        changeBtn.tintColor = UIColor.white.withAlphaComponent(0.75)
        changeBtn.addTarget(self, action: #selector(imageActionsTapped), for: .touchUpInside)
        changeBtn.translatesAutoresizingMaskIntoConstraints = false
        titleBlurView.contentView.addSubview(changeBtn)

        // Hint badge at bottom
        let hintBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        hintBlur.layer.cornerRadius = 12
        hintBlur.clipsToBounds = true
        hintBlur.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = UILabel()
        hintLabel.text      = L10n.annotationHint
        hintLabel.font      = .systemFont(ofSize: 12)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintBlur.contentView.addSubview(hintLabel)
        view.addSubview(hintBlur)

        NSLayoutConstraint.activate([
            // Scroll view fills safe area (nav bar excluded)
            zoomScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            zoomScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zoomScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // Annotation view fills scroll view frame
            annotationView.leadingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.leadingAnchor),
            annotationView.trailingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.trailingAnchor),
            annotationView.topAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.topAnchor),
            annotationView.bottomAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.bottomAnchor),
            annotationView.widthAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.widthAnchor),
            annotationView.heightAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.heightAnchor),

            // Title overlay
            titleBlurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            titleBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleBlurView.heightAnchor.constraint(equalToConstant: 44),

            changeBtn.trailingAnchor.constraint(equalTo: titleBlurView.contentView.trailingAnchor, constant: -12),
            changeBtn.centerYAnchor.constraint(equalTo: titleBlurView.contentView.centerYAnchor),
            changeBtn.widthAnchor.constraint(equalToConstant: 30),

            titleField.leadingAnchor.constraint(equalTo: titleBlurView.contentView.leadingAnchor, constant: 14),
            titleField.trailingAnchor.constraint(equalTo: changeBtn.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: titleBlurView.contentView.centerYAnchor),

            // Hint badge
            hintLabel.topAnchor.constraint(equalTo: hintBlur.contentView.topAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: hintBlur.contentView.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: hintBlur.contentView.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: hintBlur.contentView.bottomAnchor, constant: -6),

            hintBlur.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintBlur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func fillIfEditing() {
        guard let card = existingCard else { return }
        titleField.text = card.title
        annotationView.image = card.imageData.flatMap { UIImage(data: $0) }
        annotations = card.annotations
        annotationView.load(annotations: annotations)
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

    private func presentImagePicker() {
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
        saved.title      = finalTitle
        saved.imageData  = currentImageData
        saved.annotations = annotations
        onSave?(saved)
        dismiss(animated: true)
    }
}

// MARK: - ImageAnnotationViewDelegate

extension ImageCardEditorViewController: ImageAnnotationViewDelegate {
    func annotationView(_ view: ImageAnnotationView, didAddAnnotation annotation: ImageAnnotation) {
        annotations.append(annotation)
    }
    func annotationView(_ view: ImageAnnotationView, didUpdateAnnotation annotation: ImageAnnotation) {
        if let i = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[i] = annotation
        }
    }
    func annotationView(_ view: ImageAnnotationView, didDeleteAnnotation annotation: ImageAnnotation) {
        annotations.removeAll { $0.id == annotation.id }
    }
}

// MARK: - UIScrollViewDelegate

extension ImageCardEditorViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { annotationView }
}

// MARK: - PHPickerViewControllerDelegate

extension ImageCardEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
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
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
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
