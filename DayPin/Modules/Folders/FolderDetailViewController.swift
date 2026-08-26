import UIKit

final class FolderDetailViewController: UIViewController {

    private var folder: Folder

    var contextFolderID: UUID { folder.id }
    private var cards: [NoteCard] = []
    private var animatedCardIndexPaths = Set<IndexPath>()

    // Loading toast shown while multi-photo import is in progress
    private let importLoadingToast = FolderImportToastView()

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
        NotificationCenter.default.addObserver(self, selector: #selector(onPhotoImportBegan(_:)),
            name: .dayPinPhotoImportBegan, object: nil)
    }

    @objc private func onFolderNeedsRefresh() {
        importLoadingToast.hide()
        loadCards()
    }

    @objc private func onPhotoImportBegan(_ note: Notification) {
        let count = (note.userInfo?["count"] as? Int) ?? 0
        importLoadingToast.show(in: view, count: count)
    }

    @objc private func onLanguageChanged() {
        collectionView.reloadData()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        collectionView.reloadData()
    }

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(goBack)
        )
        let editBtn = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"),
                                       style: .plain, target: self, action: #selector(editFolder))
        let shareAction = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.shareFolder()
        }
        let shareLinkAction = UIAction(title: L10n.shareViaLink, image: UIImage(systemName: "link")) { [weak self] _ in
            guard let self else { return }
            ShareLinkPresenter.shareCollection(title: self.folder.name, cards: self.cards, folder: self.folder, from: self)
        }
        let shareBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            menu: UIMenu(children: [shareAction, shareLinkAction])
        )
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
        collectionView.delegate = self

        // Import loading toast (hidden by default)
        importLoadingToast.translatesAutoresizingMaskIntoConstraints = false
        importLoadingToast.alpha = 0
        view.addSubview(importLoadingToast)
        NSLayoutConstraint.activate([
            importLoadingToast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            importLoadingToast.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            importLoadingToast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 8, trailing: 10)
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func loadCards() {
        animatedCardIndexPaths.removeAll()
        cards = CardStore.shared.cards(inFolder: folder.id)
        collectionView.reloadData()
    }

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
            self?.title = updated.name
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

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard !cards.isEmpty, !(cell is EmptyCardCell) else { return }
        if !animatedCardIndexPaths.contains(indexPath) {
            animatedCardIndexPaths.insert(indexPath)
            cell.animateCardAppearance(at: indexPath.item)
        }
        // Attach swipe-to-remove gesture if not already present
        let hasSwipe = cell.gestureRecognizers?.contains(where: { $0.name == "folderSwipe" }) ?? false
        if !hasSwipe {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCardSwipe(_:)))
            pan.name = "folderSwipe"
            pan.delegate = self
            cell.addGestureRecognizer(pan)
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

            let shareLink = UIAction(title: L10n.shareViaLink,
                                     image: UIImage(systemName: "link")) { [weak self] _ in
                guard let self else { return }
                ShareLinkPresenter.shareCard(card, from: self)
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
            return UIMenu(children: [share, shareLink, copy, remove])
        })
    }
}

// MARK: - Swipe-to-remove from folder

extension FolderDetailViewController: UIGestureRecognizerDelegate {

    @objc private func handleCardSwipe(_ pan: UIPanGestureRecognizer) {
        guard let cell = pan.view as? UICollectionViewCell else { return }
        guard let indexPath = collectionView.indexPath(for: cell),
              indexPath.item < cards.count else {
            if pan.state == .ended || pan.state == .cancelled {
                UIView.animate(withDuration: 0.3) { cell.transform = .identity; cell.alpha = 1 }
            }
            return
        }

        let card = cards[indexPath.item]
        let translation = pan.translation(in: cell)

        switch pan.state {
        case .changed:
            let tx = min(0, translation.x)
            cell.transform = CGAffineTransform(translationX: tx, y: 0)
            let progress = abs(tx) / (cell.bounds.width * 0.5)
            cell.alpha = max(0.4, 1.0 - progress * 0.35)

        case .ended:
            let velocity = pan.velocity(in: cell)
            let shouldRemove = translation.x < -(cell.bounds.width * 0.35) || velocity.x < -700
            if shouldRemove {
                UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
                    cell.transform = CGAffineTransform(translationX: -(cell.bounds.width + 20), y: 0)
                    cell.alpha = 0
                } completion: { [weak self] _ in
                    guard let self else { return }
                    cell.transform = .identity
                    cell.alpha = 1
                    self.removeCardFromFolder(card, at: indexPath.item)
                }
            } else {
                UIView.animate(withDuration: 0.35, delay: 0,
                               usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
                    cell.transform = .identity
                    cell.alpha = 1
                }
            }

        case .cancelled, .failed:
            UIView.animate(withDuration: 0.3) { cell.transform = .identity; cell.alpha = 1 }

        default:
            break
        }
    }

    private func removeCardFromFolder(_ card: NoteCard, at index: Int) {
        card.folderID = nil
        CardStore.shared.save(card: card)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        cards.remove(at: index)
        animatedCardIndexPaths.removeAll()

        if cards.isEmpty {
            UIView.transition(with: collectionView, duration: 0, options: .transitionCrossDissolve) {
                self.collectionView.reloadData()
            }
        } else {
            UIView.performWithoutAnimation {
                collectionView.performBatchUpdates {
                    collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
                }
            }
        }
    }

    func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard let pan = gr as? UIPanGestureRecognizer,
              pan.name == "folderSwipe",
              let view = pan.view else { return true }
        let v = pan.velocity(in: view)
        // Only activate for clear leftward horizontal swipes
        return abs(v.x) > abs(v.y) && v.x < 0
    }

    func gestureRecognizer(_ gr: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        false
    }
}
