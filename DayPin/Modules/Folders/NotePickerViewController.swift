import UIKit

// MARK: - NotePickerViewController
// Beautiful card-grid picker for adding existing notes to a folder.
// Presented as a bottom sheet (medium + large detents).

final class NotePickerViewController: UIViewController {

    var onAdd: (([NoteCard]) -> Void)?

    // MARK: - Data

    private let folderID: UUID
    private var sections: [DaySection] = []      // grouped by day (normal mode)
    private var searchResults: [NoteCard] = []   // flat (search mode)
    private var selectedIDs = Set<UUID>()
    private var isSearching: Bool { !searchBar.text.map { $0.isEmpty }.unwrapped(default: true) }

    // MARK: - UI

    private let searchBar = UISearchBar()
    private lazy var collectionView: UICollectionView = makeCollectionView()

    // Bottom action button container (glass blur)
    private let addBtnOuter = UIView()
    private let addBtnBlur  = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let addBtnInner = UIButton(type: .system)
    private var addBtnBottomConstraint: NSLayoutConstraint!

    // Empty state
    private let emptyView    = UIView()
    private let emptyIcon    = UIImageView()
    private let emptyLabel   = UILabel()
    private let emptySubLabel = UILabel()

    // MARK: - Init

    init(folderID: UUID) {
        self.folderID = folderID
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.addNotes
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupSearch()
        setupCollectionView()
        setupAddButton()
        setupEmptyView()
        observeNotifications()
        loadNotes()
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        title = L10n.addNotes
        updateAddButton()
        emptyLabel.text = L10n.noNotesForPicker
        emptySubLabel.text = L10n.noNotesForPickerHint
        collectionView.reloadData()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        addBtnInner.tintColor = DayPinDesign.accent
        refreshAddBtnBorder()
        collectionView.reloadData()
    }

    // MARK: - Setup

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.cancel, style: .plain, target: self, action: #selector(cancelTapped)
        )
    }

    private func setupSearch() {
        searchBar.placeholder    = L10n.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor      = DayPinDesign.accent
        searchBar.backgroundImage = UIImage()
        searchBar.delegate       = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        collectionView.dataSource = self
        collectionView.delegate   = self
    }

    private func setupAddButton() {
        // Shadow wrapper
        addBtnOuter.layer.cornerRadius  = 16
        addBtnOuter.layer.shadowColor   = UIColor.black.cgColor
        addBtnOuter.layer.shadowOpacity = 0.14
        addBtnOuter.layer.shadowRadius  = 14
        addBtnOuter.layer.shadowOffset  = CGSize(width: 0, height: 4)
        addBtnOuter.translatesAutoresizingMaskIntoConstraints = false

        // Blur
        addBtnBlur.layer.cornerRadius = 16
        addBtnBlur.clipsToBounds      = true
        addBtnBlur.layer.borderWidth  = 0.5
        addBtnBlur.translatesAutoresizingMaskIntoConstraints = false
        addBtnOuter.addSubview(addBtnBlur)

        // Tint overlay
        let tint = UIView()
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.10)
                : UIColor(white: 1.0, alpha: 0.65)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        addBtnBlur.contentView.addSubview(tint)

        // Button
        addBtnInner.setTitle(L10n.addNotes, for: .normal)
        addBtnInner.titleLabel?.font = .inter(ofSize: 15, weight: .semibold)
        addBtnInner.tintColor = DayPinDesign.accent
        addBtnInner.translatesAutoresizingMaskIntoConstraints = false
        addBtnInner.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        addBtnBlur.contentView.addSubview(addBtnInner)

        view.addSubview(addBtnOuter)

        addBtnBottomConstraint = addBtnOuter.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 80)

        NSLayoutConstraint.activate([
            addBtnBlur.topAnchor.constraint(equalTo: addBtnOuter.topAnchor),
            addBtnBlur.leadingAnchor.constraint(equalTo: addBtnOuter.leadingAnchor),
            addBtnBlur.trailingAnchor.constraint(equalTo: addBtnOuter.trailingAnchor),
            addBtnBlur.bottomAnchor.constraint(equalTo: addBtnOuter.bottomAnchor),

            tint.topAnchor.constraint(equalTo: addBtnBlur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: addBtnBlur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: addBtnBlur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: addBtnBlur.contentView.bottomAnchor),

            addBtnInner.topAnchor.constraint(equalTo: addBtnBlur.contentView.topAnchor),
            addBtnInner.leadingAnchor.constraint(equalTo: addBtnBlur.contentView.leadingAnchor),
            addBtnInner.trailingAnchor.constraint(equalTo: addBtnBlur.contentView.trailingAnchor),
            addBtnInner.bottomAnchor.constraint(equalTo: addBtnBlur.contentView.bottomAnchor),
            addBtnInner.heightAnchor.constraint(equalToConstant: 52),

            addBtnOuter.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addBtnOuter.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addBtnBottomConstraint
        ])

        refreshAddBtnBorder()
    }

    private func setupEmptyView() {
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true
        view.addSubview(emptyView)

        let cfg = UIImage.SymbolConfiguration(pointSize: 40, weight: .thin)
        emptyIcon.image       = UIImage(systemName: "tray", withConfiguration: cfg)
        emptyIcon.tintColor   = .tertiaryLabel
        emptyIcon.contentMode = .scaleAspectFit
        emptyIcon.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.text          = L10n.noNotesForPicker
        emptyLabel.font          = .inter(ofSize: 16, weight: .medium)
        emptyLabel.textColor     = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        emptySubLabel.text          = L10n.noNotesForPickerHint
        emptySubLabel.font          = .inter(ofSize: 13)
        emptySubLabel.textColor     = .tertiaryLabel
        emptySubLabel.textAlignment = .center
        emptySubLabel.numberOfLines = 2
        emptySubLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [emptyIcon, emptyLabel, emptySubLabel])
        stack.axis      = .vertical
        stack.spacing   = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)

        NSLayoutConstraint.activate([
            emptyView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyIcon.heightAnchor.constraint(equalToConstant: 50),
            stack.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor, constant: -32)
        ])
    }

    private func refreshAddBtnBorder() {
        let dark = traitCollection.userInterfaceStyle == .dark
        addBtnBlur.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.18).cgColor
            : UIColor.black.withAlphaComponent(0.12).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshAddBtnBorder()
        }
    }

    // MARK: - Data

    private func loadNotes() {
        // All notes not already in this folder, grouped by dayDate
        let available = CardStore.shared.allCards().filter { $0.folderID != folderID }
        sections = makeSections(from: available)
        reloadContent()
    }

    private func makeSections(from notes: [NoteCard]) -> [DaySection] {
        let cal = Calendar.current
        var map: [Date: [NoteCard]] = [:]
        for note in notes {
            let day = cal.startOfDay(for: note.dayDate)
            map[day, default: []].append(note)
        }
        return map
            .sorted { $0.key > $1.key }
            .map { date, cards in
                DaySection(
                    date: date,
                    displayTitle: Self.sectionTitle(for: date),
                    cards: cards.sorted { $0.createdAt > $1.createdAt }
                )
            }
    }

    private static func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return L10n.deletedToday }
        if cal.isDateInYesterday(date) { return L10n.yesterday }
        let df = DateFormatter()
        df.locale = L10n.activeLocale
        df.dateFormat = "d MMMM"
        return df.string(from: date).capitalized
    }

    private func reloadContent() {
        let query = searchBar.text ?? ""
        if query.isEmpty {
            let isEmpty = sections.isEmpty
            emptyView.isHidden = !isEmpty
            emptySubLabel.text = isEmpty
                ? L10n.noNotesForPickerHint
                : ""
            collectionView.isHidden = isEmpty
        } else {
            let q = query.lowercased()
            searchResults = sections
                .flatMap { $0.cards }
                .filter { $0.title.lowercased().contains(q) || $0.comment.lowercased().contains(q) }

            let isEmpty = searchResults.isEmpty
            emptyView.isHidden = !isEmpty
            emptySubLabel.text = isEmpty ? L10n.searchNoResults : ""
            emptyLabel.text    = isEmpty ? L10n.searchNoResults : L10n.noNotesForPicker
            collectionView.isHidden = isEmpty
        }
        collectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func confirmTapped() {
        let allCards = sections.flatMap { $0.cards }
        let selected = allCards.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        onAdd?(selected)
        dismiss(animated: true)
    }

    private func updateAddButton() {
        let n = selectedIDs.count
        let title = n > 0 ? L10n.addNotesCount(n) : L10n.addNotes
        addBtnInner.setTitle(title, for: .normal)

        // Animate button in/out based on selection count
        let shouldShow = n > 0
        let targetConstant: CGFloat = shouldShow ? -16 : 80
        guard addBtnBottomConstraint.constant != targetConstant else { return }
        addBtnBottomConstraint.constant = targetConstant
        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.view.layoutIfNeeded()
        }
        // Adjust collection view inset so cards don't hide under the button
        let bottomInset: CGFloat = shouldShow ? 76 : 8
        UIView.animate(withDuration: 0.25) {
            self.collectionView.contentInset.bottom = bottomInset
        }
    }

    // MARK: - Collection view factory

    private func makeCollectionView() -> UICollectionView {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor           = .clear
        cv.alwaysBounceVertical      = true
        cv.keyboardDismissMode       = .onDrag
        cv.showsVerticalScrollIndicator = false
        cv.contentInset              = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        cv.register(TextCardCell.self,  forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,  forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(PickerSectionHeader.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: PickerSectionHeader.reuseID)
        return cv
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else { return nil }

            let itemSize  = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize, subitem: item, count: 2)

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets    = NSDirectionalEdgeInsets(top: 4, leading: 11, bottom: 8, trailing: 11)
            section.interGroupSpacing = 10

            // Section header (day label) — skip in search mode (flat list with 1 section)
            let showHeader = self.searchBar.text?.isEmpty != false
            if showHeader {
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1), heightDimension: .estimated(30))
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top)
                section.boundarySupplementaryItems = [header]
            }
            return section
        }
    }
}

// MARK: - UICollectionViewDataSource

extension NotePickerViewController: UICollectionViewDataSource {

    func numberOfSections(in cv: UICollectionView) -> Int {
        isSearching ? 1 : max(sections.count, 1)
    }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isSearching { return searchResults.count }
        guard section < sections.count else { return 0 }
        return sections[section].cards.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let card = cardAt(indexPath)
        let cell: UICollectionViewCell
        switch card.type {
        case .text:
            guard let c = cv.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as? TextCardCell,
                  let tc = card as? TextCard else { return UICollectionViewCell() }
            c.configure(with: tc); cell = c
        case .image:
            guard let c = cv.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as? ImageCardCell,
                  let ic = card as? ImageCard else { return UICollectionViewCell() }
            c.configure(with: ic); cell = c
        case .link:
            guard let c = cv.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as? LinkCardCell,
                  let lc = card as? LinkCard else { return UICollectionViewCell() }
            c.configure(with: lc); cell = c
        }
        cell.applySelectionOverlay(isSelecting: true, isSelected: selectedIDs.contains(card.id))
        return cell
    }

    func collectionView(
        _ cv: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              !isSearching,
              indexPath.section < sections.count,
              let header = cv.dequeueReusableSupplementaryView(
                  ofKind: kind,
                  withReuseIdentifier: PickerSectionHeader.reuseID,
                  for: indexPath) as? PickerSectionHeader
        else { return UICollectionReusableView() }
        header.configure(title: sections[indexPath.section].displayTitle)
        return header
    }

    private func cardAt(_ indexPath: IndexPath) -> NoteCard {
        isSearching
            ? searchResults[indexPath.item]
            : sections[indexPath.section].cards[indexPath.item]
    }
}

// MARK: - UICollectionViewDelegate

extension NotePickerViewController: UICollectionViewDelegate {

    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let card = cardAt(indexPath)
        if selectedIDs.contains(card.id) {
            selectedIDs.remove(card.id)
        } else {
            selectedIDs.insert(card.id)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateAddButton()
        cv.reloadItems(at: [indexPath])
    }
}

// MARK: - UISearchBarDelegate

extension NotePickerViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        reloadContent()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - DaySection

private struct DaySection {
    let date: Date
    let displayTitle: String
    var cards: [NoteCard]
}

// MARK: - PickerSectionHeader

private final class PickerSectionHeader: UICollectionReusableView {

    static let reuseID = "PickerSectionHeader"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font      = .inter(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String) { label.text = title.uppercased() }
}

// MARK: - Optional unwrapping helper

private extension Optional where Wrapped == Bool {
    func unwrapped(default value: Bool) -> Bool { self ?? value }
}
