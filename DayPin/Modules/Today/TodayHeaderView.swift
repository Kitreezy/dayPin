import UIKit

final class TodayHeaderView: UICollectionReusableView {

    static let reuseID = "TodayHeaderView"

    private let dateLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let stack = UIStackView(arrangedSubviews: [dateLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        dateLabel.font = .systemFont(ofSize: 26, weight: .bold)
        dateLabel.textColor = .label
        dateLabel.adjustsFontSizeToFitWidth = true
        dateLabel.minimumScaleFactor = 0.8

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
    }

    func configure(date: Date) {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d MMMM"
        df.locale = Locale.current
        dateLabel.text = df.string(from: date).capitalized

        let isToday = Calendar.current.isDateInToday(date)
        let isYesterday = Calendar.current.isDateInYesterday(date)
        if isToday {
            subtitleLabel.text = L10n.today
        } else if isYesterday {
            subtitleLabel.text = L10n.yesterday
        } else {
            subtitleLabel.text = ""
        }
    }
}
