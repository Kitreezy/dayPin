import UIKit
import PhotosUI
import SafariServices

final class TodayViewController: UIViewController {

    // MARK: - State

    private var currentDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Data

    private var allCards:    [NoteCard] = []
    private var flatCards:   [NoteCard] = []
    private var activeFilter: FilterChipsView.Filter = .all

    // MARK: - Multi-select state

    private var isSelectMode = false
    private var selectedIDs  = Set<UUID>()

    // MARK: - Search state

    private var isSearchOpen  = false
    private var searchQuery   = ""

    // MARK: - UI: Header

    private let headerContainer  = UIView()
    private let titleLabel       = UILabel()
    private let dateLabel        = UILabel()
    private let searchBtn        = UIButton(type: .system)
    private let moreBtn          = UIButton(type: .system)

    // Search overlay — slides in over the header when search is active
    private let searchContainer  = UIView()
    private let searchBar        = UISearchBar()

    // MARK: - UI: Content

    private let weekStrip    = WeekCalendarView()
    private let filterChips  = FilterChipsView()
    private let stripSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.35)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Multi-select bar

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

        selectionCountLabel.font      = .inter(ofSize: 13, weight: .medium)
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
        setupUI()
        setupGestures()
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        loadCards()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshButtonColors()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Notifications

    @objc private func onTriggerAdd() {
        guard !isSelectMode else { return }
        addTapped()
    }

    @objc private func onDataRestored() {
        currentDate = Calendar.current.startOfDay(for: Date())
        weekStrip.navigate(to: currentDate)
        updateDateLabels()
        loadCards()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        refreshButtonColors()
        collectionView.reloadData()
        addButton.refresh()
        rebuildMoreMenu()
    }

    @objc private func onLanguageChanged() {
        updateDateLabels()
        searchBar.placeholder = L10n.searchPlaceholder
        rebuildMoreMenu()
        collectionView.reloadData()
    }

    private func refreshButtonColors() {
        let accent = DayPinDesign.accent
        searchBtn.tintColor       = accent
        searchBtn.backgroundColor = accent.withAlphaComponent(0.12)
        searchBtn.layer.borderColor = accent.withAlphaComponent(0.3).cgColor

        // moreBtn uses neutral surface color from the system so it adapts automatically
        moreBtn.tintColor         = .secondaryLabel
        moreBtn.backgroundColor   = UIColor.secondarySystemFill
        moreBtn.layer.borderColor = UIColor.separator.cgColor
    }

    // MARK: - Setup

    private func setupUI() {
        // Gradient background (shared helper)
        addStandardBackground()

        // Header container
        headerContainer.backgroundColor = .clear
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)

        // Title — large bold, matches design
        titleLabel.font = .inter(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Date subtitle
        dateLabel.font = .inter(ofSize: 13, weight: .regular)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        updateDateLabels()

        // Search button — accent-tinted glass circle
        let btnSymbolCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        searchBtn.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: btnSymbolCfg), for: .normal)
        searchBtn.layer.cornerRadius = 17
        searchBtn.layer.borderWidth  = 0.5
        searchBtn.translatesAutoresizingMaskIntoConstraints = false
        searchBtn.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)

        // More (···) button — neutral glass circle
        moreBtn.setImage(UIImage(systemName: "ellipsis", withConfiguration: btnSymbolCfg), for: .normal)
        moreBtn.layer.cornerRadius = 17
        moreBtn.layer.borderWidth  = 0.5
        moreBtn.showsMenuAsPrimaryAction = true
        moreBtn.translatesAutoresizingMaskIntoConstraints = false

        refreshButtonColors()  // sets tint/bg/border from current scheme
        rebuildMoreMenu()

        headerContainer.addSubview(titleLabel)
        headerContainer.addSubview(dateLabel)
        headerContainer.addSubview(searchBtn)
        headerContainer.addSubview(moreBtn)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: searchBtn.leadingAnchor, constant: -8),

            searchBtn.trailingAnchor.constraint(equalTo: moreBtn.leadingAnchor, constant: -8),
            searchBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            searchBtn.widthAnchor.constraint(equalToConstant: 34),
            searchBtn.heightAnchor.constraint(equalToConstant: 34),

            moreBtn.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            moreBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            moreBtn.widthAnchor.constraint(equalToConstant: 34),
            moreBtn.heightAnchor.constraint(equalToConstant: 34),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            dateLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -10)
        ])

        setupSearchOverlay()

        // Week strip and filter chips
        weekStrip.translatesAutoresizingMaskIntoConstraints = false
        weekStrip.onDaySelected = { [weak self] date in
            guard let self else { return }
            let forward = date > self.currentDate
            self.transitionToDate(date, direction: forward ? 1 : -1)
        }

        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onFilterChange = { [weak self] filter in
            self?.activeFilter = filter
            self?.applyFilters()
        }

        view.addSubview(headerContainer)
        view.addSubview(weekStrip)
        view.addSubview(stripSeparator)
        view.addSubview(filterChips)
        view.addSubview(collectionView)
        view.addSubview(addButton)
        view.addSubview(selectionBar)

        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            weekStrip.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 4),
            weekStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            weekStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            weekStrip.heightAnchor.constraint(equalToConstant: 106),

            // Separator between week strip and filter chips
            stripSeparator.topAnchor.constraint(equalTo: weekStrip.bottomAnchor),
            stripSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stripSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stripSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            filterChips.topAnchor.constraint(equalTo: stripSeparator.bottomAnchor, constant: 2),
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

    // MARK: - Search overlay setup

    private func setupSearchOverlay() {
        // Transparent container — matches headerContainer height exactly so week strip
        // stays flush. No background: the search field floats directly over the gradient.
        searchContainer.backgroundColor        = .clear
        searchContainer.clipsToBounds          = true
        searchContainer.alpha                  = 0
        searchContainer.isUserInteractionEnabled = false
        searchContainer.translatesAutoresizingMaskIntoConstraints = false

        searchBar.placeholder    = L10n.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor      = DayPinDesign.accent
        searchBar.setShowsCancelButton(true, animated: false)
        searchBar.delegate       = self
        // Strip the default opaque bar so only the inner rounded text field is visible
        searchBar.backgroundImage = UIImage()
        // Localised "Cancel" / "Отмена"
        searchBar.setValue(L10n.cancel, forKey: "cancelButtonText")
        // Larger text inside the field
        searchBar.searchTextField.font            = .inter(ofSize: 16, weight: .regular)
        searchBar.searchTextField.layer.cornerRadius = 12
        searchBar.searchTextField.layer.masksToBounds = true
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchBar)

        view.addSubview(searchContainer)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainer.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),

            searchBar.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func rebuildMoreMenu() {
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
            UIAction(title: L10n.isRussian ? "Оформление" : "Appearance",
                     image: UIImage(systemName: "paintbrush")) { [weak self] _ in
                self?.openThemePicker()
            },
            UIAction(title: L10n.isRussian ? "Фон" : "Background",
                     image: UIImage(systemName: "rectangle.fill")) { [weak self] _ in
                self?.openBackgroundPicker()
            },
            UIAction(title: L10n.language,
                     image: UIImage(systemName: "globe")) { [weak self] _ in
                self?.showLanguagePicker()
            }
        ])
        moreBtn.menu = menu
    }

    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        // Tap anywhere on background: close search if open, otherwise dismiss keyboard
        let bgTap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        bgTap.cancelsTouchesInView = false
        view.addGestureRecognizer(bgTap)
    }

    @objc private func handleBackgroundTap() {
        if isSearchOpen {
            closeSearch()
        } else {
            view.endEditing(true)
        }
    }

    // MARK: - Header labels

    private func updateDateLabels() {
        if Calendar.current.isDateInToday(currentDate) {
            titleLabel.text = L10n.today
        } else {
            let df = DateFormatter()
            df.locale = L10n.activeLocale
            df.setLocalizedDateFormatFromTemplate("EEEd")
            titleLabel.text = df.string(from: currentDate).capitalized
        }

        let df2 = DateFormatter()
        df2.locale = L10n.activeLocale
        df2.dateFormat = "EEEE, d MMMM yyyy"
        dateLabel.text = df2.string(from: currentDate).capitalized
    }

    // MARK: - Search toggle

    @objc private func searchButtonTapped() {
        guard !isSearchOpen else { return }
        isSearchOpen = true
        searchContainer.isUserInteractionEnabled = true
        // Start search bar slightly above its final position for a natural drop-in feel
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
        isSearchOpen = false
        searchQuery  = ""
        searchBar.text = nil
        searchBar.resignFirstResponder()
        searchContainer.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.22, delay: 0,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.headerContainer.alpha = 1
            self.headerContainer.transform = .identity
            self.searchContainer.alpha = 0
            self.searchContainer.transform = CGAffineTransform(translationX: 0, y: -8)
        } completion: { _ in
            self.searchContainer.transform = .identity
        }
        applyFilters()
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
            self.updateDateLabels()
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
        weekStrip.refreshNoteDots()   // keep note dots in sync
        applyFilters()
    }

    private func applyFilters(animated: Bool = false) {
        // When searching: scan ALL cards across all dates (global search)
        if isSearchOpen && !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            flatCards = CardStore.shared.allCards().filter {
                $0.title.lowercased().contains(q) || $0.comment.lowercased().contains(q)
            }
            flatCards.sort { $0.createdAt > $1.createdAt }

            if animated {
                UIView.transition(with: collectionView, duration: 0.2,
                                  options: [.transitionCrossDissolve, .allowUserInteraction]) {
                    self.collectionView.reloadData()
                }
            } else {
                collectionView.reloadData()
            }
            return
        }

        // Normal per-day filtering
        let textCards  = allCards.filter { $0.type == .text }
        let imageCards = allCards.filter { $0.type == .image }
        let linkCards  = allCards.filter { $0.type == .link }

        filterChips.updateCounts(text: textCards.count, image: imageCards.count, link: linkCards.count)

        switch activeFilter {
        case .all:   flatCards = allCards
        case .text:  flatCards = textCards
        case .image: flatCards = imageCards
        case .link:  flatCards = linkCards
        }

        flatCards.sort { $0.createdAt > $1.createdAt }

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

            if self.flatCards.isEmpty {
                let size  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
                let item  = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let sec   = NSCollectionLayoutSection(group: group)
                sec.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 24, trailing: 16)
                return sec
            }

            let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item      = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

            let sec = NSCollectionLayoutSection(group: group)
            sec.contentInsets    = NSDirectionalEdgeInsets(top: 4, leading: 11, bottom: 16, trailing: 11)
            sec.interGroupSpacing = 10
            return sec
        }
    }

    // MARK: - Multi-select

    private func enterSelectMode(initialCard: NoteCard? = nil) {
        isSelectMode = true
        selectedIDs  = []
        if let card = initialCard { selectedIDs.insert(card.id) }

        // Hide custom header buttons, show done/cancel in nav area via nav bar
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена", style: .plain, target: self, action: #selector(exitSelectModeTapped)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(exitSelectModeTapped))
        ]

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

        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationItem.leftBarButtonItem  = nil
        navigationItem.rightBarButtonItems = []

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
            let toDelete = self.flatCards.filter { self.selectedIDs.contains($0.id) }
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
                let toMove = self.flatCards.filter { self.selectedIDs.contains($0.id) }
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

    // MARK: - Theme / Background

    private func openThemePicker() {
        let vc = ThemePickerViewController()
        presentEditorSheet(vc)
    }

    private func openBackgroundPicker() {
        let vc  = BackgroundPickerViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    // MARK: - Language picker

    private func showLanguagePicker() {
        let current = L10n.languageOverride ?? (L10n.isRussian ? "ru" : "en")
        let sheet = UIAlertController(title: L10n.language, message: nil, preferredStyle: .actionSheet)

        let ruTitle = L10n.langRussian + (current == "ru" ? " ✓" : "")
        sheet.addAction(UIAlertAction(title: ruTitle, style: .default) { _ in
            L10n.languageOverride = "ru"
        })

        let enTitle = L10n.langEnglish + (current == "en" ? " ✓" : "")
        sheet.addAction(UIAlertAction(title: enTitle, style: .default) { _ in
            L10n.languageOverride = "en"
        })

        let sysTitle = L10n.langSystem + (L10n.languageOverride == nil ? " ✓" : "")
        sheet.addAction(UIAlertAction(title: sysTitle, style: .default) { _ in
            L10n.languageOverride = nil
        })

        sheet.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - Add action

    @objc private func addTapped() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        var actions: [AddNoteAction] = [
            AddNoteAction(title: L10n.cardText,  icon: "text.alignleft",     badgeColor: DayPinDesign.textCardTint)  { [weak self] in self?.presentTextEditor(card: nil) },
            AddNoteAction(title: L10n.cardPhoto, icon: "photo.on.rectangle", badgeColor: DayPinDesign.imageCardTint) { [weak self] in self?.presentImagePicker() }
        ]
        if hasCamera {
            actions.append(AddNoteAction(title: L10n.cardCamera, icon: "camera", badgeColor: DayPinDesign.imageCardTint) { [weak self] in self?.presentCamera() })
        }
        actions.append(AddNoteAction(title: L10n.cardLink, icon: "link", badgeColor: DayPinDesign.linkCardTint) { [weak self] in self?.presentLinkEditor(card: nil) })

        let title = L10n.isRussian ? "Добавить заметку" : "Add note"
        AddNoteMenuSheet.show(title: title, actions: actions, from: self, sourceView: addButton)
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
        guard let foundItem = flatCards.firstIndex(where: { $0.id == card.id }) else {
            CardStore.shared.delete(card: card)
            allCards = CardStore.shared.cards(for: currentDate)
            applyFilters()
            return
        }

        CardStore.shared.delete(card: card)
        allCards = CardStore.shared.cards(for: currentDate)
        flatCards.remove(at: foundItem)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let wasEmpty = flatCards.isEmpty
        collectionView.performBatchUpdates {
            self.collectionView.deleteItems(at: [IndexPath(item: foundItem, section: 0)])
        } completion: { _ in
            if wasEmpty {
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

extension TodayViewController: UISearchBarDelegate {
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

extension TodayViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        flatCards.isEmpty ? 1 : flatCards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if flatCards.isEmpty {
            return collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as! EmptyCardCell
        }
        let card = flatCards[indexPath.item]
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
}

// MARK: - UICollectionViewDelegate

extension TodayViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !flatCards.isEmpty else { return }
        let card = flatCards[indexPath.item]
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
        guard !flatCards.isEmpty, !isSelectMode else { return nil }

        let card = flatCards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            guard let self else { return nil }

            let select = UIAction(title: "Выбрать", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.enterSelectMode(initialCard: card)
            }
            let share = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareCard(card)
            }
            let copyToDay = UIAction(title: "Скопировать в день", image: UIImage(systemName: "calendar.badge.plus")) { [weak self] _ in
                guard let self else { return }
                let vc = CopyToDayViewController()
                vc.onCopy = { date in
                    CardStore.shared.save(card: card.duplicated(to: date))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            let edit = UIAction(title: L10n.edit, image: UIImage(systemName: "pencil")) { [weak self] _ in
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
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteCard(card)
            }
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

// MARK: - CardTypeSectionHeader (kept for binary compatibility)

final class CardTypeSectionHeader: UICollectionReusableView {

    static let reuseID = "CardTypeSectionHeader"

    private let label    = UILabel()
    private let colorDot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        colorDot.layer.cornerRadius = 3
        colorDot.translatesAutoresizingMaskIntoConstraints = false
        label.font = .inter(ofSize: 11, weight: .semibold)
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
