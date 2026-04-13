import UIKit

final class CalendarViewController: UIViewController {

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(CalendarDayCell.self, forCellWithReuseIdentifier: CalendarDayCell.reuseID)
        cv.register(MonthSectionHeader.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: MonthSectionHeader.reuseID)
        return cv
    }()

    // MARK: - Data

    private var months: [MonthData] = []
    private let cal = Calendar.current

    // MARK: - Lifecycle

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
        buildMonths()
        scrollToToday(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
    }

    // MARK: - Build months (past 6 + current + next 6)

    private func buildMonths() {
        let today = Date()
        months = (-6...6).compactMap { offset -> MonthData? in
            var comps = cal.dateComponents([.year, .month], from: today)
            comps.month = (comps.month ?? 1) + offset
            comps.day = 1
            guard let first = cal.date(from: comps) else { return nil }
            return MonthData(firstDay: first, calendar: cal)
        }
    }

    private func scrollToToday(animated: Bool) {
        guard let idx = months.firstIndex(where: {
            cal.isDate($0.firstDay, equalTo: Date(), toGranularity: .month)
        }) else { return }
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(
                at: IndexPath(item: 0, section: idx),
                at: .top,
                animated: animated
            )
        }
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        // 7 equally-wide columns, fixed cell height
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / 7.0),
            heightDimension: .absolute(52)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)

        let rowSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(52)
        )
        let row = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: row)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 20, trailing: 12)

        // Single header — includes month title + weekday row
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(72)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]

        return UICollectionViewCompositionalLayout(section: section)
    }
}

// MARK: - UICollectionViewDataSource

extension CalendarViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { months.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        months[section].cells.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.reuseID, for: indexPath) as! CalendarDayCell
        let dayCell = months[indexPath.section].cells[indexPath.item]
        let hasCards = dayCell.date.map { !CardStore.shared.cards(for: $0).isEmpty } ?? false
        cell.configure(with: dayCell, hasCards: hasCards)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: MonthSectionHeader.reuseID,
            for: indexPath
        ) as! MonthSectionHeader
        header.configure(date: months[indexPath.section].firstDay)
        return header
    }
}

// MARK: - UICollectionViewDelegate

extension CalendarViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let day = months[indexPath.section].cells[indexPath.item]
        guard let date = day.date else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let vc = DayDetailViewController(date: date)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - MonthSectionHeader
// Combined header: month title + weekday labels

final class MonthSectionHeader: UICollectionReusableView {

    static let reuseID = "MonthSectionHeader"

    private let monthLabel = UILabel()
    private let weekdayStack = UIStackView()
    private let days: [String] = {
        // Respect locale's first weekday, but show Mon-Sun for simplicity
        let isRu = Locale.preferredLanguages.first?.hasPrefix("ru") == true
        return isRu
            ? ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
            : ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        monthLabel.font = .systemFont(ofSize: 18, weight: .bold)
        monthLabel.textColor = .label
        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(monthLabel)

        weekdayStack.axis = .horizontal
        weekdayStack.distribution = .fillEqually
        weekdayStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(weekdayStack)

        days.enumerated().forEach { i, d in
            let lbl = UILabel()
            lbl.text = d
            lbl.textAlignment = .center
            lbl.font = .systemFont(ofSize: 11, weight: .semibold)
            lbl.textColor = (i >= 5) ? .tertiaryLabel : UIColor.secondaryLabel.withAlphaComponent(0.7)
            weekdayStack.addArrangedSubview(lbl)
        }

        NSLayoutConstraint.activate([
            monthLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            monthLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            monthLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            weekdayStack.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 6),
            weekdayStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            weekdayStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            weekdayStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    func configure(date: Date) {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        df.locale = Locale.current
        monthLabel.text = df.string(from: date).capitalized
    }
}

// MARK: - CalendarDayCell

final class CalendarDayCell: UICollectionViewCell {

    static let reuseID = "CalendarDayCell"

    private let dayLabel = UILabel()
    private let dotView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = 12

        dayLabel.font = .systemFont(ofSize: 15, weight: .regular)
        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        dotView.layer.cornerRadius = 3
        dotView.isHidden = true
        dotView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dotView)

        NSLayoutConstraint.activate([
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -3),

            dotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotView.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 3),
            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    func configure(with data: CalendarCellData, hasCards: Bool) {
        guard let date = data.date else {
            dayLabel.text = nil
            dotView.isHidden = true
            backgroundColor = .clear
            return
        }

        let day = Calendar.current.component(.day, from: date)
        dayLabel.text = "\(day)"

        let isToday = Calendar.current.isDateInToday(date)
        let isWeekend = Calendar.current.isDateInWeekend(date)

        if isToday {
            backgroundColor = .systemBlue
            layer.cornerRadius = 12
            dayLabel.font = .systemFont(ofSize: 15, weight: .bold)
            dayLabel.textColor = .white
            dotView.backgroundColor = .white
        } else {
            backgroundColor = .clear
            dayLabel.font = .systemFont(ofSize: 15, weight: isWeekend ? .regular : .regular)
            dayLabel.textColor = isWeekend ? .tertiaryLabel : .label
            dotView.backgroundColor = .systemBlue
        }

        dotView.isHidden = !hasCards
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.backgroundColor = self.isHighlighted
                    ? UIColor.secondarySystemFill
                    : (Calendar.current.isDateInToday(self.dayDate ?? Date()) ? .systemBlue : .clear)
            }
        }
    }

    private var dayDate: Date?
}

// MARK: - MonthData

struct MonthData {
    let firstDay: Date
    let cells: [CalendarCellData]

    init(firstDay: Date, calendar: Calendar) {
        self.firstDay = firstDay

        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        // Monday-based offset
        let weekday = calendar.component(.weekday, from: firstDay) // 1=Sun...7=Sat
        let offset = (weekday - 2 + 7) % 7 // shift to Mon=0

        var result: [CalendarCellData] = Array(repeating: CalendarCellData(date: nil), count: offset)
        for day in 1...range.count {
            var comps = calendar.dateComponents([.year, .month], from: firstDay)
            comps.day = day
            result.append(CalendarCellData(date: calendar.date(from: comps)))
        }
        while result.count % 7 != 0 { result.append(CalendarCellData(date: nil)) }
        self.cells = result
    }
}

struct CalendarCellData {
    let date: Date?
}
