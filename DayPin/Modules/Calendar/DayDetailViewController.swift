import UIKit
import PhotosUI
import SafariServices

final class DayDetailViewController: UIViewController {

    private let date: Date

    init(date: Date) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let df = DateFormatter()
        df.dateFormat = "d MMMM"
        df.locale = Locale.current
        title = df.string(from: date)
        view.backgroundColor = .systemGroupedBackground

        let vc = DayCardsViewController(date: date)
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vc.view)
        vc.didMove(toParent: self)

        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: view.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - DayCardsViewController

final class DayCardsViewController: UIViewController {

    let date: Date

    private lazy var collectionView: UICollectionView = {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
        section.interGroupSpacing = 12
        let layout = UICollectionViewCompositionalLayout(section: section)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self, forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self, forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(EmptyCardCell.self, forCellWithReuseIdentifier: EmptyCardCell.reuseID)
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

    private var cards: [NoteCard] = [] {
        didSet { collectionView.reloadData() }
    }

    init(date: Date) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
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
        loadCards()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCards()
    }

    func loadCards() {
        cards = CardStore.shared.cards(for: date)
    }

    @objc private func addTapped() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        var actions: [GlassAction] = [
            GlassAction(L10n.cardText, icon: "text.alignleft") { [weak self] in self?.presentTextEditor() },
            GlassAction(L10n.cardPhoto, icon: "photo.on.rectangle") { [weak self] in self?.presentImagePicker() }
        ]
        if hasCamera {
            actions.append(GlassAction(L10n.cardCamera, icon: "camera") { [weak self] in self?.presentCamera() })
        }
        actions.append(GlassAction(L10n.cardLink, icon: "link") { [weak self] in self?.presentLinkEditor() })
        actions.append(GlassAction(L10n.cancel, style: .cancel))
        GlassActionSheet.show(actions: actions, from: self)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func presentTextEditor() {
        let vc = TextCardEditorViewController(card: nil, dayDate: date)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func presentLinkEditor() {
        let vc = LinkCardEditorViewController(card: nil, dayDate: date)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
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
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentImageCardEditor(imageData: Data?) {
        let vc = ImageCardEditorViewController(imageData: imageData, dayDate: date, existingCard: nil)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }
}

// MARK: - DataSource

extension DayCardsViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cards.isEmpty ? 1 : cards.count
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if cards.isEmpty {
            return cv.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as! EmptyCardCell
        }
        let card = cards[indexPath.item]
        switch card.type {
        case .text:
            let cell = cv.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as! TextCardCell
            cell.configure(with: card as! TextCard); return cell
        case .image:
            let cell = cv.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as! ImageCardCell
            cell.configure(with: card as! ImageCard); return cell
        case .link:
            let cell = cv.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as! LinkCardCell
            cell.configure(with: card as! LinkCard); return cell
        }
    }
}

// MARK: - Delegate

extension DayCardsViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !cards.isEmpty else { return }
        let card = cards[indexPath.item]
        switch card.type {
        case .text:
            navigationController?.pushViewController(CardDetailViewController(card: card as! TextCard), animated: true)
        case .image:
            navigationController?.pushViewController(ImageCardDetailViewController(card: card as! ImageCard), animated: true)
        case .link:
            if let link = card as? LinkCard {
                let safari = SFSafariViewController(url: link.url)
                safari.preferredControlTintColor = .systemBlue
                present(safari, animated: true)
            }
        }
    }

    func collectionView(_ cv: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !cards.isEmpty else { return nil }
        let card = cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { _ in
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                CardStore.shared.delete(card: card)
                self?.loadCards()
            }
            return UIMenu(children: [delete])
        })
    }
}

// MARK: - PHPickerDelegate + UIImagePickerDelegate

extension DayCardsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let image = obj as? UIImage, let self else { return }
            DispatchQueue.main.async { self.presentImageCardEditor(imageData: image.jpegData(compressionQuality: 0.85)) }
        }
    }
}

extension DayCardsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        presentImageCardEditor(imageData: image?.jpegData(compressionQuality: 0.85))
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
