import UIKit
import PhotosUI
import SafariServices

final class TodayViewController: UIViewController {

    // MARK: - State

    private var currentDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Data

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

    // MARK: - Multi-select state
    private var isSelectMode  = false
    private var selectedIDs   = Set<UUID>()

    // MARK: - UI

    private let weekStrip       = WeekCalendarView()
    private let filterChips     = FilterChipsView()
    private let searchResultsVC = GlobalSearchViewController()
    private let navSearchBar    = UISearchBar()
    private let navTitleLabel   = UILabel()

    // Плавающая панель действий при мульти-выборе
    private lazy var selectionBar: UIView = {
        let bar = UIView()
        bar.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.12, alpha: 0.95)
                : UIColor(white: 0.98, alpha: 0.95)
        }
        bar.layer.cornerRadius  = 18
        bar.layer.shadowColor   = UIColor.black.cgColor
        bar.layer.shadowOpacity = 0.15
        bar.layer.shadowRadius  = 12
        bar.layer.shadowOffset  = CGSize(width: 0, height: 4)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isHidden = true

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)

        let copyBtn = UIButton(type: .system)
        copyBtn.setImage(UIImage(systemName: "calendar.badge.plus", withConfiguration: iconCfg), for: .normal)
        copyBtn.tintColor = DayPinDesign.accent
        copyBtn.addTarget(self, action: #selector(copySelectedTapped), for: .touchUpInside)

        selectionCountLabel.font      = .systemFont(ofSize: 13, weight: .medium)
        selectionCountLabel.textColor = .secondaryLabel
        selectionCountLabel.textAlignment = .center

        let folderBtn = UIButton(type: .system)
        folderBtn.setImage(UIImage(systemName: "folder.badge.plus", withConfiguration: iconCfg), for: .normal)
        folderBtn.tintColor = DayPinDesign.accent
        folderBtn.addTarget(self, action: #selector(moveSelectedToFolderTapped), for: .touchUpInside)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.setImage(UIImage(systemName: "trash", withConfiguration: iconCfg), for: .normal)
        deleteBtn.tintColor = .systemRed
        deleteBtn.addTarget(self, action: #selector(deleteSelectedTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [copyBtn, selectionCountLabel, folderBtn, deleteBtn])
        stack.axis         = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment    = .center
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
    private let selectionCountLabel = UILabel()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.keyboardDismissMode = .onDrag
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self,  forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,  forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(EmptyCardCell.self, forCellWithReuseIdentifier: EmptyCardCell.reuseID)
        cv.register(
            CardTypeSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: CardTypeSectionHeader.reuseID
        )
        return cv
    }()

    private lazy var addButton: GlassFABView = {
        let fab = GlassFABView()
        fab.translatesAutoresizingMaskIntoConstraints = false
        fab.action = { [weak self] in self?.addTapped() }
        return fab
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        setupSearchController()
        setupUI()
        setupGestures()
        setupThemeButton()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onDataRestored),
            name: .dayPinDataRestored,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onTriggerAdd),
            name: NSNotification.Name("daypin.triggerAdd"),
            object: nil
        )
    }

    @objc private func onTriggerAdd() {
        // Called via daypin://add deep link (e.g. from widget)
        guard !isSelectMode else { return }
        addTapped()
    }

    @objc private func onDataRestored() {
        currentDate = Calendar.current.startOfDay(for: Date())
        weekStrip.navigate(to: currentDate)
        updateNavTitle()
        loadCards()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        collectionView.reloadData()
        setupThemeButton()
        addButton.refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCards()
    }

    // MARK: - Setup

    private func setupSearchController() {
        // Date label — left side of nav bar
        navTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        navTitleLabel.textColor = .label
        updateNavTitle()
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: navTitleLabel)

        // Search bar — nav bar title view (inline)
        navSearchBar.placeholder = "Поиск"
        navSearchBar.searchBarStyle = .minimal
        navSearchBar.tintColor = DayPinDesign.accent
        navSearchBar.delegate = self
        navigationItem.titleView = navSearchBar

        searchResultsVC.onOpen = { [weak self] card in
            self?.navSearchBar.text = nil
            self?.navSearchBar.resignFirstResponder()
            self?.hideSearchOverlay()
            self?.openCard(card)
        }
    }

    private func updateNavTitle() {
        if Calendar.current.isDateInToday(currentDate) {
            navTitleLabel.text = "Сегодня"
        } else {
            let df = DateFormatter()
            df.locale = Locale.current
            df.setLocalizedDateFormatFromTemplate("EEEd")
            navTitleLabel.text = df.string(from: currentDate).capitalized
        }
    }

    private func showSearchOverlay() {
        guard searchResultsVC.parent == nil else { return }
        addChild(searchResultsVC)
        let sv = searchResultsVC.view!
        sv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        searchResultsVC.didMove(toParent: self)
        sv.alpha = 0
        UIView.animate(withDuration: 0.18) { sv.alpha = 1 }
    }

    private func hideSearchOverlay() {
        guard searchResultsVC.parent != nil else { return }
        UIView.animate(withDuration: 0.15) {
            self.searchResultsVC.view.alpha = 0
        } completion: { _ in
            self.searchResultsVC.willMove(toParent: nil)
            self.searchResultsVC.view.removeFromSuperview()
            self.searchResultsVC.removeFromParent()
        }
    }

    private func setupUI() {
        // Wave watermark — behind everything
        let wave = WaveBackgroundView()
        wave.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wave)
        NSLayoutConstraint.activate([
            wave.topAnchor.constraint(equalTo: view.topAnchor),
            wave.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wave.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wave.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45)
        ])

        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onFilterChange = { [weak self] filter in
            self?.activeFilter = filter
            self?.applyFilters()
        }

        weekStrip.translatesAutoresizingMaskIntoConstraints = false
        weekStrip.onDaySelected = { [weak self] date in
            guard let self else { return }
            let forward = date > self.currentDate
            self.transitionToDate(date, direction: forward ? 1 : -1)
        }

        view.addSubview(filterChips)
        view.addSubview(weekStrip)
        view.addSubview(collectionView)
        view.addSubview(addButton)
        view.addSubview(selectionBar)

        NSLayoutConstraint.activate([
            weekStrip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            weekStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            weekStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            weekStrip.heightAnchor.constraint(equalToConstant: 68),

            filterChips.topAnchor.constraint(equalTo: weekStrip.bottomAnchor, constant: 2),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterChips.heightAnchor.constraint(equalToConstant: 42),

            collectionView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 2),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 52),
            addButton.heightAnchor.constraint(equalToConstant: 52),

            selectionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            selectionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        collectionView.dataSource = self
        collectionView.delegate   = self
    }

    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }

    private func setupThemeButton() {
        let menu = UIMenu(options: .displayInline, children: [
            UIAction(title: "Выбрать заметки",
                     image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.selectTapped()
            },
            UIAction(title: "Недавно удалённые",
                     image: UIImage(systemName: "clock.arrow.circlepath")) { [weak self] _ in
                self?.trashTapped()
            },
            UIAction(title: "Резервная копия",
                     image: UIImage(systemName: "externaldrive")) { [weak self] _ in
                self?.backupTapped()
            },
            UIAction(title: "Оформление",
                     image: UIImage(systemName: "paintbrush")) { [weak self] _ in
                self?.openThemePicker()
            }
        ])

        let moreBtn = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: menu
        )
        moreBtn.tintColor = DayPinDesign.accent
        navigationItem.rightBarButtonItems = [moreBtn]
    }

    private func openThemePicker() {
        let vc = ThemePickerViewController()
        presentEditorSheet(vc)
    }

    // MARK: - Day navigation

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let cal = Calendar.current
        let delta = gesture.direction == .left ? 1 : -1
        guard let newDate = cal.date(byAdding: .day, value: delta, to: currentDate) else { return }
        transitionToDate(newDate, direction: delta)
    }

    private func transitionToDate(_ newDate: Date, direction: Int) {
        guard !Calendar.current.isDate(newDate, inSameDayAs: currentDate) else { return }

        let outX = CGFloat(direction) * (-view.bounds.width * 0.35)
        let inX  = CGFloat(direction) * (view.bounds.width * 0.35)

        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
            self.collectionView.transform = CGAffineTransform(translationX: outX, y: 0)
            self.collectionView.alpha = 0
        } completion: { _ in
            self.currentDate = newDate
            self.weekStrip.navigate(to: newDate)
            self.updateNavTitle()
            self.loadCards()
            self.collectionView.transform = CGAffineTransform(translationX: -inX, y: 0)
            self.collectionView.alpha = 0
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
                self.collectionView.transform = .identity
                self.collectionView.alpha = 1
            }
        }
    }

    // MARK: - Data

    func loadCards() {
        allCards = CardStore.shared.cards(for: currentDate)
        applyFilters()
    }

    private func applyFilters(animated: Bool = false) {
        let textAll  = allCards.filter { $0.type == .text }
        let imageAll = allCards.filter { $0.type == .image }
        let linkAll  = allCards.filter { $0.type == .link }

        // Counts always reflect unfiltered day totals — so chips stay informative
        filterChips.updateCounts(text: textAll.count, image: imageAll.count, link: linkAll.count)

        var text  = textAll
        var image = imageAll
        var link  = linkAll

        switch activeFilter {
        case .text:  image = []; link  = []
        case .image: text  = []; link  = []
        case .link:  text  = []; image = []
        case .all:   break
        }

        activeSections = [
            TypeSection(type: .text,  cards: text),
            TypeSection(type: .image, cards: image),
            TypeSection(type: .link,  cards: link)
        ].filter { !$0.cards.isEmpty }

        if animated {
            UIView.transition(with: collectionView, duration: 0.28,
                              options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.collectionView.reloadData()
            }
        } else {
            collectionView.reloadData()
        }
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, _ in
            guard let self else { return nil }

            // Empty state → full-width single item, no header
            if self.activeSections.isEmpty {
                let size  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
                let item  = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let sec   = NSCollectionLayoutSection(group: group)
                sec.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 24, trailing: 16)
                return sec
            }

            // All sections: same 2-column grid with a compact type label header
            let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item      = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

            let sec = NSCollectionLayoutSection(group: group)
            sec.contentInsets    = NSDirectionalEdgeInsets(top: 4, leading: 11, bottom: 16, trailing: 11)
            sec.interGroupSpacing = 10

            let hdrSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(32))
            let hdr = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: hdrSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            sec.boundarySupplementaryItems = [hdr]
            return sec
        }
    }

    // MARK: - Multi-select

    private func enterSelectMode(initialCard: NoteCard? = nil) {
        isSelectMode = true
        selectedIDs  = []
        if let card = initialCard { selectedIDs.insert(card.id) }

        // Nav bar: «Готово» справа вместо обычных кнопок, поиск прячем
        navigationItem.titleView = nil
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена", style: .plain, target: self, action: #selector(exitSelectModeTapped)
        )
        let doneBtn = UIBarButtonItem(
            title: "Готово", style: .done, target: self, action: #selector(exitSelectModeTapped)
        )
        navigationItem.rightBarButtonItems = [doneBtn]

        addButton.isHidden = true
        selectionBar.isHidden = false

        UIView.animate(withDuration: 0.2) { self.selectionBar.alpha = 1 }
        collectionView.reloadData()
        updateSelectionBarLabel()
    }

    @objc private func exitSelectModeTapped() { exitSelectMode() }

    private func exitSelectMode() {
        isSelectMode = false
        selectedIDs  = []

        // Восстанавливаем nav bar
        setupSearchController()
        setupThemeButton()
        addButton.isHidden    = false
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
        selectionCountLabel.text = n == 0 ? "Выберите заметки" : "Выбрано: \(n)"
    }

    @objc private func deleteSelectedTapped() {
        guard !selectedIDs.isEmpty else { return }
        let count = selectedIDs.count
        let alert = UIAlertController(
            title: "Удалить \(count) заметок?",
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self else { return }
            let toDelete = self.activeSections.flatMap { $0.cards }.filter { self.selectedIDs.contains($0.id) }
            toDelete.forEach { CardStore.shared.delete(card: $0) }
            self.allCards = CardStore.shared.cards(for: self.currentDate)
            self.exitSelectMode()
            self.applyFilters(animated: true)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        })
        present(alert, animated: true)
    }

    @objc private func moveSelectedToFolderTapped() {
        guard !selectedIDs.isEmpty else { return }
        let folders = FolderStore.shared.all()
        guard !folders.isEmpty else {
            let alert = UIAlertController(title: "Нет папок",
                                          message: "Создайте папку в разделе «Папки»",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let sheet = UIAlertController(title: "Выберите папку", message: nil, preferredStyle: .actionSheet)
        for folder in folders {
            sheet.addAction(UIAlertAction(title: folder.name, style: .default) { [weak self] _ in
                guard let self else { return }
                let toMove = self.activeSections.flatMap { $0.cards }.filter { self.selectedIDs.contains($0.id) }
                toMove.forEach { card in
                    card.folderID = folder.id
                    CardStore.shared.save(card: card)
                }
                self.exitSelectMode()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            })
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - Trash / Recently Deleted

    @objc private func trashTapped() {
        let vc = RecentlyDeletedViewController()
        vc.onRestored = { [weak self] in self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    // MARK: - Select mode toggle

    @objc private func selectTapped() {
        if isSelectMode {
            exitSelectMode()
        } else {
            enterSelectMode()
        }
    }

    // MARK: - Backup

    @objc private func backupTapped() {
        let vc = BackupViewController()
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    // MARK: - Add action

    @objc private func addTapped() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        var actions: [GlassAction] = [
            GlassAction(L10n.cardText,  icon: "text.alignleft")        { [weak self] in self?.presentTextEditor(card: nil) },
            GlassAction(L10n.cardPhoto, icon: "photo.on.rectangle")     { [weak self] in self?.presentImagePicker() }
        ]
        if hasCamera {
            actions.append(GlassAction(L10n.cardCamera, icon: "camera") { [weak self] in self?.presentCamera() })
        }
        actions.append(GlassAction(L10n.cardLink, icon: "link") { [weak self] in self?.presentLinkEditor(card: nil) })
        actions.append(GlassAction(L10n.cancel, style: .cancel))
        GlassActionSheet.show(actions: actions, from: self, sourceView: addButton)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Editors

    func presentTextEditor(card: TextCard?) {
        let vc = TextCardEditorViewController(card: card, dayDate: currentDate)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        presentEditorSheet(vc)
    }

    func presentLinkEditor(card: LinkCard?) {
        let vc = LinkCardEditorViewController(card: card, dayDate: currentDate)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        presentEditorSheet(vc)
    }

    func presentImagePicker() {
        let picker = RecentPhotosPickerViewController()
        picker.onSelect = { [weak self] data in
            self?.presentImageCardEditor(imageData: data)
        }
        picker.onShowAll = { [weak self] in
            self?.presentSystemImagePicker()
        }
        present(picker, animated: true)
    }

    private func presentSystemImagePicker() {
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
        let vc = ImageCardEditorViewController(imageData: imageData, dayDate: currentDate, existingCard: nil)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func presentImageEditor(card: ImageCard) {
        let vc = ImageCardEditorViewController(imageData: card.imageData, dayDate: currentDate, existingCard: card)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func deleteCard(_ card: NoteCard) {
        var foundSection = -1, foundItem = -1
        for (si, sec) in activeSections.enumerated() {
            if let ii = sec.cards.firstIndex(where: { $0.id == card.id }) {
                foundSection = si; foundItem = ii; break
            }
        }

        CardStore.shared.delete(card: card)
        allCards = CardStore.shared.cards(for: currentDate)

        guard foundSection >= 0 else { applyFilters(); return }

        let ip = IndexPath(item: foundItem, section: foundSection)
        activeSections[foundSection].cards.remove(at: foundItem)
        let sectionEmpty = activeSections[foundSection].cards.isEmpty
        if sectionEmpty { activeSections.remove(at: foundSection) }
        let allEmpty = activeSections.isEmpty

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        collectionView.performBatchUpdates {
            self.collectionView.deleteItems(at: [ip])
            // Don't delete the section when it becomes the only one left turning into
            // the empty-state section — numberOfSections still returns 1 in that case.
            if sectionEmpty && !allEmpty {
                self.collectionView.deleteSections(IndexSet(integer: foundSection))
            }
        } completion: { _ in
            if allEmpty {
                UIView.transition(with: self.collectionView, duration: 0.2, options: .transitionCrossDissolve) {
                    self.collectionView.reloadData()
                }
            }
        }
    }

    func shareCard(_ card: NoteCard) {
        var items: [Any] = [card.title]
        if !card.comment.isEmpty { items.append(card.comment) }
        if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
        if let link = card as? LinkCard { items.append(link.url) }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }

    // MARK: - Multi-select: copy to day

    @objc private func copySelectedTapped() {
        let cards = activeSections.flatMap { $0.cards }.filter { selectedIDs.contains($0.id) }
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

extension TodayViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            hideSearchOverlay()
        } else {
            showSearchOverlay()
            searchResultsVC.reload(query: searchText)
        }
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Replace left bar item with compact xmark instead of full "Отмена" text
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let cancelBtn = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle.fill", withConfiguration: cfg),
            style: .plain,
            target: self,
            action: #selector(dismissSearch)
        )
        cancelBtn.tintColor = UIColor.tertiaryLabel
        navigationItem.leftBarButtonItem = cancelBtn
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchBar.text?.isEmpty ?? true {
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: navTitleLabel)
        }
    }

    @objc private func dismissSearch() {
        navSearchBar.text = nil
        navSearchBar.resignFirstResponder()
        hideSearchOverlay()
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: navTitleLabel)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        dismissSearch()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UICollectionViewDataSource

extension TodayViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        activeSections.isEmpty ? 1 : activeSections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        activeSections.isEmpty ? 1 : activeSections[section].cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if activeSections.isEmpty {
            return collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as! EmptyCardCell
        }
        let card = activeSections[indexPath.section].cards[indexPath.item]
        let cell: UICollectionViewCell
        switch card.type {
        case .text:
            let c = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as! TextCardCell
            c.configure(with: card as! TextCard); cell = c
        case .image:
            let c = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as! ImageCardCell
            c.configure(with: card as! ImageCard); cell = c
        case .link:
            let c = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as! LinkCardCell
            c.configure(with: card as! LinkCard); cell = c
        }
        cell.applySelectionOverlay(isSelecting: isSelectMode,
                                   isSelected: selectedIDs.contains(card.id))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: CardTypeSectionHeader.reuseID, for: indexPath
        ) as! CardTypeSectionHeader
        if !activeSections.isEmpty {
            header.configure(title: activeSections[indexPath.section].header,
                             color: activeSections[indexPath.section].accentColor)
        }
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension TodayViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !activeSections.isEmpty else { return }
        let card = activeSections[indexPath.section].cards[indexPath.item]
        if isSelectMode {
            toggleSelection(card)
        } else {
            openCard(card)
        }
    }

    func openCard(_ card: NoteCard) {
        switch card.type {
        case .text:
            navigationController?.pushViewController(CardDetailViewController(card: card as! TextCard), animated: true)
        case .image:
            navigationController?.pushViewController(ImageCardDetailViewController(card: card as! ImageCard), animated: true)
        case .link:
            navigationController?.pushViewController(LinkCardDetailViewController(card: card as! LinkCard), animated: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !activeSections.isEmpty else { return nil }

        // In select mode — tap selects, context menu disabled
        if isSelectMode { return nil }

        let card = activeSections[indexPath.section].cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            guard let self else { return nil }

            let select = UIAction(title: "Выбрать", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.enterSelectMode(initialCard: card)
            }
            let share  = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in self?.shareCard(card) }
            let copyToDay = UIAction(title: "Скопировать в день", image: UIImage(systemName: "calendar.badge.plus")) { [weak self] _ in
                guard let self else { return }
                let vc = CopyToDayViewController()
                vc.onCopy = { date in
                    CardStore.shared.save(card: card.duplicated(to: date))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            let edit   = UIAction(title: L10n.edit,  image: UIImage(systemName: "pencil")) { [weak self] _ in
                switch card.type {
                case .text:  self?.presentTextEditor(card: card as? TextCard)
                case .image: if let c = card as? ImageCard { self?.presentImageEditor(card: c) }
                case .link:  self?.presentLinkEditor(card: card as? LinkCard)
                }
            }
            let folderActions = FolderStore.shared.all().map { folder -> UIAction in
                let isCurrent = card.folderID == folder.id
                return UIAction(
                    title: folder.name,
                    image: UIImage(systemName: isCurrent ? "folder.fill" : "folder"),
                    state: isCurrent ? .on : .off
                ) { _ in
                    card.folderID = isCurrent ? nil : folder.id
                    CardStore.shared.save(card: card)
                }
            }
            let folderMenu = UIMenu(
                title: "В папку",
                image: UIImage(systemName: "folder.badge.plus"),
                children: folderActions.isEmpty
                    ? [UIAction(title: "Нет папок", attributes: .disabled) { _ in }]
                    : folderActions
            )
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in self?.deleteCard(card) }
            return UIMenu(children: [select, share, copyToDay, edit, folderMenu, delete])
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

extension TodayViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        presentImageCardEditor(imageData: image?.jpegData(compressionQuality: 0.85))
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
}

// MARK: - CardTypeSectionHeader

final class CardTypeSectionHeader: UICollectionReusableView {

    static let reuseID = "CardTypeSectionHeader"

    private let label    = UILabel()
    private let colorDot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        colorDot.layer.cornerRadius = 3
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [colorDot, label])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            colorDot.widthAnchor.constraint(equalToConstant: 6),
            colorDot.heightAnchor.constraint(equalToConstant: 6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, color: UIColor) {
        label.text = title
        colorDot.backgroundColor = color
    }
}
