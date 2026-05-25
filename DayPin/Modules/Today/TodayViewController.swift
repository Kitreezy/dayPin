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
    private var activeTagID: UUID? = nil

    // MARK: - Animation

    /// Tracks which index paths have already been animated so we only animate once per reload.
    private var animatedCardIndexPaths = Set<IndexPath>()

    // MARK: - Multi-select state

    private var isSelectMode = false
    private var selectedIDs = Set<UUID>()

    // MARK: - Undo state

    private var pendingDeleteCard: NoteCard?
    private var undoTimer: Timer?
    private let undoToast = UndoToastView()

    // Set from add-notification userInfo when opened from a folder context.
    // Carried through multi-step flows (camera, photo picker) where it can't be passed directly.
    private var pendingAddFolderID: UUID?

    // MARK: - Search state

    private var isSearchOpen = false
    private var searchQuery = ""

    // MARK: - UI: Header

    private let headerContainer = UIView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let searchBtn = UIButton(type: .system)
    private let moreBtn = UIButton(type: .system)

    // Slides in over the header when search is active
    private let searchContainer = UIView()
    private let searchBar = UISearchBar()

    // MARK: - UI: Content

    private let weekStrip = WeekCalendarView()
    private let filterChips = FilterChipsView()
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
        bar.layer.cornerRadius = 18
        bar.layer.shadowColor = UIColor.black.cgColor
        bar.layer.shadowOpacity = 0.15
        bar.layer.shadowRadius = 12
        bar.layer.shadowOffset = CGSize(width: 0, height: 4)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isHidden = true

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)

        let copyBtn = UIButton(type: .system)
        copyBtn.setImage(UIImage(systemName: "calendar.badge.plus", withConfiguration: iconCfg), for: .normal)
        copyBtn.tintColor = DayPinDesign.accent
        copyBtn.addTarget(self, action: #selector(copySelectedTapped), for: .touchUpInside)

        selectionCountLabel.font = .inter(ofSize: 13, weight: .medium)
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
        NotificationCenter.default.addObserver(self, selector: #selector(onAddText),   name: .dayPinAddText,   object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAddPhoto),  name: .dayPinAddPhoto,  object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAddCamera), name: .dayPinAddCamera, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAddLink),   name: .dayPinAddLink,   object: nil)
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
        rebuildMoreMenu()
        undoToast.refreshAccent()
    }

    @objc private func onLanguageChanged() {
        updateDateLabels()
        searchBar.placeholder = L10n.searchPlaceholder
        rebuildMoreMenu()
        collectionView.reloadData()
        undoToast.refresh()
    }

    private func refreshButtonColors() {
        let accent = DayPinDesign.accent
        searchBtn.tintColor = accent
        searchBtn.backgroundColor = accent.withAlphaComponent(0.12)
        searchBtn.layer.borderColor = accent.withAlphaComponent(0.3).cgColor

        // moreBtn uses neutral surface color from the system so it adapts automatically
        moreBtn.tintColor = .secondaryLabel
        moreBtn.backgroundColor = UIColor.secondarySystemFill
        moreBtn.layer.borderColor = UIColor.separator.cgColor
    }

    // MARK: - Setup

    private func setupUI() {
        addStandardBackground()

        headerContainer.backgroundColor = .clear
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)

        titleLabel.font = .inter(ofSize: 34, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = .inter(ofSize: 13, weight: .regular)
        dateLabel.textColor = .secondaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        updateDateLabels()

        let btnSymbolCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        searchBtn.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: btnSymbolCfg), for: .normal)
        searchBtn.layer.cornerRadius = 17
        searchBtn.layer.borderWidth = 0.5
        searchBtn.translatesAutoresizingMaskIntoConstraints = false
        searchBtn.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)

        moreBtn.setImage(UIImage(systemName: "ellipsis", withConfiguration: btnSymbolCfg), for: .normal)
        moreBtn.layer.cornerRadius = 17
        moreBtn.layer.borderWidth = 0.5
        moreBtn.showsMenuAsPrimaryAction = true
        moreBtn.translatesAutoresizingMaskIntoConstraints = false

        refreshButtonColors()
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

        weekStrip.translatesAutoresizingMaskIntoConstraints = false
        weekStrip.onDaySelected = { [weak self] date in
            guard let self else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            let forward = date > self.currentDate
            self.transitionToDate(date, direction: forward ? 1 : -1)
        }

        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onFilterChange = { [weak self] filter in
            self?.activeFilter = filter
            self?.applyFilters()
        }
        filterChips.onTagFilterChange = { [weak self] tagID in
            self?.activeTagID = tagID
            self?.applyFilters()
        }

        view.addSubview(headerContainer)
        view.addSubview(weekStrip)
        view.addSubview(stripSeparator)
        view.addSubview(filterChips)
        view.addSubview(collectionView)
        view.addSubview(selectionBar)

        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            weekStrip.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 4),
            weekStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            weekStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            weekStrip.heightAnchor.constraint(equalToConstant: 106),

            stripSeparator.topAnchor.constraint(equalTo: weekStrip.bottomAnchor),
            stripSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stripSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stripSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            filterChips.topAnchor.constraint(equalTo: stripSeparator.bottomAnchor, constant: 2),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 2),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            selectionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            selectionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true

        undoToast.translatesAutoresizingMaskIntoConstraints = false
        undoToast.alpha = 0
        undoToast.isUserInteractionEnabled = false
        undoToast.onUndo = { [weak self] in self?.handleUndo() }
        view.addSubview(undoToast)
        NSLayoutConstraint.activate([
            undoToast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            undoToast.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            undoToast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Search overlay setup

    private func setupSearchOverlay() {
        // No background so the field floats directly over the gradient
        searchContainer.backgroundColor = .clear
        searchContainer.clipsToBounds = true
        searchContainer.alpha = 0
        searchContainer.isUserInteractionEnabled = false
        searchContainer.translatesAutoresizingMaskIntoConstraints = false

        searchBar.placeholder = L10n.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = DayPinDesign.accent
        searchBar.setShowsCancelButton(true, animated: false)
        searchBar.delegate = self
        searchBar.backgroundImage = UIImage()
        searchBar.setValue(L10n.cancel, forKey: "cancelButtonText")
        searchBar.searchTextField.font = .inter(ofSize: 16, weight: .regular)
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
            UIAction(title: L10n.selectNotes,
                     image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.selectTapped()
            },
            UIAction(title: L10n.recentlyDeleted,
                     image: UIImage(systemName: "clock.arrow.circlepath")) { [weak self] _ in
                self?.trashTapped()
            },
            UIAction(title: L10n.backup,
                     image: UIImage(systemName: "externaldrive")) { [weak self] _ in
                self?.backupTapped()
            },
            UIAction(title: L10n.appearance,
                     image: UIImage(systemName: "paintbrush")) { [weak self] _ in
                self?.openThemePicker()
            },
            UIAction(title: L10n.background,
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
        searchQuery = ""
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
        dismissUndoToast()

        let outX = CGFloat(direction) * (-view.bounds.width * 0.35)
        let inX = CGFloat(direction) * (view.bounds.width * 0.35)

        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
            self.collectionView.transform = CGAffineTransform(translationX: outX, y: 0)
            self.collectionView.alpha = 0
        } completion: { _ in
            self.currentDate = newDate
            self.weekStrip.navigate(to: newDate)
            self.updateDateLabels()
            self.resetFilters()
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
        animatedCardIndexPaths.removeAll()
        weekStrip.refreshNoteDots()
        applyFilters()
    }

    func resetFilters() {
        activeFilter = .all
        activeTagID = nil
        filterChips.reset()
    }

    private func applyFilters(animated: Bool = false) {
        // Global search across all dates when the search bar is active
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

        let textCards = allCards.filter { $0.type == .text }
        let imageCards = allCards.filter { $0.type == .image }
        let linkCards = allCards.filter { $0.type == .link }

        filterChips.updateCounts(text: textCards.count, image: imageCards.count, link: linkCards.count)

        // Collect all unique tag IDs used by today's cards for the tag chips row
        let usedTagIDs = Array(Set(allCards.flatMap { $0.tagIDs }))
        filterChips.updateTags(usedTagIDs)

        switch activeFilter {
        case .all:   flatCards = allCards
        case .text:  flatCards = textCards
        case .image: flatCards = imageCards
        case .link:  flatCards = linkCards
        }

        // Apply tag filter on top of type filter
        if let tagID = activeTagID {
            flatCards = flatCards.filter { $0.tagIDs.contains(tagID) }
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
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let sec = NSCollectionLayoutSection(group: group)
                sec.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 24, trailing: 16)
                return sec
            }

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

            let sec = NSCollectionLayoutSection(group: group)
            sec.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 11, bottom: 16, trailing: 11)
            sec.interGroupSpacing = 10
            return sec
        }
    }

    // MARK: - Multi-select

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
            // Single persist for all deletions — no N × encode on main thread
            CardStore.shared.deleteMany(cards: toDelete)
            // Optimistic in-memory removal
            let deletedIDs = Set(toDelete.map { $0.id })
            self.allCards.removeAll { deletedIDs.contains($0.id) }
            self.exitSelectMode()
            self.applyFilters(animated: true)
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
            // Single persist for all cards
            CardStore.shared.saveMany(cards: toMove)
            self.exitSelectMode()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        presentFolderPicker(vc)
    }

    // MARK: - Folder picker bottom sheet helper

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
        let vc = BackgroundPickerViewController()
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

    // MARK: - Add actions

    @objc private func addTapped() {
        presentTextEditor(card: nil)
    }

    // userInfo may carry "folderID": UUID when triggered from a folder context
    @objc private func onAddText(_ n: Notification)   {
        presentTextEditor(card: nil, folderID: n.folderID)
    }
    @objc private func onAddPhoto(_ n: Notification)  {
        pendingAddFolderID = n.folderID
        if pendingAddFolderID != nil {
            // In folder context: offer multi-photo picker
            presentMultiPhotoPicker()
        } else {
            presentImagePicker()
        }
    }
    @objc private func onAddCamera(_ n: Notification) {
        pendingAddFolderID = n.folderID
        presentCamera()
    }
    @objc private func onAddLink(_ n: Notification)   {
        presentLinkEditor(card: nil, folderID: n.folderID)
    }

    // MARK: - Editors

    func presentTextEditor(card: TextCard?, folderID: UUID? = nil) {
        let vc = TextCardEditorViewController(card: card, dayDate: currentDate)
        vc.onSave = { [weak self] saved in
            if let fid = folderID { saved.folderID = fid }
            CardStore.shared.save(card: saved)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.loadCards()
            if folderID != nil {
                NotificationCenter.default.post(name: .dayPinFolderNeedsRefresh, object: nil)
            }
        }
        presentEditorSheet(vc)
    }

    func presentLinkEditor(card: LinkCard?, folderID: UUID? = nil) {
        let vc = LinkCardEditorViewController(card: card, dayDate: currentDate)
        vc.onSave = { [weak self] saved in
            if let fid = folderID { saved.folderID = fid }
            CardStore.shared.save(card: saved)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.loadCards()
            if folderID != nil {
                NotificationCenter.default.post(name: .dayPinFolderNeedsRefresh, object: nil)
            }
        }
        presentEditorSheet(vc)
    }

    func presentImagePicker() {
        presentCameraCard(startMode: .gallery)
    }

    func presentCamera() {
        presentCameraCard(startMode: .camera)
    }

    // Multi-photo picker (folder context only)
    private func presentMultiPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0  // unlimited
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCameraCard(startMode: CameraCardViewController.StartMode, existingCard: ImageCard? = nil) {
        let folderID = pendingAddFolderID
        pendingAddFolderID = nil
        let vc = CameraCardViewController(startMode: startMode, dayDate: currentDate, existingCard: existingCard)
        vc.onSave = { [weak self] saved in
            if let fid = folderID { saved.folderID = fid }
            CardStore.shared.save(card: saved)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.loadCards()
            if folderID != nil {
                NotificationCenter.default.post(name: .dayPinFolderNeedsRefresh, object: nil)
            }
        }
        present(vc, animated: true)
    }

    func presentImageEditor(card: ImageCard) {
        let vc = CameraCardViewController(startMode: .gallery, dayDate: currentDate, existingCard: card)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(vc, animated: true)
    }

    /// Immediately updates in-memory state then fires an async persist.
    /// Never re-queries from store so the UI responds in one frame.
    ///
    /// - Parameter cellAlreadyGone: pass `true` when the cell has already been animated
    ///   off-screen by the swipe gesture; suppresses the redundant batch-update animation.
    func deleteCard(_ card: NoteCard, cellAlreadyGone: Bool = false) {
        if pendingDeleteCard != nil {
            undoTimer?.invalidate()
            undoTimer = nil
            pendingDeleteCard = nil
        }

        // Kick off async persist immediately — no UI wait
        CardStore.shared.delete(card: card)

        // Optimistic in-memory removal (instant, no re-query)
        allCards.removeAll { $0.id == card.id }

        guard let foundItem = flatCards.firstIndex(where: { $0.id == card.id }) else {
            // Card was filtered out but still in allCards — just refresh counts and filters
            refreshFilterCounts()
            applyFilters()
            showUndoToast(for: card)
            return
        }

        flatCards.remove(at: foundItem)

        // Update filter chips immediately — counts reflect the removal right now
        refreshFilterCounts()

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if flatCards.isEmpty {
            // Going from N cards to empty: cross-dissolve into the empty state cell
            UIView.transition(with: collectionView, duration: cellAlreadyGone ? 0.0 : 0.25,
                              options: .transitionCrossDissolve) {
                self.collectionView.reloadData()
            }
        } else if cellAlreadyGone {
            // Cell already flew off screen — close the gap instantly, no second animation
            UIView.performWithoutAnimation {
                collectionView.performBatchUpdates {
                    self.collectionView.deleteItems(at: [IndexPath(item: foundItem, section: 0)])
                }
            }
        } else {
            collectionView.performBatchUpdates {
                self.collectionView.deleteItems(at: [IndexPath(item: foundItem, section: 0)])
            }
        }

        showUndoToast(for: card)
    }

    /// Recomputes filter chip counts from the current in-memory `allCards`.
    /// Call after any optimistic removal so chips stay in sync without a full `applyFilters()`.
    private func refreshFilterCounts() {
        let text  = allCards.filter { $0.type == .text  }.count
        let image = allCards.filter { $0.type == .image }.count
        let link  = allCards.filter { $0.type == .link  }.count
        filterChips.updateCounts(text: text, image: image, link: link)
    }

    // MARK: - Undo

    private func showUndoToast(for card: NoteCard) {
        pendingDeleteCard = card
        undoToast.isUserInteractionEnabled = true

        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4) {
            self.undoToast.alpha = 1
            self.undoToast.transform = .identity
        }

        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.dismissUndoToast()
        }
    }

    @objc private func handleUndo() {
        undoTimer?.invalidate()
        undoTimer = nil
        guard let card = pendingDeleteCard else { return }
        pendingDeleteCard = nil
        CardStore.shared.restoreFromTrash(card: card)
        loadCards()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismissUndoToast()
    }

    private func dismissUndoToast() {
        undoTimer?.invalidate()
        undoTimer = nil
        pendingDeleteCard = nil
        undoToast.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.22) {
            self.undoToast.alpha = 0
            self.undoToast.transform = CGAffineTransform(translationX: 0, y: 20)
        } completion: { _ in
            self.undoToast.transform = .identity
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
            guard let empty = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as? EmptyCardCell else {
                return UICollectionViewCell()
            }
            empty.startAnimating()
            return empty
        }
        let card = flatCards[indexPath.item]
        let cell: UICollectionViewCell
        switch card.type {
        case .text:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as? TextCardCell,
                  let textCard = card as? TextCard else { return UICollectionViewCell() }
            c.configure(with: textCard); cell = c
        case .image:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as? ImageCardCell,
                  let imageCard = card as? ImageCard else { return UICollectionViewCell() }
            c.configure(with: imageCard); cell = c
        case .link:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as? LinkCardCell,
                  let linkCard = card as? LinkCard else { return UICollectionViewCell() }
            c.configure(with: linkCard); cell = c
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

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !flatCards.isEmpty, !isSelectMode else { return nil }

        let card = flatCards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            guard let self else { return nil }

            let select = UIAction(title: L10n.selectNote, image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.enterSelectMode(initialCard: card)
            }
            let share = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareCard(card)
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
                switch card.type {
                case .text:  self?.presentTextEditor(card: card as? TextCard)
                case .image: if let c = card as? ImageCard { self?.presentImageEditor(card: c) }
                case .link:  self?.presentLinkEditor(card: card as? LinkCard)
                }
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
                    self?.applyFilters(animated: false)
                }
                self.presentFolderPicker(picker)
            }
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteCard(card)
            }
            return UIMenu(children: [select, share, copyToDay, edit, folderAction, delete])
        })
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard !flatCards.isEmpty, !(cell is EmptyCardCell) else { return }

        // Staggered appearance animation — only on first display after reload
        if !animatedCardIndexPaths.contains(indexPath) {
            animatedCardIndexPaths.insert(indexPath)
            cell.animateCardAppearance(at: indexPath.item)
        }

        cell.gestureRecognizers?
            .filter { $0.name == "cardSwipe" }
            .forEach { cell.removeGestureRecognizer($0) }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCardSwipe(_:)))
        pan.name = "cardSwipe"
        pan.delegate = self
        cell.addGestureRecognizer(pan)
    }
}

// MARK: - Card swipe-to-delete

extension TodayViewController {

    @objc private func handleCardSwipe(_ pan: UIPanGestureRecognizer) {
        guard let cell = pan.view as? UICollectionViewCell else { return }
        guard let indexPath = collectionView.indexPath(for: cell),
              indexPath.item < flatCards.count else {
            if pan.state == .ended || pan.state == .cancelled {
                UIView.animate(withDuration: 0.3) {
                    cell.transform = .identity
                    cell.alpha = 1
                }
            }
            return
        }

        let card = flatCards[indexPath.item]
        let translation = pan.translation(in: cell)

        switch pan.state {
        case .changed:
            let tx = min(0, translation.x)
            cell.transform = CGAffineTransform(translationX: tx, y: 0)
            let progress = abs(tx) / (cell.bounds.width * 0.5)
            cell.alpha = max(0.4, 1.0 - progress * 0.35)

        case .ended:
            let velocity = pan.velocity(in: cell)
            let shouldDelete = translation.x < -(cell.bounds.width * 0.35) || velocity.x < -700
            if shouldDelete {
                UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
                    cell.transform = CGAffineTransform(translationX: -(cell.bounds.width + 20), y: 0)
                    cell.alpha = 0
                } completion: { _ in
                    cell.transform = .identity
                    cell.alpha = 1
                    // cellAlreadyGone=true: skip the redundant batch-update animation
                    self.deleteCard(card, cellAlreadyGone: true)
                }
            } else {
                UIView.animate(withDuration: 0.35, delay: 0,
                               usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
                    cell.transform = .identity
                    cell.alpha = 1
                }
            }

        case .cancelled, .failed:
            UIView.animate(withDuration: 0.3) {
                cell.transform = .identity
                cell.alpha = 1
            }

        default:
            break
        }
    }
}


// MARK: - UIGestureRecognizerDelegate

extension TodayViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              pan.name == "cardSwipe",
              let view = pan.view else { return true }
        let v = pan.velocity(in: view)
        return abs(v.x) > abs(v.y) && v.x < 0
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { false }
}

// MARK: - CardTypeSectionHeader

final class CardTypeSectionHeader: UICollectionReusableView {

    static let reuseID = "CardTypeSectionHeader"

    private let label = UILabel()
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

// MARK: - Drag & Drop (reorder within the same day)

extension TodayViewController: UICollectionViewDragDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        // Only allow drag when not in select mode and there are real cards
        guard !isSelectMode, !flatCards.isEmpty else { return [] }
        let card = flatCards[indexPath.item]
        let provider = NSItemProvider(object: card.id.uuidString as NSString)
        let item = UIDragItem(itemProvider: provider)
        item.localObject = indexPath
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return [item]
    }
}

extension TodayViewController: UICollectionViewDropDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath else { return }

        guard sourceIndexPath != destinationIndexPath else { return }

        collectionView.performBatchUpdates {
            let moved = flatCards.remove(at: sourceIndexPath.item)
            flatCards.insert(moved, at: destinationIndexPath.item)
            collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
        } completion: { [weak self] _ in
            guard let self else { return }
            // Persist new order
            CardStore.shared.updateOrder(cards: self.flatCards)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
    }
}

// MARK: - PHPickerViewControllerDelegate (multi-photo for folder context)

extension TodayViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let folderID = pendingAddFolderID, !results.isEmpty else {
            pendingAddFolderID = nil
            return
        }
        pendingAddFolderID = nil

        // Immediate feedback — user knows processing started
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Notify FolderDetailViewController to show a loading indicator right away
        NotificationCenter.default.post(
            name: .dayPinPhotoImportBegan,
            object: nil,
            userInfo: ["count": results.count]
        )

        // Phase 1: load + compress all images in parallel (background threads — no storage mutation)
        Task.detached(priority: .userInitiated) { [weak self] in
            var imageDatas: [Data] = []

            await withTaskGroup(of: Data?.self) { group in
                for result in results {
                    group.addTask {
                        return await withCheckedContinuation { continuation in
                            result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                                guard let img = obj as? UIImage,
                                      let data = img.compressedForStorage()
                                else { continuation.resume(returning: nil); return }
                                continuation.resume(returning: data)
                            }
                        }
                    }
                }
                for await data in group {
                    if let data { imageDatas.append(data) }
                }
            }

            // Phase 2: batch-save on the main thread — single storage mutation, single persist
            await MainActor.run { [weak self] in
                guard !imageDatas.isEmpty else { return }
                let cards: [NoteCard] = imageDatas.map { data in
                    let card = ImageCard(title: "", dayDate: Date(), imageData: data)
                    card.folderID = folderID
                    return card
                }
                CardStore.shared.saveMany(cards: cards)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self?.loadCards()
                NotificationCenter.default.post(name: .dayPinFolderNeedsRefresh, object: nil)
            }
        }
    }
}

// MARK: - UIImage helpers

private extension UIImage {
    /// Fix orientation then downscale to max 1600px on the long edge before JPEG encoding.
    /// Keeps file size small and makes encoding fast.
    func compressedForStorage(maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        // Fix orientation
        var result = self
        if imageOrientation != .up {
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            draw(in: CGRect(origin: .zero, size: size))
            result = UIGraphicsGetImageFromCurrentImageContext() ?? self
            UIGraphicsEndImageContext()
        }

        // Downscale if needed
        let longest = max(result.size.width, result.size.height)
        if longest > maxDimension {
            let scale = maxDimension / longest
            let newSize = CGSize(width: result.size.width * scale,
                                 height: result.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            result.draw(in: CGRect(origin: .zero, size: newSize))
            result = UIGraphicsGetImageFromCurrentImageContext() ?? result
            UIGraphicsEndImageContext()
        }

        return result.jpegData(compressionQuality: quality)
    }
}
