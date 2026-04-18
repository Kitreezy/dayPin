import UIKit

final class TasksViewController: UIViewController {

    // MARK: - Layout

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self, sectionIndex < self.sections.count else {
                // Fallback
                let size  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                let item  = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }

            let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item      = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets   = NSDirectionalEdgeInsets(top: 6, leading: 11, bottom: 16, trailing: 11)
            section.interGroupSpacing = 10

            let hdrSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(40))
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
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self,  forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,  forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(TasksSectionHeader.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: TasksSectionHeader.reuseID)
        return cv
    }()

    // MARK: - Data

    private var allSections: [(date: Date, cards: [NoteCard])] = []
    private var sections:    [(date: Date, cards: [NoteCard])] = []
    private var searchQuery: String = ""
    private var activeFilter: FilterChipsView.Filter = .all

    private let searchBar   = UISearchBar()
    private let filterChips = FilterChipsView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background

        let wave = WaveBackgroundView()
        wave.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wave)
        NSLayoutConstraint.activate([
            wave.topAnchor.constraint(equalTo: view.topAnchor),
            wave.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wave.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wave.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45)
        ])

        searchBar.placeholder = L10n.searchPlaceholder
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onFilterChange = { [weak self] filter in
            self?.activeFilter = filter
            self?.applyFilters()
        }

        collectionView.keyboardDismissMode = .onDrag
        view.addSubview(searchBar)
        view.addSubview(filterChips)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            filterChips.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterChips.heightAnchor.constraint(equalToConstant: 38),

            collectionView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        collectionView.dataSource = self
        collectionView.delegate   = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAll()
    }

    @objc private func onSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        collectionView.reloadData()
    }

    // MARK: - Data loading

    private func loadAll() {
        let all     = CardStore.shared.allCards()
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

        sections = result
        collectionView.reloadData()
    }

    // MARK: - Editor helper

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
}

// MARK: - UISearchBarDelegate

extension TasksViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchQuery = searchText
        applyFilters()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""; searchBar.resignFirstResponder()
        searchQuery = ""; applyFilters()
    }
}

// MARK: - DataSource

extension TasksViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let card = sections[indexPath.section].cards[indexPath.item]
        switch card.type {
        case .text:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as! TextCardCell
            cell.configure(with: card as! TextCard); return cell
        case .image:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as! ImageCardCell
            cell.configure(with: card as! ImageCard); return cell
        case .link:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as! LinkCardCell
            cell.configure(with: card as! LinkCard); return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: TasksSectionHeader.reuseID, for: indexPath
        ) as! TasksSectionHeader
        header.configure(date: sections[indexPath.section].date)
        return header
    }
}

// MARK: - Delegate

extension TasksViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let card = sections[indexPath.section].cards[indexPath.item]
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
        let card = sections[indexPath.section].cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { _ in
            let share = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                var items: [Any] = [card.title]
                if !card.comment.isEmpty { items.append(card.comment) }
                if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
                if let link = card as? LinkCard { items.append(link.url) }
                self?.present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
            }
            let edit = UIAction(title: L10n.edit, image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentEditor(for: card)
            }
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                CardStore.shared.delete(card: card)
                self?.loadAll()
            }
            return UIMenu(children: [share, edit, delete])
        })
    }
}

// MARK: - Section Header

final class TasksSectionHeader: UICollectionReusableView {

    static let reuseID = "TasksSectionHeader"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
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
            df.locale = Locale.current
            label.text = df.string(from: date).uppercased()
        }
    }
}
