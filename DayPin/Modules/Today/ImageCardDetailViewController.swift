import UIKit

final class ImageCardDetailViewController: UIViewController {

    private let card: ImageCard
    private let zoomScrollView  = UIScrollView()
    private let annotationView  = ImageAnnotationView()
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
        title = card.title
        view.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(white: 0.05, alpha: 1) : .systemGroupedBackground
        }
        setupNav()
        setupUI()
        setupZoomHUD()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(goBack)
        )

        let editBtn = UIBarButtonItem(image: UIImage(systemName: "pencil"),
                                      style: .plain, target: self, action: #selector(editCard))
        let listBtn = UIBarButtonItem(image: UIImage(systemName: "list.bullet"),
                                      style: .plain, target: self, action: #selector(showPinList))

        let shareAction  = UIAction(title: "Поделиться", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in self?.share() }
        let folderAction = UIAction(title: "В папку",    image: UIImage(systemName: "folder.badge.plus"))   { [weak self] _ in self?.addToFolder() }
        let menu = UIMenu(children: [shareAction, folderAction])
        let moreBtn = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)

        navigationItem.rightBarButtonItems = [moreBtn, editBtn, listBtn]
    }

    // MARK: - UI

    private func setupUI() {
        zoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.minimumZoomScale = 1
        zoomScrollView.maximumZoomScale = 4
        zoomScrollView.delegate = self
        zoomScrollView.showsVerticalScrollIndicator   = false
        zoomScrollView.showsHorizontalScrollIndicator = false
        view.addSubview(zoomScrollView)

        annotationView.translatesAutoresizingMaskIntoConstraints = false
        annotationView.layer.cornerRadius = 0
        annotationView.image = card.imageData.flatMap { UIImage(data: $0) }
        annotationView.delegate = self
        annotationView.zoomScrollView = zoomScrollView
        annotationView.load(annotations: annotations)
        zoomScrollView.addSubview(annotationView)

        // Compact hint badge
        let hintLabel = UILabel()
        hintLabel.text      = L10n.annotationHint
        hintLabel.font      = .systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 1
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        let hintContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        hintContainer.layer.cornerRadius = 12
        hintContainer.clipsToBounds = true
        hintContainer.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.contentView.addSubview(hintLabel)
        view.addSubview(hintContainer)

        NSLayoutConstraint.activate([
            zoomScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zoomScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            zoomScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),

            annotationView.leadingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.leadingAnchor),
            annotationView.trailingAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.trailingAnchor),
            annotationView.topAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.topAnchor),
            annotationView.bottomAnchor.constraint(equalTo: zoomScrollView.contentLayoutGuide.bottomAnchor),
            annotationView.widthAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.widthAnchor),
            annotationView.heightAnchor.constraint(equalTo: zoomScrollView.frameLayoutGuide.heightAnchor),

            hintContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            hintContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            hintContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            hintLabel.topAnchor.constraint(equalTo: hintContainer.contentView.topAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: hintContainer.contentView.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: hintContainer.contentView.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: hintContainer.contentView.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - Zoom HUD  (two separate round buttons, no conflicting stack)

    private let zoomInBtn  = UIButton(type: .system)
    private let zoomOutBtn = UIButton(type: .system)

    private func setupZoomHUD() {
        for (btn, icon, sel) in [
            (zoomInBtn,  "plus",  #selector(zoomInAction)),
            (zoomOutBtn, "minus", #selector(zoomOutAction))
        ] as [(UIButton, String, Selector)] {
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
            btn.tintColor = .white
            btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            btn.layer.cornerRadius = 18
            btn.layer.borderWidth  = 0.5
            btn.layer.borderColor  = UIColor.white.withAlphaComponent(0.25).cgColor
            btn.alpha = 0
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.addTarget(self, action: sel, for: .touchUpInside)
            view.addSubview(btn)
        }

        NSLayoutConstraint.activate([
            zoomInBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            zoomInBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -52),
            zoomInBtn.widthAnchor.constraint(equalToConstant: 36),
            zoomInBtn.heightAnchor.constraint(equalToConstant: 36),

            zoomOutBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            zoomOutBtn.bottomAnchor.constraint(equalTo: zoomInBtn.topAnchor, constant: -8),
            zoomOutBtn.widthAnchor.constraint(equalToConstant: 36),
            zoomOutBtn.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func zoomInAction() {
        let newScale = min(zoomScrollView.maximumZoomScale, zoomScrollView.zoomScale * 1.5)
        zoomScrollView.setZoomScale(newScale, animated: true)
    }

    @objc private func zoomOutAction() {
        let newScale = max(zoomScrollView.minimumZoomScale, zoomScrollView.zoomScale / 1.5)
        zoomScrollView.setZoomScale(newScale, animated: true)
    }

    // MARK: - Actions

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func share() {
        var items: [Any] = [card.title]
        if let data = card.imageData, let image = UIImage(data: data) { items.append(image) }
        let notes = annotations.map { "• \($0.text)" }.joined(separator: "\n")
        if !notes.isEmpty { items.append(notes) }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }

    @objc private func editCard() {
        let vc = ImageCardEditorViewController(imageData: card.imageData, dayDate: card.dayDate, existingCard: card)
        vc.onSave = { [weak self] saved in
            guard let self else { return }
            self.card.title       = saved.title
            self.card.imageData   = saved.imageData
            self.card.annotations = saved.annotations
            self.annotations      = saved.annotations
            self.title            = saved.title
            self.annotationView.image = saved.imageData.flatMap { UIImage(data: $0) }
            self.annotationView.load(annotations: self.annotations)
            self.persist()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc private func showPinList() {
        guard !annotations.isEmpty else { return }
        let vc = PinListViewController(annotations: annotations)
        vc.onSelectPin = { [weak self] annotation in
            self?.focusOnAnnotation(annotation)
        }
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(vc, animated: true)
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

    @objc private func addToFolder() {
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

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let show = scrollView.zoomScale > 1.02
        UIView.animate(withDuration: 0.2) {
            self.zoomInBtn.alpha  = show ? 1 : 0
            self.zoomOutBtn.alpha = show ? 1 : 0
        }
    }
}
