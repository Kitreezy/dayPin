import UIKit
import SafariServices

final class TasksViewController: UIViewController {

    private lazy var collectionView: UICollectionView = {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 20, trailing: 16)
        section.interGroupSpacing = 10

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(40))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]

        let layout = UICollectionViewCompositionalLayout { _, _ in section }

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self, forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self, forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(TasksSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TasksSectionHeader.reuseID)
        return cv
    }()

    private var sections: [(date: Date, cards: [NoteCard])] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAll()
    }

    private func loadAll() {
        let all = CardStore.shared.allCards()
        let grouped = Dictionary(grouping: all) { Calendar.current.startOfDay(for: $0.dayDate) }
        sections = grouped.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
        collectionView.reloadData()
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
            ofKind: kind,
            withReuseIdentifier: TasksSectionHeader.reuseID,
            for: indexPath
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
            if let link = card as? LinkCard {
                let safari = SFSafariViewController(url: link.url)
                safari.preferredControlTintColor = .systemBlue
                present(safari, animated: true)
            }
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
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                CardStore.shared.delete(card: card)
                self?.loadAll()
            }
            return UIMenu(children: [share, delete])
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
