import UIKit
import PhotosUI
import SafariServices

final class TodayViewController: UIViewController {

    // MARK: UI

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self, forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self, forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(EmptyCardCell.self, forCellWithReuseIdentifier: EmptyCardCell.reuseID)
        cv.register(
            TodayHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: TodayHeaderView.reuseID
        )
        return cv
    }()

    private lazy var addButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = .label
        btn.tintColor = .systemBackground
        btn.layer.cornerRadius = 30
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.2
        btn.layer.shadowRadius = 12
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        btn.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        btn.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: Data

    private var cards: [NoteCard] = [] {
        didSet { collectionView.reloadData() }
    }

    let date: Date

    init(date: Date = Calendar.current.startOfDay(for: Date())) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCards()
    }

    // MARK: Setup

    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            addButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        collectionView.dataSource = self
        collectionView.delegate = self
    }

    private func loadCards() {
        cards = CardStore.shared.cards(for: date)
    }

    // MARK: Layout

    private func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16)
        section.interGroupSpacing = 12

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(90))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: Add Action

    @objc private func addTapped() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

        var actions: [GlassAction] = [
            GlassAction(L10n.cardText, icon: "text.alignleft") { [weak self] in self?.presentTextEditor(card: nil) },
            GlassAction(L10n.cardPhoto, icon: "photo.on.rectangle") { [weak self] in self?.presentImagePicker() }
        ]
        if hasCamera {
            actions.append(GlassAction(L10n.cardCamera, icon: "camera") { [weak self] in self?.presentCamera() })
        }
        actions.append(GlassAction(L10n.cardLink, icon: "link") { [weak self] in self?.presentLinkEditor(card: nil) })
        actions.append(GlassAction(L10n.cancel, style: .cancel))

        GlassActionSheet.show(actions: actions, from: self)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: Editors

    func presentTextEditor(card: TextCard?) {
        let vc = TextCardEditorViewController(card: card, dayDate: date)
        vc.onSave = { [weak self] saved in
            CardStore.shared.save(card: saved)
            self?.loadCards()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func presentLinkEditor(card: LinkCard?) {
        let vc = LinkCardEditorViewController(card: card, dayDate: date)
        vc.onSave = { [weak self] saved in
            CardStore.shared.save(card: saved)
            self?.loadCards()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func presentImagePicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    func presentImageCardEditor(imageData: Data?) {
        let vc = ImageCardEditorViewController(imageData: imageData, dayDate: date, existingCard: nil)
        vc.onSave = { [weak self] saved in
            CardStore.shared.save(card: saved)
            self?.loadCards()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func deleteCard(_ card: NoteCard) {
        CardStore.shared.delete(card: card)
        loadCards()
    }

    func shareCard(_ card: NoteCard) {
        var items: [Any] = [card.title]
        if !card.comment.isEmpty { items.append(card.comment) }
        if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
        if let link = card as? LinkCard { items.append(link.url) }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        present(vc, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension TodayViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cards.isEmpty ? 1 : cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if cards.isEmpty {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as! EmptyCardCell
            return cell
        }
        let card = cards[indexPath.item]
        switch card.type {
        case .text:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as! TextCardCell
            cell.configure(with: card as! TextCard)
            return cell
        case .image:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as! ImageCardCell
            cell.configure(with: card as! ImageCard)
            return cell
        case .link:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as! LinkCardCell
            cell.configure(with: card as! LinkCard)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: TodayHeaderView.reuseID,
            for: indexPath
        ) as! TodayHeaderView
        header.configure(date: date)
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension TodayViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !cards.isEmpty else { return }
        let card = cards[indexPath.item]
        openCard(card)
    }

    func openCard(_ card: NoteCard) {
        switch card.type {
        case .text:
            let vc = CardDetailViewController(card: card as! TextCard)
            navigationController?.pushViewController(vc, animated: true)
        case .image:
            let vc = ImageCardDetailViewController(card: card as! ImageCard)
            navigationController?.pushViewController(vc, animated: true)
        case .link:
            if let link = card as? LinkCard {
                let safari = SFSafariViewController(url: link.url)
                safari.preferredControlTintColor = .systemBlue
                present(safari, animated: true)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !cards.isEmpty else { return nil }
        let card = cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { _ in
            let share = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareCard(card)
            }
            let edit = UIAction(title: L10n.edit, image: UIImage(systemName: "pencil")) { [weak self] _ in
                switch card.type {
                case .text: self?.presentTextEditor(card: card as? TextCard)
                case .image: break
                case .link: self?.presentLinkEditor(card: card as? LinkCard)
                }
            }
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteCard(card)
            }
            return UIMenu(children: [share, edit, delete])
        })
    }
}

// MARK: - PHPickerViewControllerDelegate

extension TodayViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let image = obj as? UIImage, let self else { return }
            DispatchQueue.main.async { self.presentImageCardEditor(imageData: image.jpegData(compressionQuality: 0.85)) }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate (Camera)

extension TodayViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        presentImageCardEditor(imageData: image?.jpegData(compressionQuality: 0.85))
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
