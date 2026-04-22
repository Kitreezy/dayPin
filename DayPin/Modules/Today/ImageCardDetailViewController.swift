import UIKit

final class ImageCardDetailViewController: UIViewController {

    private let card: ImageCard
    private let zoomScrollView = UIScrollView()
    private let annotationView = ImageAnnotationView()
    private var annotations: [ImageAnnotation]

    init(card: ImageCard) {
        self.card        = card
        self.annotations = card.annotations
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupFloatingControls()
        setupHint()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Re-enable swipe-back after nav bar is hidden
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Core UI

    private func setupUI() {
        zoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.minimumZoomScale = 1
        zoomScrollView.maximumZoomScale = 5
        zoomScrollView.delegate = self
        zoomScrollView.showsVerticalScrollIndicator   = false
        zoomScrollView.showsHorizontalScrollIndicator = false
        zoomScrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(zoomScrollView)

        annotationView.translatesAutoresizingMaskIntoConstraints = false
        annotationView.layer.cornerRadius = 0
        annotationView.image = card.imageData.flatMap { UIImage(data: $0) }
        annotationView.delegate = self
        annotationView.zoomScrollView = zoomScrollView
        annotationView.load(annotations: annotations)
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
    }

    // MARK: - Floating Controls

    private func setupFloatingControls() {
        // Back pill — top-left
        let backBlur = makeBlurPill()
        let backIcon = UIImageView(image: UIImage(systemName: "chevron.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        backIcon.tintColor = .white
        backIcon.translatesAutoresizingMaskIntoConstraints = false
        backBlur.contentView.addSubview(backIcon)
        NSLayoutConstraint.activate([
            backIcon.centerXAnchor.constraint(equalTo: backBlur.contentView.centerXAnchor),
            backIcon.centerYAnchor.constraint(equalTo: backBlur.contentView.centerYAnchor)
        ])
        backBlur.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(goBack)))
        view.addSubview(backBlur)

        // Right pills stack (edit, list, more)
        let editBlur  = makePillButton(icon: "pencil",          action: #selector(editCard))
        let listBlur  = makePillButton(icon: "list.bullet",     action: #selector(showPinList))
        let moreBlur  = makePillButton(icon: "ellipsis",        action: #selector(moreTapped))

        let rightStack = UIStackView(arrangedSubviews: [editBlur, listBlur, moreBlur])
        rightStack.axis = .horizontal
        rightStack.spacing = 8
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rightStack)

        NSLayoutConstraint.activate([
            backBlur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backBlur.widthAnchor.constraint(equalToConstant: 36),
            backBlur.heightAnchor.constraint(equalToConstant: 36),

            rightStack.centerYAnchor.constraint(equalTo: backBlur.centerYAnchor),
            rightStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func makeBlurPill() -> UIVisualEffectView {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        v.layer.cornerRadius = 18
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func makePillButton(icon: String, action: Selector) -> UIVisualEffectView {
        let blur = makeBlurPill()
        let img = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        img.tintColor = .white
        img.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(img)
        NSLayoutConstraint.activate([
            img.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            img.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            blur.widthAnchor.constraint(equalToConstant: 36),
            blur.heightAnchor.constraint(equalToConstant: 36)
        ])
        blur.addGestureRecognizer(UITapGestureRecognizer(target: self, action: action))
        return blur
    }

    // MARK: - Hint badge

    private func setupHint() {
        let hintBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        hintBlur.layer.cornerRadius = 12
        hintBlur.clipsToBounds = true
        hintBlur.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = UILabel()
        hintLabel.text = L10n.annotationHint
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintBlur.contentView.addSubview(hintLabel)
        view.addSubview(hintBlur)

        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: hintBlur.contentView.topAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: hintBlur.contentView.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: hintBlur.contentView.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: hintBlur.contentView.bottomAnchor, constant: -6),

            hintBlur.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintBlur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Actions

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func editCard() {
        let vc = ImageCardEditorViewController(imageData: card.imageData, dayDate: card.dayDate, existingCard: card)
        vc.onSave = { [weak self] saved in
            guard let self else { return }
            self.card.title       = saved.title
            self.card.imageData   = saved.imageData
            self.card.annotations = saved.annotations
            self.annotations      = saved.annotations
            self.annotationView.image = saved.imageData.flatMap { UIImage(data: $0) }
            self.annotationView.load(annotations: self.annotations)
            self.persist()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc private func showPinList() {
        guard !annotations.isEmpty else { return }
        let vc = PinListViewController(annotations: annotations)
        vc.onSelectPin = { [weak self] annotation in self?.focusOnAnnotation(annotation) }
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(vc, animated: true)
    }

    @objc private func moreTapped() {
        let shareAction  = UIAction(title: "Поделиться",        image: UIImage(systemName: "square.and.arrow.up"))   { [weak self] _ in self?.share() }
        let copyAction   = UIAction(title: "Скопировать в день", image: UIImage(systemName: "calendar.badge.plus")) { [weak self] _ in self?.copyToDay() }
        let folderAction = UIAction(title: "В папку",            image: UIImage(systemName: "folder.badge.plus"))   { [weak self] _ in self?.addToFolder() }
        let menu = UIMenu(children: [shareAction, copyAction, folderAction])
        let config = UIButton.Configuration.plain()
        let btn = UIButton(configuration: config)
        btn.menu = menu
        btn.showsMenuAsPrimaryAction = true
        btn.sendActions(for: .menuActionTriggered)
        // Show as action sheet on iOS 14+
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Поделиться", style: .default) { [weak self] _ in self?.share() })
        alert.addAction(UIAlertAction(title: "Скопировать в день", style: .default) { [weak self] _ in self?.copyToDay() })
        alert.addAction(UIAlertAction(title: "В папку", style: .default) { [weak self] _ in self?.addToFolder() })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func share() {
        var items: [Any] = [card.title]
        if let data = card.imageData, let image = UIImage(data: data) { items.append(image) }
        let notes = annotations.map { "• \($0.text)" }.joined(separator: "\n")
        if !notes.isEmpty { items.append(notes) }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }

    private func copyToDay() {
        let vc = CopyToDayViewController()
        vc.onCopy = { [weak self] date in
            guard let self else { return }
            CardStore.shared.save(card: self.card.duplicated(to: date))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func addToFolder() {
        let folders = FolderStore.shared.all()
        let sheet = UIAlertController(title: "Добавить в папку", message: nil, preferredStyle: .actionSheet)
        for folder in folders {
            let isCurrent = card.folderID == folder.id
            let title = isCurrent ? "✓ \(folder.name)" : folder.name
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                self.card.folderID = isCurrent ? nil : folder.id
                CardStore.shared.save(card: self.card)
            })
        }
        if folders.isEmpty {
            sheet.addAction(UIAlertAction(title: "Нет папок — создайте во вкладке «Папки»", style: .default, handler: nil))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    func focusOnAnnotation(_ annotation: ImageAnnotation) {
        let pinCenter = annotationView.localPoint(for: annotation)
        let targetZoom: CGFloat = 2.5
        let svSize = zoomScrollView.bounds.size
        let zoomRect = CGRect(
            x: pinCenter.x - svSize.width  / (2 * targetZoom),
            y: pinCenter.y - svSize.height / (2 * targetZoom),
            width:  svSize.width  / targetZoom,
            height: svSize.height / targetZoom
        )
        zoomScrollView.zoom(to: zoomRect, animated: true)
    }

    private func persist() {
        card.annotations = annotations
        CardStore.shared.save(card: card)
    }
}

// MARK: - ImageAnnotationViewDelegate

extension ImageCardDetailViewController: ImageAnnotationViewDelegate {
    func annotationView(_ view: ImageAnnotationView, didAddAnnotation annotation: ImageAnnotation) {
        annotations.append(annotation); persist()
    }
    func annotationView(_ view: ImageAnnotationView, didUpdateAnnotation annotation: ImageAnnotation) {
        if let i = annotations.firstIndex(where: { $0.id == annotation.id }) { annotations[i] = annotation }
        persist()
    }
    func annotationView(_ view: ImageAnnotationView, didDeleteAnnotation annotation: ImageAnnotation) {
        annotations.removeAll { $0.id == annotation.id }; persist()
    }
}

// MARK: - UIScrollViewDelegate

extension ImageCardDetailViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { annotationView }
}
