import UIKit

// MARK: - Result Model

struct SearchResult {
    let card: NoteCard
    let matchedTitle: Bool       // true = title match, false = comment match
    let snippet: String          // short excerpt to show
    let date: Date
}

// MARK: - GlobalSearchViewController

final class GlobalSearchViewController: UIViewController {

    var onOpen: ((NoteCard) -> Void)?

    private var allCards: [NoteCard] = []
    private var results:  [SearchResult] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        setupTable()
        setupEmpty()
        reload(query: "")
    }

    // MARK: - Public

    func reload(query: String) {
        allCards = CardStore.shared.allCards()
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()

        if q.isEmpty {
            results = []
        } else {
            results = allCards.compactMap { card -> SearchResult? in
                let titleMatch = card.title.lowercased().contains(q)
                let commentMatch = card.comment.lowercased().contains(q)
                guard titleMatch || commentMatch else { return nil }

                let snippet: String
                if commentMatch, !card.comment.isEmpty {
                    snippet = excerptAround(q, in: card.comment, window: 60)
                } else {
                    snippet = ""
                }
                return SearchResult(card: card, matchedTitle: titleMatch,
                                    snippet: snippet, date: card.dayDate)
            }
        }

        tableView.reloadData()
        emptyLabel.isHidden = !results.isEmpty || q.isEmpty
    }

    // MARK: - Setup

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.keyboardDismissMode = .onDrag
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseID)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmpty() {
        emptyLabel.text = "Ничего не найдено"
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Helpers

    private func excerptAround(_ query: String, in text: String, window: Int) -> String {
        let lower = text.lowercased()
        guard let range = lower.range(of: query) else { return String(text.prefix(window)) }
        let idx = text.distance(from: text.startIndex, to: range.lowerBound)
        let start = max(0, idx - window / 3)
        let si = text.index(text.startIndex, offsetBy: start)
        let ei = text.index(si, offsetBy: min(window, text.count - start))
        var excerpt = String(text[si..<ei])
        if start > 0 { excerpt = "…" + excerpt }
        if ei < text.endIndex { excerpt += "…" }
        return excerpt
    }
}

// MARK: - UITableViewDataSource + Delegate

extension GlobalSearchViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseID, for: indexPath) as! SearchResultCell
        cell.configure(with: results[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onOpen?(results[indexPath.row].card)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

// MARK: - SearchResultCell

private final class SearchResultCell: UITableViewCell {

    static let reuseID = "SearchResultCell"

    private let typeIcon    = UIImageView()
    private let titleLabel  = UILabel()
    private let snippetLabel = UILabel()
    private let dateLabel   = UILabel()
    private let pill        = UIView()
    private let pillLabel   = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        let iconWrapper = UIView()
        iconWrapper.layer.cornerRadius = 10
        iconWrapper.translatesAutoresizingMaskIntoConstraints = false

        typeIcon.contentMode = .scaleAspectFit
        typeIcon.translatesAutoresizingMaskIntoConstraints = false
        iconWrapper.addSubview(typeIcon)

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        snippetLabel.font = .systemFont(ofSize: 13)
        snippetLabel.textColor = .secondaryLabel
        snippetLabel.numberOfLines = 2
        snippetLabel.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        pill.layer.cornerRadius = 8
        pill.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.font = .systemFont(ofSize: 10, weight: .medium)
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(pillLabel)

        contentView.addSubview(iconWrapper)
        contentView.addSubview(titleLabel)
        contentView.addSubview(snippetLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(pill)

        NSLayoutConstraint.activate([
            iconWrapper.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconWrapper.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            iconWrapper.widthAnchor.constraint(equalToConstant: 30),
            iconWrapper.heightAnchor.constraint(equalToConstant: 30),

            typeIcon.centerXAnchor.constraint(equalTo: iconWrapper.centerXAnchor),
            typeIcon.centerYAnchor.constraint(equalTo: iconWrapper.centerYAnchor),
            typeIcon.widthAnchor.constraint(equalToConstant: 16),
            typeIcon.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconWrapper.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -8),

            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dateLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            snippetLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            snippetLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            snippetLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            pill.topAnchor.constraint(equalTo: snippetLabel.bottomAnchor, constant: 6),
            pill.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pill.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            pill.heightAnchor.constraint(equalToConstant: 18),

            pillLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 2),
            pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -8),
            pillLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -2)
        ])

        accessoryType = .disclosureIndicator
    }

    func configure(with result: SearchResult) {
        titleLabel.text = result.card.title
        snippetLabel.text = result.snippet
        snippetLabel.isHidden = result.snippet.isEmpty

        let df = DateFormatter()
        df.dateFormat = "d MMM"
        df.locale = Locale.current
        dateLabel.text = df.string(from: result.date)

        switch result.card.type {
        case .text:
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            typeIcon.image = UIImage(systemName: "text.alignleft", withConfiguration: cfg)
            typeIcon.tintColor = DayPinDesign.textCardTint
            (typeIcon.superview as? UIView)?.backgroundColor = DayPinDesign.textCardTint.withAlphaComponent(0.12)
            pillLabel.text = "Заметка"
            pill.backgroundColor = DayPinDesign.textCardTint.withAlphaComponent(0.12)
            pillLabel.textColor = DayPinDesign.textCardTint
        case .image:
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            typeIcon.image = UIImage(systemName: "photo", withConfiguration: cfg)
            typeIcon.tintColor = DayPinDesign.imageCardTint
            (typeIcon.superview as? UIView)?.backgroundColor = DayPinDesign.imageCardTint.withAlphaComponent(0.12)
            pillLabel.text = "Фото"
            pill.backgroundColor = DayPinDesign.imageCardTint.withAlphaComponent(0.12)
            pillLabel.textColor = DayPinDesign.imageCardTint
        case .link:
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            typeIcon.image = UIImage(systemName: "link", withConfiguration: cfg)
            typeIcon.tintColor = DayPinDesign.linkCardTint
            (typeIcon.superview as? UIView)?.backgroundColor = DayPinDesign.linkCardTint.withAlphaComponent(0.12)
            pillLabel.text = "Ссылка"
            pill.backgroundColor = DayPinDesign.linkCardTint.withAlphaComponent(0.12)
            pillLabel.textColor = DayPinDesign.linkCardTint
        }
    }
}
