import UIKit

final class RecentlyDeletedViewController: UIViewController {

    var onRestored: (() -> Void)?

    private var items: [(card: NoteCard, deletedAt: Date)] = []

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(RecentlyDeletedCell.self, forCellReuseIdentifier: RecentlyDeletedCell.reuseID)
        return tv
    }()

    private lazy var emptyLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = L10n.noDeletedNotes
        lbl.font = .inter(ofSize: 16, weight: .medium)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.isHidden = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.recentlyDeleted
        view.backgroundColor = DayPinDesign.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.close, style: .plain, target: self, action: #selector(close)
        )
        let clearBtn = UIBarButtonItem(
            title: L10n.clearAll, style: .plain, target: self, action: #selector(emptyTrashTapped)
        )
        clearBtn.tintColor = .systemRed
        navigationItem.rightBarButtonItem = clearBtn

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadItems()
        observeNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        title = L10n.recentlyDeleted
        navigationItem.leftBarButtonItem?.title = L10n.close
        navigationItem.rightBarButtonItem?.title = L10n.clearAll
        emptyLabel.text = L10n.noDeletedNotes
        tableView.reloadData()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
    }

    // MARK: - Data

    private func loadItems() {
        let deleted = CardStore.shared.recentlyDeleted()
        items = deleted.compactMap { card -> (NoteCard, Date)? in
            guard let d = CardStore.shared.deletedAt(for: card.id) else { return nil }
            return (card, d)
        }
        tableView.reloadData()
        emptyLabel.isHidden = !items.isEmpty
        tableView.isHidden = items.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !items.isEmpty
    }

    // MARK: - Actions

    @objc private func close() { dismiss(animated: true) }

    @objc private func emptyTrashTapped() {
        let alert = UIAlertController(
            title: L10n.emptyTrashTitle,
            message: L10n.emptyTrashMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.emptyTrashConfirm, style: .destructive) { [weak self] _ in
            CardStore.shared.emptyTrash()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.loadItems()
        })
        present(alert, animated: true)
    }

    private func restore(_ card: NoteCard, at indexPath: IndexPath) {
        CardStore.shared.restoreFromTrash(card: card)
        items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        if items.isEmpty {
            emptyLabel.isHidden = false
            tableView.isHidden = true
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        onRestored?()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func permanentlyDelete(_ card: NoteCard, at indexPath: IndexPath) {
        CardStore.shared.permanentlyDelete(card: card)
        items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        if items.isEmpty {
            emptyLabel.isHidden = false
            tableView.isHidden = true
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - UITableViewDataSource + Delegate

extension RecentlyDeletedViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tv.dequeueReusableCell(withIdentifier: RecentlyDeletedCell.reuseID, for: indexPath) as? RecentlyDeletedCell else {
            return UITableViewCell()
        }
        let item = items[indexPath.row]
        cell.configure(card: item.card, deletedAt: item.deletedAt)
        return cell
    }

    func tableView(_ tv: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 72 }

    func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        items.isEmpty ? nil : L10n.autoDeleteNote
    }

    func tableView(_ tv: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let card = items[indexPath.row].card
        let delete = UIContextualAction(style: .destructive, title: L10n.delete) { [weak self] _, _, done in
            self?.permanentlyDelete(card, at: indexPath)
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(_ tv: UITableView,
                   leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let card = items[indexPath.row].card
        let restore = UIContextualAction(style: .normal, title: L10n.backupRestore) { [weak self] _, _, done in
            self?.restore(card, at: indexPath)
            done(true)
        }
        restore.image = UIImage(systemName: "arrow.uturn.backward")
        restore.backgroundColor = DayPinDesign.accent
        return UISwipeActionsConfiguration(actions: [restore])
    }

    func tableView(_ tv: UITableView,
                   contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        let item = items[indexPath.row]
        let card = item.card
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            let restore = UIAction(title: L10n.backupRestore,
                                   image: UIImage(systemName: "arrow.uturn.backward")) { [weak self] _ in
                self?.restore(card, at: indexPath)
            }
            let delete = UIAction(title: L10n.deleteForever,
                                  image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { [weak self] _ in
                self?.permanentlyDelete(card, at: indexPath)
            }
            return UIMenu(children: [restore, delete])
        })
    }
}

// MARK: - RecentlyDeletedCell

private final class RecentlyDeletedCell: UITableViewCell {

    static let reuseID = "RecentlyDeletedCell"

    private let typeIcon = UIImageView()
    private let titleLbl = UILabel()
    private let dateLbl = UILabel()
    private let daysLbl = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let iconBg = UIView()
        iconBg.backgroundColor = DayPinDesign.accent.withAlphaComponent(0.10)
        iconBg.layer.cornerRadius = 10
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        typeIcon.contentMode = .scaleAspectFit
        typeIcon.tintColor = DayPinDesign.accent
        typeIcon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(typeIcon)

        titleLbl.font = .inter(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .label
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        dateLbl.font = .inter(ofSize: 12)
        dateLbl.textColor = .secondaryLabel
        dateLbl.translatesAutoresizingMaskIntoConstraints = false

        daysLbl.font = .inter(ofSize: 12, weight: .medium)
        daysLbl.textAlignment = .right
        daysLbl.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLbl, dateLbl])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconBg)
        contentView.addSubview(textStack)
        contentView.addSubview(daysLbl)

        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconBg.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 38),
            iconBg.heightAnchor.constraint(equalToConstant: 38),

            typeIcon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            typeIcon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            typeIcon.widthAnchor.constraint(equalToConstant: 17),
            typeIcon.heightAnchor.constraint(equalToConstant: 17),

            textStack.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: daysLbl.leadingAnchor, constant: -8),

            daysLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            daysLbl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            daysLbl.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }

    func configure(card: NoteCard, deletedAt: Date) {
        titleLbl.text = card.title.isEmpty ? L10n.untitledNote : card.title

        let df = DateFormatter()
        df.dateFormat = "d MMM, HH:mm"
        df.locale = L10n.activeLocale
        dateLbl.text = L10n.deletedNotePrefix(df.string(from: deletedAt))

        let expiry = deletedAt.addingTimeInterval(30 * 24 * 3600)
        let seconds = expiry.timeIntervalSinceNow
        let days = max(0, Int(ceil(seconds / 86400)))
        if days <= 3 {
            daysLbl.text = days == 0 ? L10n.deletedToday : L10n.daysRemaining(days)
            daysLbl.textColor = .systemRed
        } else {
            daysLbl.text = L10n.daysRemaining(days)
            daysLbl.textColor = .tertiaryLabel
        }

        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        switch card.type {
        case .text:  typeIcon.image = UIImage(systemName: "text.alignleft", withConfiguration: cfg)
        case .image: typeIcon.image = UIImage(systemName: "photo", withConfiguration: cfg)
        case .link:  typeIcon.image = UIImage(systemName: "link", withConfiguration: cfg)
        }
    }
}
