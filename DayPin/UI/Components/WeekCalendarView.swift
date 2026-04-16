import UIKit

/// Horizontal 7-day strip that can follow any selected date.
/// Tapping a day calls `onDaySelected(_:)`.
final class WeekCalendarView: UIView {

    var onDaySelected: ((Date) -> Void)?

    private let calendar = Calendar.current
    private var selectedDate: Date
    private var centerDate: Date       // middle day of the strip
    private var dayButtons: [DayButton] = []
    private let stack = UIStackView()

    // MARK: - Init

    init(selectedDate: Date = Calendar.current.startOfDay(for: Date())) {
        self.selectedDate  = Calendar.current.startOfDay(for: selectedDate)
        self.centerDate    = Calendar.current.startOfDay(for: selectedDate)
        super.init(frame: .zero)
        buildStrip()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildStrip() {
        dayButtons.forEach { $0.removeFromSuperview() }
        dayButtons.removeAll()
        stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        if stack.superview == nil {
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        let days: [Date] = (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: centerDate) }

        for date in days {
            let btn = DayButton(
                date: date,
                isToday: calendar.isDateInToday(date),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
            )
            btn.addTarget(self, action: #selector(dayTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
            dayButtons.append(btn)
        }
    }

    // MARK: - Public

    /// Navigate to a date — rebuilds strip if date is outside current window, else just updates selection.
    func navigate(to date: Date) {
        let newDate = calendar.startOfDay(for: date)
        selectedDate = newDate

        let inWindow = dayButtons.contains { calendar.isDate($0.date, inSameDayAs: newDate) }
        if !inWindow {
            centerDate = newDate
            buildStrip()
        } else {
            dayButtons.forEach { $0.setSelected(calendar.isDate($0.date, inSameDayAs: newDate)) }
        }
    }

    // MARK: - Actions

    @objc private func dayTapped(_ sender: DayButton) {
        navigate(to: sender.date)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDaySelected?(sender.date)
    }
}

// MARK: - DayButton

private final class DayButton: UIButton {

    let date: Date
    private let dayLabel  = UILabel()
    private let numLabel  = UILabel()
    private let circle    = UIView()
    private let isToday:  Bool

    init(date: Date, isToday: Bool, isSelected: Bool) {
        self.date    = date
        self.isToday = isToday
        super.init(frame: .zero)
        setup()
        setSelected(isSelected)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let dfLetter = DateFormatter()
        dfLetter.dateFormat = "EEEEEE"   // 2-letter abbreviation: пн/вт/ср or Mo/Tu/We
        dfLetter.locale = Locale.current
        dayLabel.text      = dfLetter.string(from: date).uppercased()
        dayLabel.font      = .systemFont(ofSize: 10, weight: .medium)
        dayLabel.textColor = .secondaryLabel
        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false

        let dfNum = DateFormatter()
        dfNum.dateFormat = "d"
        numLabel.text          = dfNum.string(from: date)
        numLabel.textAlignment = .center
        numLabel.translatesAutoresizingMaskIntoConstraints = false

        circle.layer.cornerRadius      = 14
        circle.isUserInteractionEnabled = false
        circle.translatesAutoresizingMaskIntoConstraints = false

        addSubview(circle)
        addSubview(dayLabel)
        addSubview(numLabel)

        NSLayoutConstraint.activate([
            dayLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            dayLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            dayLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            circle.centerXAnchor.constraint(equalTo: centerXAnchor),
            circle.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 4),
            circle.widthAnchor.constraint(equalToConstant: 28),
            circle.heightAnchor.constraint(equalToConstant: 28),
            circle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            numLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            numLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])

        if isToday {
            circle.layer.borderWidth = 1.5
            circle.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.45).cgColor
        }
    }

    func setSelected(_ selected: Bool) {
        if selected {
            circle.backgroundColor  = DayPinDesign.accent
            circle.layer.borderWidth = 0
            numLabel.textColor = .white
            numLabel.font      = .systemFont(ofSize: 15, weight: .semibold)
        } else {
            circle.backgroundColor  = .clear
            circle.layer.borderWidth = isToday ? 1.5 : 0
            circle.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.45).cgColor
            numLabel.textColor = isToday ? DayPinDesign.accent : .label
            numLabel.font      = .systemFont(ofSize: 15, weight: isToday ? .bold : .regular)
        }
    }

    override var isHighlighted: Bool {
        didSet { UIView.animate(withDuration: 0.1) { self.alpha = self.isHighlighted ? 0.5 : 1 } }
    }
}
