import UIKit

// MARK: - FolderDetailViewController
// Shows all cards assigned to a given folder in a 2-column grid.

final class FolderDetailViewController: UIViewController {

    private var folder: Folder

    /// Exposed so MainContainerViewController can detect the active folder context.
    var contextFolderID: UUID { folder.id }
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = folder.name
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupUI()
        observeNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        loadCards()
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onFolderNeedsRefresh),
            name: .dayPinFolderNeedsRefresh, object: nil)
    }

    @objc private func onFolderNeedsRefresh() {
        loadCards()
    }

    @objc private func onLanguageChanged() {
        collectionView.reloadData()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        collectionView.reloadData()
    }

    // MARK: - Setup

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(goBack)
        )
        let editBtn  = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"),
                                       style: .plain, target: self, action: #selector(editFolder))
        let shareBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"),
                                       style: .plain, target: self, action: #selector(shareFolder))
        navigationItem.rightBarButtonItems = [shareBtn, editBtn]
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
            guard let textCard = card as? TextCard else { return }
            navigationController?.pushViewController(CardDetailViewController(card: textCard), animated: true)
        case .image:
            guard let imageCard = card as? ImageCard else { return }
            navigationController?.pushViewController(ImageCardOverviewViewController(card: imageCard), animated: true)
        case .link:
            guard let linkCard = card as? LinkCard else { return }
            navigationController?.pushViewController(LinkCardDetailViewController(card: linkCard), animated: true)
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
            guard let empty = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as? EmptyCardCell else {
                return UICollectionViewCell()
            }
            return empty
        }
        let card = cards[indexPath.item]
        switch card.type {
        case .text:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as? TextCardCell,
                  let textCard = card as? TextCard else { return UICollectionViewCell() }
            c.configure(with: textCard); return c
        case .image:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as? ImageCardCell,
                  let imageCard = card as? ImageCard else { return UICollectionViewCell() }
            c.configure(with: imageCard); return c
        case .link:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as? LinkCardCell,
                  let linkCard = card as? LinkCard else { return UICollectionViewCell() }
            c.configure(with: linkCard); return c
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

            let share = UIAction(title: L10n.share,
                                 image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self else { return }
                var items: [Any] = [card.title]
                if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
                if let link = card as? LinkCard { items.append(link.url) }
                self.present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
            }

            let copy = UIAction(title: L10n.copyToDay,
                                image: UIImage(systemName: "calendar.badge.plus")) { [weak self] _ in
                guard let self else { return }
                let vc = CopyToDayViewController()
                vc.onCopy = { date in
                    CardStore.shared.save(card: card.duplicated(to: date))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }

            let remove = UIAction(title: L10n.removeFromFolder,
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
