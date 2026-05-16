import UIKit

// MARK: - FolderDetailViewController
// Shows all cards assigned to a given folder in a 2-column grid.

final class FolderDetailViewController: UIViewController {

    private var folder: Folder
    private var cards: [NoteCard] = []

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 40, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self,  forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,  forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(EmptyCardCell.self, forCellWithReuseIdentifier: EmptyCardCell.reuseID)
        return cv
    }()

    init(folder: Folder) {
        self.folder = folder
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = folder.name
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        loadCards()
    }

    // MARK: - Setup

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(goBack)
        )
        let addBtn   = UIBarButtonItem(image: UIImage(systemName: "plus"),
                                       style: .plain, target: self, action: #selector(addNote))
        let editBtn  = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"),
                                       style: .plain, target: self, action: #selector(editFolder))
        let shareBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                                       style: .plain, target: self, action: #selector(shareFolder))
        navigationItem.rightBarButtonItems = [addBtn, shareBtn, editBtn]
    }

    private func setupUI() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        collectionView.dataSource = self
        collectionView.delegate   = self
    }

    private func makeLayout() -> UICollectionViewLayout {
        let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
        let item      = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
        let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
        let section   = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 8, trailing: 10)
        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - Data

    private func loadCards() {
        cards = CardStore.shared.cards(inFolder: folder.id)
        collectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func goBack() { navigationController?.popViewController(animated: true) }

    @objc private func shareFolder() {
        guard !cards.isEmpty else { return }
        let items: [Any] = cards.compactMap { card -> Any? in
            if let img = card as? ImageCard, let data = img.imageData { return UIImage(data: data) }
            if let link = card as? LinkCard { return link.url }
            return card.title
        }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }

    @objc private func addNote() {
        let today = Calendar.current.startOfDay(for: Date())
        let sheet = UIAlertController(title: "Новая заметка", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Текст", style: .default) { [weak self] (_: UIAlertAction) in
            guard let self else { return }
            let vc = TextCardEditorViewController(card: nil, dayDate: today)
            vc.onSave = { [weak self] saved in
                guard let self else { return }
                saved.folderID = self.folder.id
                CardStore.shared.save(card: saved)
                self.loadCards()
            }
            self.presentEditorSheet(vc)
        })
        sheet.addAction(UIAlertAction(title: "Изображение", style: .default) { [weak self] (_: UIAlertAction) in
            guard let self else { return }
            let vc = ImageCardEditorViewController(imageData: nil, dayDate: today, existingCard: nil)
            vc.onSave = { [weak self] saved in
                guard let self else { return }
                saved.folderID = self.folder.id
                CardStore.shared.save(card: saved)
                self.loadCards()
            }
            self.present(UINavigationController(rootViewController: vc), animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Добавить существующие", style: .default) { [weak self] (_: UIAlertAction) in
            guard let self else { return }
            let vc = NotePickerViewController(folderID: self.folder.id)
            vc.onAdd = { [weak self] notes in
                guard let self else { return }
                notes.forEach { card in
                    card.folderID = self.folder.id
                    CardStore.shared.save(card: card)
                }
                self.loadCards()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            self.present(UINavigationController(rootViewController: vc), animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func editFolder() {
        let vc = FolderEditorViewController(folder: folder)
        vc.onSave = { [weak self] updated in
            FolderStore.shared.save(updated)
            self?.folder = updated
            self?.title  = updated.name
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func openCard(_ card: NoteCard) {
        switch card.type {
        case .text:
            navigationController?.pushViewController(CardDetailViewController(card: card as! TextCard), animated: true)
        case .image:
            navigationController?.pushViewController(ImageCardOverviewViewController(card: card as! ImageCard), animated: true)
        case .link:
            navigationController?.pushViewController(LinkCardDetailViewController(card: card as! LinkCard), animated: true)
        }
    }
}

// MARK: - UICollectionViewDataSource + Delegate

extension FolderDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cards.isEmpty ? 1 : cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if cards.isEmpty {
            return collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as! EmptyCardCell
        }
        let card = cards[indexPath.item]
        switch card.type {
        case .text:
            let c = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as! TextCardCell
            c.configure(with: card as! TextCard); return c
        case .image:
            let c = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as! ImageCardCell
            c.configure(with: card as! ImageCard); return c
        case .link:
            let c = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as! LinkCardCell
            c.configure(with: card as! LinkCard); return c
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !cards.isEmpty else { return }
        openCard(cards[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard !cards.isEmpty else { return nil }
        let card = cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            guard let self else { return nil }

            let share = UIAction(title: "Поделиться",
                                 image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self else { return }
                var items: [Any] = [card.title]
                if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
                if let link = card as? LinkCard { items.append(link.url) }
                self.present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
            }

            let copy = UIAction(title: "Скопировать в день",
                                image: UIImage(systemName: "calendar.badge.plus")) { [weak self] _ in
                guard let self else { return }
                let vc = CopyToDayViewController()
                vc.onCopy = { date in
                    CardStore.shared.save(card: card.duplicated(to: date))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }

            let remove = UIAction(title: "Убрать из папки",
                                  image: UIImage(systemName: "folder.badge.minus"),
                                  attributes: .destructive) { [weak self] _ in
                card.folderID = nil
                CardStore.shared.save(card: card)
                self?.loadCards()
            }
            return UIMenu(children: [share, copy, remove])
        })
    }
}
