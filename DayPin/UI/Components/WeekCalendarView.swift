import UIKit

/// Horizontal week strip with arrow navigation and swipe-to-change-day support.
final class WeekCalendarView: UIView {

    var onDaySelected: ((Date) -> Void)?

    private let cal = Calendar.current
    private var selectedDate: Date
    private var weekStart: Date          // always a Monday

    private let prevBtn        = UIButton(type: .system)
    private let nextBtn        = UIButton(type: .system)
    private let weekRangeLabel = UILabel()
    private let dayStack       = UIStackView()
    private var dayButtons: [DayButton] = []

    // Pan state
    private var panBaseDate: Date?

    // MARK: - Init

    init(selectedDate: Date = Calendar.current.startOfDay(for: Date())) {
        self.selectedDate = Calendar.current.startOfDay(for: selectedDate)
        self.weekStart    = Self.mondayOf(Calendar.current.startOfDay(for: selectedDate))
        super.init(frame: .zero)
        buildUI()
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSchemeChanged),
            name: .dayPinLanguageChanged, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildUI() {
        let arrowCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)

        for btn in [prevBtn, nextBtn] {
            // Rounded-rect glass pill — matches the design
            btn.backgroundColor   = UIColor.secondarySystemFill
            btn.layer.cornerRadius = 8
            btn.layer.borderWidth  = 0.5
            btn.layer.borderColor  = UIColor.separator.cgColor
            btn.tintColor          = .secondaryLabel
            btn.translatesAutoresizingMaskIntoConstraints = false
        }
        prevBtn.setImage(UIImage(systemName: "chevron.left",  withConfiguration: arrowCfg), for: .normal)
        nextBtn.setImage(UIImage(systemName: "chevron.right", withConfiguration: arrowCfg), for: .normal)
        prevBtn.addTarget(self, action: #selector(prevWeekTapped), for: .touchUpInside)
        nextBtn.addTarget(self, action: #selector(nextWeekTapped), for: .touchUpInside)

        weekRangeLabel.font          = .inter(ofSize: 12, weight: .semibold)
        weekRangeLabel.textColor     = .secondaryLabel
        weekRangeLabel.textAlignment = .center
        weekRangeLabel.translatesAutoresizingMaskIntoConstraints = false

        dayStack.axis         = .horizontal
        dayStack.distribution = .fillEqually
        dayStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(prevBtn)
        addSubview(nextBtn)
        addSubview(weekRangeLabel)
        addSubview(dayStack)

        NSLayoutConstraint.activate([
            prevBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            prevBtn.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            prevBtn.widthAnchor.constraint(equalToConstant: 34),
            prevBtn.heightAnchor.constraint(equalToConstant: 28),

            nextBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            nextBtn.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            nextBtn.widthAnchor.constraint(equalToConstant: 34),
            nextBtn.heightAnchor.constraint(equalToConstant: 28),

            weekRangeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            weekRangeLabel.centerYAnchor.constraint(equalTo: prevBtn.centerYAnchor),
            weekRangeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: prevBtn.trailingAnchor, constant: 8),
            weekRangeLabel.trailingAnchor.constraint(lessThanOrEqualTo: nextBtn.leadingAnchor, constant: -8),

            dayStack.topAnchor.constraint(equalTo: prevBtn.bottomAnchor, constant: 6),
            dayStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            dayStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            dayStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])

        // Pan gesture on the day area (not arrow buttons)
        let pan      = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        dayStack.addGestureRecognizer(pan)
        dayStack.isUserInteractionEnabled = true

        rebuildDays()
    }

    private func rebuildDays() {
        dayStack.arrangedSubviews.forEach { dayStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        dayButtons.removeAll()

        for i in 0..<7 {
            guard let date = cal.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let hasNotes = !CardStore.shared.cards(for: date).isEmpty
            let btn = DayButton(
                date:       date,
                isToday:    cal.isDateInToday(date),
                isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                hasNotes:   hasNotes
            )
            btn.addTarget(self, action: #selector(dayTapped(_:)), for: .touchUpInside)
            dayStack.addArrangedSubview(btn)
            dayButtons.append(btn)
        }
        updateWeekLabel()
    }

    /// Refreshes note-dot state for all visible day buttons (call after saving/deleting a card).
    func refreshNoteDots() {
        dayButtons.forEach { btn in
            btn.updateNotes(hasNotes: !CardStore.shared.cards(for: btn.date).isEmpty)
        }
    }

    private func updateWeekLabel() {
        guard let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) else { return }
        let startDay  = cal.component(.day, from: weekStart)
        let endDay    = cal.component(.day, from: weekEnd)
        let startMon  = cal.component(.month, from: weekStart)
        let endMon    = cal.component(.month, from: weekEnd)

        let monthFmt = DateFormatter()
        monthFmt.locale = L10n.activeLocale   // matches active language, not just device region
        monthFmt.dateFormat = "MMM"

        if startMon == endMon {
            weekRangeLabel.text = "\(startDay)-\(endDay) \(monthFmt.string(from: weekEnd).uppercased())"
        } else {
            let s = "\(startDay) \(monthFmt.string(from: weekStart).uppercased())"
            let e = "\(endDay) \(monthFmt.string(from: weekEnd).uppercased())"
            weekRangeLabel.text = "\(s) - \(e)"
        }
    }

    // MARK: - Public

    func navigate(to date: Date) {
        let d = cal.startOfDay(for: date)
        selectedDate = d
        if !dayButtons.contains(where: { cal.isDate($0.date, inSameDayAs: d) }) {
            weekStart = Self.mondayOf(d)
            rebuildDays()
        } else {
            dayButtons.forEach { $0.setSelected(cal.isDate($0.date, inSameDayAs: d)) }
        }
    }

    // MARK: - Actions

    @objc private func dayTapped(_ sender: DayButton) {
        selectedDate = sender.date
        dayButtons.forEach { $0.setSelected(cal.isDate($0.date, inSameDayAs: sender.date)) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDaySelected?(sender.date)
    }

    @objc private func prevWeekTapped() {
        guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { return }
        weekStart = prev
        rebuildDays()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func nextWeekTapped() {
        guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return }
        weekStart = next
        rebuildDays()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Pan gesture

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            panBaseDate = selectedDate   // kept for possible future use

        case .changed:
            let dayW = dayStack.bounds.width / 7
            guard dayW > 0 else { return }
            // Map finger X position directly to day index — no discrete jump thresholds
            let x   = max(0, pan.location(in: dayStack).x)
            let idx = min(6, Int(x / dayW))
            guard let targetDate = cal.date(byAdding: .day, value: idx, to: weekStart) else { return }
            let target = cal.startOfDay(for: targetDate)
            guard !cal.isDate(target, inSameDayAs: selectedDate) else { return }
            selectedDate = target
            dayButtons.forEach { $0.setSelected(cal.isDate($0.date, inSameDayAs: target)) }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

        case .ended, .cancelled:
            onDaySelected?(selectedDate)
            panBaseDate = nil
        default:
            break
        }
    }

    // MARK: - Scheme change

    @objc private func onSchemeChanged() { rebuildDays() }

    // MARK: - Helpers

    private static func mondayOf(_ date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}

// MARK: - UIGestureRecognizerDelegate

extension WeekCalendarView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard let pan = gr as? UIPanGestureRecognizer else { return true }
        let v = pan.velocity(in: self)
        return abs(v.x) > abs(v.y) * 1.5
    }
}

// MARK: - DayButton (private)

private final class DayButton: UIButton {

    let date: Date

    // Rounded-rect highlight box — cornerRadius matches the arrow buttons
    private let selectionRect = UIView()
    private let dayLabel      = UILabel()
    private let numLabel      = UILabel()
    // Small dot shown when the day has at least one note
    private let noteDot       = UIView()

    private let isToday:  Bool
    private var hasNotes: Bool

    init(date: Date, isToday: Bool, isSelected: Bool, hasNotes: Bool) {
        self.date     = date
        self.isToday  = isToday
        self.hasNotes = hasNotes
        super.init(frame: .zero)
        setup()
        setSelected(isSelected)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setup() {
        let dfLetter        = DateFormatter()
        dfLetter.dateFormat = "EEEEEE"
        dfLetter.locale     = L10n.activeLocale
        dayLabel.text       = dfLetter.string(from: date).uppercased()
        dayLabel.font       = .inter(ofSize: 10, weight: .medium)
        dayLabel.textColor  = .secondaryLabel
        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false

        let dfNum     = DateFormatter()
        dfNum.dateFormat = "d"
        numLabel.text = dfNum.string(from: date)
        numLabel.textAlignment = .center
        numLabel.translatesAutoresizingMaskIntoConstraints = false

        // Rounded rectangle — consistent with arrow button style (cornerRadius 10)
        selectionRect.layer.cornerRadius       = 10
        selectionRect.isUserInteractionEnabled = false
        selectionRect.translatesAutoresizingMaskIntoConstraints = false

        // Note dot — visible if the day has cards
        noteDot.layer.cornerRadius = 2.5
        noteDot.isHidden           = !hasNotes
        noteDot.translatesAutoresizingMaskIntoConstraints = false

        addSubview(selectionRect)
        addSubview(dayLabel)
        addSubview(numLabel)
        addSubview(noteDot)

        NSLayoutConstraint.activate([
            dayLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            dayLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            dayLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            selectionRect.centerXAnchor.constraint(equalTo: centerXAnchor),
            selectionRect.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 3),
            selectionRect.widthAnchor.constraint(equalToConstant: 32),
            selectionRect.heightAnchor.constraint(equalToConstant: 32),

            numLabel.centerXAnchor.constraint(equalTo: selectionRect.centerXAnchor),
            numLabel.centerYAnchor.constraint(equalTo: selectionRect.centerYAnchor),

            noteDot.centerXAnchor.constraint(equalTo: centerXAnchor),
            noteDot.topAnchor.constraint(equalTo: selectionRect.bottomAnchor, constant: 4),
            noteDot.widthAnchor.constraint(equalToConstant: 5),
            noteDot.heightAnchor.constraint(equalToConstant: 5),
            noteDot.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -2)
        ])

        if isToday {
            selectionRect.layer.borderWidth = 1.5
            selectionRect.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.5).cgColor
        }
    }

    // MARK: State

    func setSelected(_ selected: Bool) {
        if selected {
            selectionRect.backgroundColor   = DayPinDesign.accent
            selectionRect.layer.borderWidth = 0
            numLabel.textColor  = UIColor(dynamicProvider: { _ in UIColor.white })
            numLabel.font       = .inter(ofSize: 15, weight: .bold)
            noteDot.backgroundColor = UIColor(dynamicProvider: { _ in UIColor.white }).withAlphaComponent(0.8)
        } else {
            selectionRect.backgroundColor   = .clear
            selectionRect.layer.borderWidth = isToday ? 1.5 : 0
            selectionRect.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.5).cgColor
            numLabel.textColor  = isToday ? DayPinDesign.accent : .label
            numLabel.font       = .inter(ofSize: 15, weight: isToday ? .bold : .regular)
            noteDot.backgroundColor = DayPinDesign.accent
        }
    }

    func updateNotes(hasNotes: Bool) {
        self.hasNotes    = hasNotes
        noteDot.isHidden = !hasNotes
    }

    override var isHighlighted: Bool {
        didSet { UIView.animate(withDuration: 0.1) { self.alpha = self.isHighlighted ? 0.5 : 1 } }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous),
           selectionRect.layer.borderWidth > 0 {
            selectionRect.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.5).cgColor
        }
    }
}
