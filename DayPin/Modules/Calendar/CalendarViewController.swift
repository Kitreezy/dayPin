import UIKit

// MARK: - CalendarViewController
// Redesigned: single-month view with custom month/year picker + inline notes list.

final class CalendarViewController: UIViewController {

    // MARK: - State

    private let cal = Calendar.current
    private var displayedMonth: Date = {
        let c = Calendar.current
        var comps = c.dateComponents([.year, .month], from: Date())
        comps.day = 1
        return c.date(from: comps) ?? Date()
    }()
    private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    private var notesForSelectedDay: [NoteCard] = []

    // MARK: - UI: Top header (pinned)

    private let titleLabel      = UILabel()
    private let todayBtn        = UIButton(type: .system)
    private let monthPickerView = MonthPickerView()

    // MARK: - UI: Collection (calendar grid + notes)

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor    = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(CalendarDayCell.self,   forCellWithReuseIdentifier: CalendarDayCell.reuseID)
        cv.register(TextCardCell.self,      forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self,     forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,      forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(EmptyNotesCell.self,    forCellWithReuseIdentifier: EmptyNotesCell.reuseID)
        cv.register(WeekdayHeaderView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: WeekdayHeaderView.reuseID)
        cv.register(NotesSectionHeader.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: NotesSectionHeader.reuseID)
        return cv
    }()

    // MARK: - Section identifiers
    private let sectionCalendar = 0
    private let sectionNotes    = 1

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        addStandardBackground()
        buildUI()
        reloadNotes()

        NotificationCenter.default.addObserver(self, selector: #selector(onSchemeChanged),
                                               name: .dayPinColorSchemeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSchemeChanged),
                                               name: .dayPinLanguageChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        collectionView.reloadData()
        reloadNotes()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Build UI

    private func buildUI() {
        // Title label
        titleLabel.font          = .inter(ofSize: 34, weight: .bold)
        titleLabel.textColor     = .label
        titleLabel.text          = L10n.isRussian ? "Календарь" : "Calendar"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // "Today" jump button — top-right, aligned with title
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        todayBtn.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: iconCfg), for: .normal)
        todayBtn.setTitle(L10n.isRussian ? "  Сегодня" : "  Today", for: .normal)
        todayBtn.titleLabel?.font     = .inter(ofSize: 13, weight: .semibold)
        todayBtn.tintColor            = DayPinDesign.accent
        todayBtn.setTitleColor(DayPinDesign.accent, for: .normal)
        todayBtn.backgroundColor      = DayPinDesign.accent.withAlphaComponent(0.1)
        todayBtn.layer.cornerRadius   = 10
        todayBtn.layer.borderWidth    = 0.5
        todayBtn.layer.borderColor    = DayPinDesign.accent.withAlphaComponent(0.3).cgColor
        todayBtn.layer.masksToBounds  = true
        todayBtn.contentEdgeInsets    = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 12)
        todayBtn.translatesAutoresizingMaskIntoConstraints = false
        todayBtn.addTarget(self, action: #selector(jumpToToday), for: .touchUpInside)
        view.addSubview(todayBtn)

        // Month picker
        monthPickerView.translatesAutoresizingMaskIntoConstraints = false
        monthPickerView.configure(date: displayedMonth)
        monthPickerView.onPrev = { [weak self] in self?.shiftMonth(by: -1) }
        monthPickerView.onNext = { [weak self] in self?.shiftMonth(by:  1) }
        monthPickerView.onPickerTapped = { [weak self] in self?.showMonthYearPicker() }
        view.addSubview(monthPickerView)

        // Collection
        view.addSubview(collectionView)
        collectionView.dataSource = self
        collectionView.delegate   = self

        // Swipe gestures for month navigation
        let swipeLeft  = UISwipeGestureRecognizer(target: self, action: #selector(swipedLeft))
        swipeLeft.direction  = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipedRight))
        swipeRight.direction = .right
        collectionView.addGestureRecognizer(swipeLeft)
        collectionView.addGestureRecognizer(swipeRight)

        let safeTop = view.safeAreaLayoutGuide.topAnchor
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: safeTop, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            todayBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            todayBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            monthPickerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            monthPickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            monthPickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            monthPickerView.heightAnchor.constraint(equalToConstant: 40),

            collectionView.topAnchor.constraint(equalTo: monthPickerView.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func jumpToToday() {
        let today = cal.startOfDay(for: Date())
        selectedDate = today

        // Navigate to current month if needed
        var comps = cal.dateComponents([.year, .month], from: today)
        comps.day = 1
        if let monthFirst = cal.date(from: comps), !cal.isDate(monthFirst, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = monthFirst
            monthPickerView.configure(date: displayedMonth)
        }

        reloadNotes()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Scroll to top to show calendar
        collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
    }

    // MARK: - Helpers

    private func reloadNotes() {
        notesForSelectedDay = CardStore.shared.cards(for: selectedDate)
        collectionView.reloadData()
    }

    private func shiftMonth(by value: Int) {
        guard let next = cal.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = next
        monthPickerView.configure(date: displayedMonth)

        // Animate calendar section only
        UIView.transition(with: collectionView, duration: 0.22,
                          options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.collectionView.reloadSections(IndexSet(integer: self.sectionCalendar))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func swipedLeft()  { shiftMonth(by:  1) }
    @objc private func swipedRight() { shiftMonth(by: -1) }

    private func showMonthYearPicker() {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        // Restrict to month/year navigation by responding to value changes
        picker.date = displayedMonth

        let alert = UIAlertController(title: L10n.isRussian ? "Выбор месяца" : "Select Month",
                                      message: "\n\n\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        alert.view.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 48),
            picker.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor)
        ])

        alert.addAction(UIAlertAction(title: L10n.done, style: .default) { [weak self] _ in
            guard let self else { return }
            var comps = self.cal.dateComponents([.year, .month], from: picker.date)
            comps.day = 1
            if let first = self.cal.date(from: comps) {
                self.displayedMonth = first
                self.monthPickerView.configure(date: first)
                self.collectionView.reloadSections(IndexSet(integer: self.sectionCalendar))
            }
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    @objc private func onSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        titleLabel.text = L10n.isRussian ? "Календарь" : "Calendar"
        todayBtn.setTitle(L10n.isRussian ? "  Сегодня" : "  Today", for: .normal)
        todayBtn.tintColor          = DayPinDesign.accent
        todayBtn.setTitleColor(DayPinDesign.accent, for: .normal)
        todayBtn.backgroundColor    = DayPinDesign.accent.withAlphaComponent(0.1)
        todayBtn.layer.borderColor  = DayPinDesign.accent.withAlphaComponent(0.3).cgColor
        monthPickerView.configure(date: displayedMonth)
        collectionView.reloadData()
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous) {
            todayBtn.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.3).cgColor
        }
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else { return nil }
            if sectionIndex == self.sectionCalendar {
                return self.calendarSectionLayout()
            } else {
                return self.notesSectionLayout()
            }
        }
    }

    private func calendarSectionLayout() -> NSCollectionLayoutSection {
        // 7-column grid
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / 7.0),
                                              heightDimension: .absolute(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)

        let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                             heightDimension: .absolute(50))
        let row = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: row)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 8, trailing: 10)

        // Weekday labels header
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                heightDimension: .absolute(32))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
        section.boundarySupplementaryItems = [header]
        return section
    }

    private func notesSectionLayout() -> NSCollectionLayoutSection {
        let hasNotes = !notesForSelectedDay.isEmpty
        if hasNotes {
            let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                                   heightDimension: .absolute(160))
            let item      = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                   heightDimension: .absolute(160))
            let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
            let section   = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 11, bottom: 16, trailing: 11)
            section.interGroupSpacing = 10
            section.boundarySupplementaryItems = [notesSectionHeader()]
            return section
        } else {
            // Empty state cell
            let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                   heightDimension: .absolute(80))
            let item      = NSCollectionLayoutItem(layoutSize: itemSize)
            let group     = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section   = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16)
            section.boundarySupplementaryItems = [notesSectionHeader()]
            return section
        }
    }

    private func notesSectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                heightDimension: .absolute(36))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
    }

    // MARK: - Calendar cells builder

    private func calendarCells() -> [CalendarCellData] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let weekday = cal.component(.weekday, from: displayedMonth)
        let offset  = (weekday - 2 + 7) % 7  // Monday = 0

        var result: [CalendarCellData] = Array(repeating: CalendarCellData(date: nil), count: offset)
        for day in 1...range.count {
            var comps = cal.dateComponents([.year, .month], from: displayedMonth)
            comps.day = day
            result.append(CalendarCellData(date: cal.date(from: comps)))
        }
        while result.count % 7 != 0 { result.append(CalendarCellData(date: nil)) }
        return result
    }
}

// MARK: - UICollectionViewDataSource

extension CalendarViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == sectionCalendar {
            return calendarCells().count
        } else {
            return max(1, notesForSelectedDay.count)   // at least 1 for empty cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == sectionCalendar {
            let cells = calendarCells()
            let cell  = collectionView.dequeueReusableCell(withReuseIdentifier: CalendarDayCell.reuseID, for: indexPath) as! CalendarDayCell
            let data  = cells[indexPath.item]
            let hasCards = data.date.map { !CardStore.shared.cards(for: $0).isEmpty } ?? false
            let isSel    = data.date.map { cal.isDate($0, inSameDayAs: selectedDate) } ?? false
            cell.configure(with: data, hasCards: hasCards, isSelected: isSel)
            return cell
        } else {
            if notesForSelectedDay.isEmpty {
                return collectionView.dequeueReusableCell(withReuseIdentifier: EmptyNotesCell.reuseID, for: indexPath)
            }
            let card = notesForSelectedDay[indexPath.item]
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
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if indexPath.section == sectionCalendar {
            let v = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: WeekdayHeaderView.reuseID, for: indexPath) as! WeekdayHeaderView
            v.configure()
            return v
        } else {
            let v = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind, withReuseIdentifier: NotesSectionHeader.reuseID, for: indexPath) as! NotesSectionHeader
            v.configure(date: selectedDate)
            return v
        }
    }
}

// MARK: - UICollectionViewDelegate

extension CalendarViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == sectionCalendar {
            let cells = calendarCells()
            guard let date = cells[indexPath.item].date else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedDate = cal.startOfDay(for: date)
            reloadNotes()
        } else if !notesForSelectedDay.isEmpty {
            let card = notesForSelectedDay[indexPath.item]
            switch card.type {
            case .text:
                navigationController?.pushViewController(CardDetailViewController(card: card as! TextCard), animated: true)
            case .image:
                navigationController?.pushViewController(ImageCardDetailViewController(card: card as! ImageCard), animated: true)
            case .link:
                navigationController?.pushViewController(LinkCardDetailViewController(card: card as! LinkCard), animated: true)
            }
        }
    }
}

// MARK: - MonthPickerView

final class MonthPickerView: UIView {

    var onPrev: (() -> Void)?
    var onNext: (() -> Void)?
    var onPickerTapped: (() -> Void)?

    private let prevBtn   = UIButton(type: .system)
    private let nextBtn   = UIButton(type: .system)
    private let monthBtn  = UIButton(type: .system)   // tappable label

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let arrowCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)

        for btn in [prevBtn, nextBtn] {
            btn.backgroundColor    = UIColor.secondarySystemFill
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth  = 0.5
            btn.layer.borderColor  = UIColor.separator.cgColor
            btn.tintColor          = .secondaryLabel
            btn.translatesAutoresizingMaskIntoConstraints = false
        }
        prevBtn.setImage(UIImage(systemName: "chevron.left",  withConfiguration: arrowCfg), for: .normal)
        nextBtn.setImage(UIImage(systemName: "chevron.right", withConfiguration: arrowCfg), for: .normal)
        prevBtn.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextBtn.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Tappable month/year label
        var cfg = UIButton.Configuration.plain()
        cfg.imagePlacement = .trailing
        cfg.imagePadding   = 4
        let chevron = UIImage(systemName: "chevron.down",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        monthBtn.configuration        = cfg
        monthBtn.setImage(chevron, for: .normal)
        monthBtn.tintColor            = .secondaryLabel
        monthBtn.titleLabel?.font     = .inter(ofSize: 15, weight: .semibold)
        monthBtn.setTitleColor(.label, for: .normal)
        monthBtn.addTarget(self, action: #selector(pickerTapped), for: .touchUpInside)
        monthBtn.translatesAutoresizingMaskIntoConstraints = false

        addSubview(prevBtn)
        addSubview(nextBtn)
        addSubview(monthBtn)

        NSLayoutConstraint.activate([
            prevBtn.leadingAnchor.constraint(equalTo: leadingAnchor),
            prevBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            prevBtn.widthAnchor.constraint(equalToConstant: 34),
            prevBtn.heightAnchor.constraint(equalToConstant: 30),

            nextBtn.trailingAnchor.constraint(equalTo: trailingAnchor),
            nextBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextBtn.widthAnchor.constraint(equalToConstant: 34),
            nextBtn.heightAnchor.constraint(equalToConstant: 30),

            monthBtn.centerXAnchor.constraint(equalTo: centerXAnchor),
            monthBtn.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(date: Date) {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        df.locale = L10n.activeLocale
        let title = df.string(from: date).capitalized
        monthBtn.setTitle(title, for: .normal)
    }

    @objc private func prevTapped()   { onPrev?() }
    @objc private func nextTapped()   { onNext?() }
    @objc private func pickerTapped() { onPickerTapped?() }
}

// MARK: - WeekdayHeaderView

final class WeekdayHeaderView: UICollectionReusableView {

    static let reuseID = "WeekdayHeaderView"

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        stack.axis         = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        for i in 0..<7 {
            let lbl = UILabel()
            lbl.textAlignment = .center
            lbl.font          = .inter(ofSize: 11, weight: .semibold)
            lbl.textColor     = (i >= 5) ? UIColor.systemRed.withAlphaComponent(0.7) : .secondaryLabel
            stack.addArrangedSubview(lbl)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure() {
        let days: [String] = L10n.isRussian
            ? ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
            : ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        zip(stack.arrangedSubviews, days).forEach { ($0 as? UILabel)?.text = $1 }
    }
}

// MARK: - NotesSectionHeader

final class NotesSectionHeader: UICollectionReusableView {

    static let reuseID = "NotesSectionHeader"

    private let label = UILabel()
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font      = .inter(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        separator.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(separator)
        addSubview(label)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(date: Date) {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let df  = DateFormatter()
        df.dateFormat = "MMMM"
        df.locale = L10n.activeLocale
        let month = df.string(from: date).uppercased()
        let notes = L10n.isRussian ? "ЗАМЕТКИ" : "NOTES"
        label.text = "\(notes) • \(day) \(month)"
    }
}

// MARK: - CalendarDayCell (updated)

final class CalendarDayCell: UICollectionViewCell {

    static let reuseID = "CalendarDayCell"

    private let selectionRect = UIView()
    private let dayLabel      = UILabel()
    private let dotView       = UIView()
    private var cellDate: Date?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionRect.layer.cornerRadius       = 10
        selectionRect.isUserInteractionEnabled = false
        selectionRect.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(selectionRect)

        dayLabel.textAlignment = .center
        dayLabel.font          = .inter(ofSize: 15, weight: .regular)
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        dotView.layer.cornerRadius = 2.5
        dotView.isHidden           = true
        dotView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dotView)

        NSLayoutConstraint.activate([
            selectionRect.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            selectionRect.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -3),
            selectionRect.widthAnchor.constraint(equalToConstant: 34),
            selectionRect.heightAnchor.constraint(equalToConstant: 34),

            dayLabel.centerXAnchor.constraint(equalTo: selectionRect.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: selectionRect.centerYAnchor),

            dotView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dotView.topAnchor.constraint(equalTo: selectionRect.bottomAnchor, constant: 3),
            dotView.widthAnchor.constraint(equalToConstant: 5),
            dotView.heightAnchor.constraint(equalToConstant: 5)
        ])
    }

    func configure(with data: CalendarCellData, hasCards: Bool, isSelected: Bool) {
        guard let date = data.date else {
            dayLabel.text = nil
            dotView.isHidden = true
            selectionRect.backgroundColor = .clear
            selectionRect.layer.borderWidth = 0
            return
        }
        cellDate = date
        let day       = Calendar.current.component(.day, from: date)
        let isToday   = Calendar.current.isDateInToday(date)
        let isWeekend = Calendar.current.isDateInWeekend(date)

        dayLabel.text = "\(day)"

        if isSelected {
            selectionRect.backgroundColor   = DayPinDesign.accent
            selectionRect.layer.borderWidth = 0
            dayLabel.font       = .inter(ofSize: 15, weight: .bold)
            dayLabel.textColor  = .white
            dotView.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        } else if isToday {
            selectionRect.backgroundColor   = .clear
            selectionRect.layer.borderWidth = 1.5
            selectionRect.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.6).cgColor
            dayLabel.font       = .inter(ofSize: 15, weight: .bold)
            dayLabel.textColor  = DayPinDesign.accent
            dotView.backgroundColor = DayPinDesign.accent
        } else {
            selectionRect.backgroundColor   = .clear
            selectionRect.layer.borderWidth = 0
            dayLabel.font       = .inter(ofSize: 15, weight: .regular)
            dayLabel.textColor  = isWeekend ? UIColor.systemRed.withAlphaComponent(0.65) : .label
            dotView.backgroundColor = DayPinDesign.accent
        }
        dotView.isHidden = !hasCards
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) { self.alpha = self.isHighlighted ? 0.55 : 1 }
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous),
           selectionRect.layer.borderWidth > 0 {
            selectionRect.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.6).cgColor
        }
    }
}

// MARK: - EmptyNotesCell

final class EmptyNotesCell: UICollectionViewCell {

    static let reuseID = "EmptyNotesCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        let label = UILabel()
        label.font          = .inter(ofSize: 14, weight: .regular)
        label.textColor     = .tertiaryLabel
        label.text          = L10n.isRussian ? "Нет заметок за этот день" : "No notes for this day"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Data Models

struct MonthData {
    let firstDay: Date
    let cells: [CalendarCellData]

    init(firstDay: Date, calendar: Calendar) {
        self.firstDay = firstDay
        let range = calendar.range(of: .day, in: .month, for: firstDay)!
        let weekday = calendar.component(.weekday, from: firstDay)
        let offset  = (weekday - 2 + 7) % 7

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
