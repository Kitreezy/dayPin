import UIKit
import PhotosUI

final class DayDetailViewController: UIViewController {

    private let date: Date

    init(date: Date) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshTitle()
        view.backgroundColor = DayPinDesign.background

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

        observeNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        refreshTitle()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
    }

    private func refreshTitle() {
        let df = DateFormatter()
        df.dateFormat = "d MMMM"
        df.locale = L10n.activeLocale
        title = df.string(from: date)
    }
}

// MARK: - DayCardsViewController

final class DayCardsViewController: UIViewController {

    let date: Date

    private var allCards: [NoteCard] = []

    private struct TypeSection {
        let type: CardType
        var cards: [NoteCard]
        var header: String {
            switch type {
            case .text:  return L10n.sectionText
            case .image: return L10n.sectionImage
            case .link:  return L10n.sectionLink
            }
        }
        var accentColor: UIColor {
            switch type {
            case .text:  return DayPinDesign.accent
            case .image: return DayPinDesign.accentLight
            case .link:  return DayPinDesign.accentDeep
            }
        }
    }

    private var activeSections: [TypeSection] = []
    private var activeFilter: FilterChipsView.Filter = .all
    private var animatedCardIndexPaths = Set<IndexPath>()

    // MARK: - UI

    private let filterChips = FilterChipsView()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self,  forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,  forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(EmptyCardCell.self, forCellWithReuseIdentifier: EmptyCardCell.reuseID)
        cv.register(CardTypeSectionHeader.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: CardTypeSectionHeader.reuseID)
        return cv
    }()


    init(date: Date) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background

        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onFilterChange = { [weak self] filter in
            self?.activeFilter = filter
            self?.applyFilter()
        }

        collectionView.keyboardDismissMode = .onDrag
        view.addSubview(filterChips)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            filterChips.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterChips.heightAnchor.constraint(equalToConstant: 38),

            collectionView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(onAddText),   name: .dayPinAddText,   object: nil)
        nc.addObserver(self, selector: #selector(onAddPhoto),  name: .dayPinAddPhoto,  object: nil)
        nc.addObserver(self, selector: #selector(onAddCamera), name: .dayPinAddCamera, object: nil)
        nc.addObserver(self, selector: #selector(onAddLink),   name: .dayPinAddLink,   object: nil)
        collectionView.dataSource = self
        collectionView.delegate = self
        loadCards()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCards()
    }

    // MARK: - Data

    func loadCards() {
        animatedCardIndexPaths.removeAll()
        allCards = CardStore.shared.cards(for: date)
        applyFilter()
    }

    private func applyFilter() {
        var text = allCards.filter { $0.type == .text }
        var image = allCards.filter { $0.type == .image }
        var link = allCards.filter { $0.type == .link }

        switch activeFilter {
        case .text:  image = []; link = []
        case .image: text = []; link = []
        case .link:  text = []; image = []
        case .all:   break
        }

        activeSections = [
            TypeSection(type: .text,  cards: text),
            TypeSection(type: .image, cards: image),
            TypeSection(type: .link,  cards: link)
        ].filter { !$0.cards.isEmpty }

        collectionView.reloadData()
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, _ in
            guard let self else { return nil }

            if self.activeSections.isEmpty {
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let sec = NSCollectionLayoutSection(group: group)
                sec.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
                return sec
            }

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

            let sec = NSCollectionLayoutSection(group: group)
            sec.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 11, bottom: 16, trailing: 11)
            sec.interGroupSpacing = 10

            let hdrSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36))
            let hdr = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: hdrSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            sec.boundarySupplementaryItems = [hdr]
            return sec
        }
    }

    // MARK: - Add (via global "+" notifications)

    @objc private func onAddText()   { presentTextEditor() }
    @objc private func onAddPhoto()  { presentImagePicker() }
    @objc private func onAddCamera() { presentCamera() }
    @objc private func onAddLink()   { presentLinkEditor() }

    private func presentTextEditor() {
        let vc = TextCardEditorViewController(card: nil, dayDate: date)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        presentEditorSheet(vc)
    }

    private func presentLinkEditor() {
        let vc = LinkCardEditorViewController(card: nil, dayDate: date)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        presentEditorSheet(vc)
    }

    private func presentImagePicker() {
        presentCameraCard(startMode: .gallery)
    }

    private func presentCamera() {
        presentCameraCard(startMode: .camera)
    }

    private func presentCameraCard(startMode: CameraCardViewController.StartMode, existingCard: ImageCard? = nil) {
        let vc = CameraCardViewController(startMode: startMode, dayDate: date, existingCard: existingCard)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(vc, animated: true)
    }

    private func presentImageEditor(card: ImageCard) {
        presentCameraCard(startMode: .gallery, existingCard: card)
    }

    private func deleteCard(_ card: NoteCard, at indexPath: IndexPath) {
        guard indexPath.section < activeSections.count,
              indexPath.item < activeSections[indexPath.section].cards.count else {
            CardStore.shared.delete(card: card); loadCards(); return
        }

        CardStore.shared.delete(card: card)
        allCards = CardStore.shared.cards(for: date)

        activeSections[indexPath.section].cards.remove(at: indexPath.item)
        let sectionEmpty = activeSections[indexPath.section].cards.isEmpty
        if sectionEmpty { activeSections.remove(at: indexPath.section) }
        let allEmpty = activeSections.isEmpty

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        collectionView.performBatchUpdates {
            self.collectionView.deleteItems(at: [indexPath])
            if sectionEmpty && !allEmpty {
                self.collectionView.deleteSections(IndexSet(integer: indexPath.section))
            }
        } completion: { _ in
            if allEmpty {
                UIView.transition(with: self.collectionView, duration: 0.2, options: .transitionCrossDissolve) {
                    self.collectionView.reloadData()
                }
            }
        }
    }
}

// MARK: - DataSource

extension DayCardsViewController: UICollectionViewDataSource {
    func numberOfSections(in cv: UICollectionView) -> Int {
        activeSections.isEmpty ? 1 : activeSections.count
    }
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        activeSections.isEmpty ? 1 : activeSections[section].cards.count
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if activeSections.isEmpty {
            guard let cell = cv.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as? EmptyCardCell else {
                return cv.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath)
            }
            return cell
        }
        let card = activeSections[indexPath.section].cards[indexPath.item]
        switch card.type {
        case .text:
            guard let cell = cv.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as? TextCardCell else {
                return cv.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath)
            }
            if let textCard = card as? TextCard { cell.configure(with: textCard) }
            return cell
        case .image:
            guard let cell = cv.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as? ImageCardCell else {
                return cv.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath)
            }
            if let imageCard = card as? ImageCard { cell.configure(with: imageCard) }
            return cell
        case .link:
            guard let cell = cv.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as? LinkCardCell else {
                return cv.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath)
            }
            if let linkCard = card as? LinkCard { cell.configure(with: linkCard) }
            return cell
        }
    }
    func collectionView(_ cv: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = cv.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: CardTypeSectionHeader.reuseID, for: indexPath
        ) as? CardTypeSectionHeader else {
            return cv.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CardTypeSectionHeader.reuseID, for: indexPath)
        }
        if !activeSections.isEmpty {
            header.configure(title: activeSections[indexPath.section].header,
                             color: activeSections[indexPath.section].accentColor)
        }
        return header
    }
}

// MARK: - Delegate

extension DayCardsViewController: UICollectionViewDelegate {

    func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard !activeSections.isEmpty, !(cell is EmptyCardCell) else { return }
        if !animatedCardIndexPaths.contains(indexPath) {
            animatedCardIndexPaths.insert(indexPath)
            // Flat index across sections for smooth stagger
            let flatIndex = activeSections[0..<indexPath.section].reduce(0) { $0 + $1.cards.count } + indexPath.item
            cell.animateCardAppearance(at: flatIndex)
        }
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !activeSections.isEmpty else { return }
        let card = activeSections[indexPath.section].cards[indexPath.item]
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

    func collectionView(_ cv: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !activeSections.isEmpty else { return nil }
        let card = activeSections[indexPath.section].cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { _ in
            let share = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self else { return }
                var items: [Any] = [card.title]
                if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
                if let link = card as? LinkCard { items.append(link.url) }
                self.present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
            }
            let copyToDay = UIAction(title: L10n.copyToDay, image: UIImage(systemName: "calendar.badge.plus")) { [weak self] _ in
                guard let self else { return }
                let vc = CopyToDayViewController()
                vc.onCopy = { date in
                    CardStore.shared.save(card: card.duplicated(to: date))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            let edit = UIAction(title: L10n.edit, image: UIImage(systemName: "pencil")) { [weak self] _ in
                guard let self else { return }
                switch card.type {
                case .text:
                    let vc = TextCardEditorViewController(card: card as? TextCard, dayDate: date)
                    vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
                    presentEditorSheet(vc)
                case .image:
                    if let c = card as? ImageCard { presentImageEditor(card: c) }
                case .link:
                    let vc = LinkCardEditorViewController(card: card as? LinkCard, dayDate: date)
                    vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
                    presentEditorSheet(vc)
                }
            }
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteCard(card, at: indexPath)
            }
            return UIMenu(children: [share, copyToDay, edit, delete])
        })
    }
}

