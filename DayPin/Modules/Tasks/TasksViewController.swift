import UIKit

final class TasksViewController: UIViewController {

    private var isSearchOpen = false
    private var searchQuery = ""

    // MARK: - Multi-select state

    private var isSelectMode = false
    private var selectedIDs = Set<UUID>()

    private let headerContainer = UIView()
    private let titleLabel = UILabel()
    private let searchBtn = UIButton(type: .system)
    private let searchContainer = UIView()
    private let searchBar = UISearchBar()

    private let filterChips = FilterChipsView()
    private var activeFilter: FilterChipsView.Filter = .all

    // MARK: - Multi-select bar

    private let selectionCountLabel = UILabel()
    private let selectionCopyBtn = UIButton(type: .system)
    private let selectionFolderBtn = UIButton(type: .system)

    private lazy var selectionBar: UIView = {
        let bar = UIView()
        bar.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.12, alpha: 0.95)
                : UIColor(white: 0.98, alpha: 0.95)
        }
        bar.layer.cornerRadius = 18
        bar.layer.shadowColor = UIColor.black.cgColor
        bar.layer.shadowOpacity = 0.15
        bar.layer.shadowRadius = 12
        bar.layer.shadowOffset = CGSize(width: 0, height: 4)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isHidden = true

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)

        selectionCopyBtn.setImage(UIImage(systemName: "calendar.badge.plus", withConfiguration: iconCfg), for: .normal)
        selectionCopyBtn.addTarget(self, action: #selector(copySelectedTapped), for: .touchUpInside)

        selectionCountLabel.font = .inter(ofSize: 13, weight: .medium)
        selectionCountLabel.textColor = .secondaryLabel
        selectionCountLabel.textAlignment = .center

        selectionFolderBtn.setImage(UIImage(systemName: "folder.badge.plus", withConfiguration: iconCfg), for: .normal)
        selectionFolderBtn.addTarget(self, action: #selector(moveSelectedToFolderTapped), for: .touchUpInside)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setImage(UIImage(systemName: "trash", withConfiguration: iconCfg), for: .normal)
        deleteBtn.tintColor = .systemRed
        deleteBtn.addTarget(self, action: #selector(deleteSelectedTapped), for: .touchUpInside)

        refreshSelectionBarColors()

        let stack = UIStackView(arrangedSubviews: [selectionCopyBtn, selectionCountLabel, selectionFolderBtn, deleteBtn])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -14)
        ])
        return bar
    }()

    private func refreshSelectionBarColors() {
        selectionCopyBtn.tintColor = DayPinDesign.accentContrast
        selectionFolderBtn.tintColor = DayPinDesign.accentContrast
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self, sectionIndex < self.sections.count else {
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 11, bottom: 16, trailing: 11)
            section.interGroupSpacing = 10

            let hdrSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
            let hdr = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: hdrSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [hdr]
            return section
        }

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.keyboardDismissMode = .onDrag
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self,  forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,  forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(TasksSectionHeader.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: TasksSectionHeader.reuseID)
        return cv
    }()

    private var allSections: [(date: Date, cards: [NoteCard])] = []
    private var sections:    [(date: Date, cards: [NoteCard])] = []
    private var animatedCardIndexPaths = Set<IndexPath>()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        addStandardBackground()
        setupUI()

        // Custom tap: closes search if open, otherwise dismisses keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(onSchemeChanged),
                                               name: .dayPinColorSchemeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSchemeChanged),
                                               name: .dayPinLanguageChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        loadAll()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    @objc private func handleBackgroundTap() {
        if isSearchOpen {
            closeSearch()
        } else {
            view.endEditing(true)
        }
    }

    // MARK: - UI

    private func setupUI() {
        headerContainer.backgroundColor = .clear
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)

        titleLabel.text = L10n.tabAll
        titleLabel.font = .inter(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(titleLabel)

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        searchBtn.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: iconCfg), for: .normal)
        searchBtn.layer.cornerRadius = 10
        searchBtn.layer.borderWidth = 1
        searchBtn.layer.masksToBounds = true
        searchBtn.translatesAutoresizingMaskIntoConstraints = false
        searchBtn.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        headerContainer.addSubview(searchBtn)
        refreshButtonColors()
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerContainer.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),

            searchBtn.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            searchBtn.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            searchBtn.widthAnchor.constraint(equalToConstant: 34),
            searchBtn.heightAnchor.constraint(equalToConstant: 34)
        ])

        setupSearchOverlay()

        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onFilterChange = { [weak self] filter in
            self?.activeFilter = filter
            self?.applyFilters()
        }
        view.addSubview(filterChips)

        view.addSubview(collectionView)
        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(selectionBar)

        NSLayoutConstraint.activate([
            filterChips.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 2),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterChips.heightAnchor.constraint(equalToConstant: 38),

            collectionView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            selectionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            selectionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func setupSearchOverlay() {
        searchContainer.backgroundColor = .clear
        searchContainer.clipsToBounds = true
        searchContainer.alpha = 0
        searchContainer.isUserInteractionEnabled = false
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        searchBar.placeholder = L10n.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = DayPinDesign.accent
        searchBar.backgroundImage = UIImage()
        searchBar.setValue(L10n.cancel, forKey: "cancelButtonText")
        searchBar.setShowsCancelButton(true, animated: false)
        searchBar.searchTextField.font = .inter(ofSize: 16, weight: .regular)
        searchBar.searchTextField.layer.cornerRadius = 12
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainer.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),

            searchBar.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8)
        ])
    }

    private func refreshButtonColors() {
        let accent = DayPinDesign.accent
        searchBtn.tintColor = accent
        searchBtn.backgroundColor = accent.withAlphaComponent(0.12)
        searchBtn.layer.borderColor = accent.withAlphaComponent(0.3).cgColor
    }

    // MARK: - Search toggle

    @objc private func searchButtonTapped() {
        isSearchOpen = true
        searchContainer.isUserInteractionEnabled = true
        searchContainer.transform = CGAffineTransform(translationX: 0, y: -8)
        searchContainer.alpha = 0
        UIView.animate(withDuration: 0.28, delay: 0,
                       usingSpringWithDamping: 0.85, initialSpringVelocity: 0.3) {
            self.headerContainer.alpha = 0
            self.headerContainer.transform = CGAffineTransform(translationX: 0, y: -6)
            self.searchContainer.alpha = 1
            self.searchContainer.transform = .identity
        }
        searchBar.becomeFirstResponder()
    }

    private func closeSearch() {
        searchQuery = ""
        isSearchOpen = false
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchContainer.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.25, delay: 0,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.headerContainer.alpha = 1
            self.headerContainer.transform = .identity
            self.searchContainer.alpha = 0
            self.searchContainer.transform = CGAffineTransform(translationX: 0, y: -8)
        }
        applyFilters()
    }

    // MARK: - Data loading

    private func loadAll() {
        let all = CardStore.shared.allCards()
        let grouped = Dictionary(grouping: all) { Calendar.current.startOfDay(for: $0.dayDate) }
        allSections = grouped.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
        applyFilters()
    }

    private func applyFilters() {
        var result = allSections

        if activeFilter != .all {
            let type: CardType
            switch activeFilter {
            case .text:  type = .text
            case .image: type = .image
            case .link:  type = .link
            case .all:   type = .text
            }
            result = result.compactMap { (date, cards) in
                let filtered = cards.filter { $0.type == type }
                return filtered.isEmpty ? nil : (date, filtered)
            }
        }

        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.compactMap { (date, cards) in
                let filtered = cards.filter {
                    $0.title.lowercased().contains(q) || $0.comment.lowercased().contains(q)
                }
                return filtered.isEmpty ? nil : (date, filtered)
            }
        }

        let allCards = allSections.flatMap { $0.cards }
        filterChips.updateCounts(
            text:  allCards.filter { $0.type == .text  }.count,
            image: allCards.filter { $0.type == .image }.count,
            link:  allCards.filter { $0.type == .link  }.count
        )

        sections = result
        animatedCardIndexPaths.removeAll()
        collectionView.reloadData()
    }

    @objc private func onSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        titleLabel.text = L10n.tabAll
        refreshButtonColors()
        refreshSelectionBarColors()
        collectionView.reloadData()
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            refreshButtonColors()
        }
    }

    private func presentEditor(for card: NoteCard) {
        switch card.type {
        case .text:
            let vc = TextCardEditorViewController(card: card as? TextCard, dayDate: card.dayDate)
            vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadAll() }
            presentEditorSheet(vc)
        case .image:
            guard let img = card as? ImageCard else { return }
            let vc = ImageCardEditorViewController(imageData: img.imageData, dayDate: card.dayDate, existingCard: img)
            vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadAll() }
            present(UINavigationController(rootViewController: vc), animated: true)
        case .link:
            let vc = LinkCardEditorViewController(card: card as? LinkCard, dayDate: card.dayDate)
            vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadAll() }
            presentEditorSheet(vc)
        }
    }

    // MARK: - Multi-select

    private var flatCards: [NoteCard] { sections.flatMap { $0.cards } }

    private func enterSelectMode(initialCard: NoteCard? = nil) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSelectMode = true
        selectedIDs = []
        if let card = initialCard { selectedIDs.insert(card.id) }

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.cancel, style: .plain, target: self, action: #selector(exitSelectModeTapped)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: L10n.done, style: .done, target: self, action: #selector(exitSelectModeTapped))
        ]

        selectionBar.isHidden = false
        UIView.animate(withDuration: 0.2) { self.selectionBar.alpha = 1 }
        collectionView.reloadData()
        updateSelectionBarLabel()
    }

    @objc private func exitSelectModeTapped() { exitSelectMode() }

    private func exitSelectMode() {
        isSelectMode = false
        selectedIDs = []

        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItems = []

        selectionBar.isHidden = true
        collectionView.reloadData()
    }

    private func toggleSelection(_ card: NoteCard) {
        if selectedIDs.contains(card.id) {
            selectedIDs.remove(card.id)
        } else {
            selectedIDs.insert(card.id)
        }
        updateSelectionBarLabel()
        collectionView.reloadData()
    }

    private func updateSelectionBarLabel() {
        let n = selectedIDs.count
        selectionCountLabel.text = n == 0 ? L10n.selectNotesPrompt : L10n.selectedCount(n)
    }

    @objc private func deleteSelectedTapped() {
        guard !selectedIDs.isEmpty else { return }
        let count = selectedIDs.count
        GlassAlert.confirm(
            in: self,
            title: L10n.deleteNotesTitle(count),
            confirmTitle: L10n.delete
        ) { [weak self] in
            guard let self else { return }
            let toDelete = self.flatCards.filter { self.selectedIDs.contains($0.id) }
            CardStore.shared.deleteMany(cards: toDelete)
            self.exitSelectMode()
            self.loadAll()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    @objc private func moveSelectedToFolderTapped() {
        guard !selectedIDs.isEmpty else { return }
        guard !FolderStore.shared.all().isEmpty else {
            GlassAlert.show(in: self, title: L10n.noFolders, message: L10n.noFoldersMessage)
            return
        }
        let vc = FolderPickerBottomSheet(currentFolderID: nil)
        vc.onPick = { [weak self] folder in
            guard let self else { return }
            let toMove = self.flatCards.filter { self.selectedIDs.contains($0.id) }
            toMove.forEach { $0.folderID = folder?.id }
            CardStore.shared.saveMany(cards: toMove)
            self.exitSelectMode()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        presentFolderPicker(vc)
    }

    @objc private func copySelectedTapped() {
        let cards = flatCards.filter { selectedIDs.contains($0.id) }
        guard !cards.isEmpty else { return }
        let vc = CopyToDayViewController()
        vc.onCopy = { [weak self] date in
            cards.forEach { CardStore.shared.save(card: $0.duplicated(to: date)) }
            self?.exitSelectMode()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension TasksViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchQuery = searchText
        applyFilters()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        closeSearch()
    }
}

// MARK: - UICollectionViewDataSource

extension TasksViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let card = sections[indexPath.section].cards[indexPath.item]
        let cell: UICollectionViewCell
        switch card.type {
        case .text:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as? TextCardCell,
                  let text = card as? TextCard else { return UICollectionViewCell() }
            c.configure(with: text); cell = c
        case .image:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as? ImageCardCell,
                  let image = card as? ImageCard else { return UICollectionViewCell() }
            c.configure(with: image); cell = c
        case .link:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as? LinkCardCell,
                  let link = card as? LinkCard else { return UICollectionViewCell() }
            c.configure(with: link); cell = c
        }
        cell.applySelectionOverlay(isSelecting: isSelectMode, isSelected: selectedIDs.contains(card.id))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: TasksSectionHeader.reuseID, for: indexPath
        ) as? TasksSectionHeader else {
            return UICollectionReusableView()
        }
        header.configure(date: sections[indexPath.section].date)
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension TasksViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !animatedCardIndexPaths.contains(indexPath) {
            animatedCardIndexPaths.insert(indexPath)
            let flatIndex = sections[0..<indexPath.section].reduce(0) { $0 + $1.cards.count } + indexPath.item
            cell.animateCardAppearance(at: flatIndex)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let card = sections[indexPath.section].cards[indexPath.item]
        if isSelectMode {
            toggleSelection(card)
            return
        }
        switch card.type {
        case .text:
            guard let text = card as? TextCard else { return }
            navigationController?.pushViewController(CardDetailViewController(card: text), animated: true)
        case .image:
            guard let image = card as? ImageCard else { return }
            navigationController?.pushViewController(ImageCardOverviewViewController(card: image), animated: true)
        case .link:
            guard let link = card as? LinkCard else { return }
            navigationController?.pushViewController(LinkCardDetailViewController(card: link), animated: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !isSelectMode else { return nil }
        let card = sections[indexPath.section].cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            guard let self else { return nil }
            let select = UIAction(title: L10n.selectNotes, image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.enterSelectMode(initialCard: card)
            }
            let share = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                var items: [Any] = [card.title]
                if !card.comment.isEmpty { items.append(card.comment) }
                if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
                if let link = card as? LinkCard { items.append(link.url) }
                self?.present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
            }
            let folderAction = UIAction(
                title: L10n.inFolder,
                image: UIImage(systemName: "folder.badge.plus")
            ) { [weak self] _ in
                guard let self else { return }
                let picker = FolderPickerBottomSheet(currentFolderID: card.folderID)
                picker.onPick = { [weak self] folder in
                    card.folderID = folder?.id
                    CardStore.shared.save(card: card)
                    self?.loadAll()
                }
                self.presentFolderPicker(picker)
            }
            let edit = UIAction(title: L10n.edit, image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentEditor(for: card)
            }
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                CardStore.shared.delete(card: card)
                self?.loadAll()
            }
            return UIMenu(children: [select, share, folderAction, edit, delete])
        })
    }

    private func presentFolderPicker(_ vc: FolderPickerBottomSheet) {
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        present(nav, animated: true)
    }
}

// MARK: - TasksSectionHeader

final class TasksSectionHeader: UICollectionReusableView {

    static let reuseID = "TasksSectionHeader"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .inter(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(date: Date) {
        if Calendar.current.isDateInToday(date) {
            label.text = L10n.todaySection
        } else if Calendar.current.isDateInYesterday(date) {
            label.text = L10n.yesterdaySection
        } else {
            let df = DateFormatter()
            df.dateFormat = "d MMMM yyyy"
            df.locale = L10n.activeLocale
            label.text = df.string(from: date).uppercased()
        }
    }
}
