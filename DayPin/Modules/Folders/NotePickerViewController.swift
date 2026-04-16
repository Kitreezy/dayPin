import UIKit

// MARK: - NotePickerViewController
// Выбор существующих заметок для добавления в папку.
// Показывает все заметки, которые ещё не находятся в указанной папке.

final class NotePickerViewController: UIViewController {

    var onAdd: (([NoteCard]) -> Void)?

    private let folderID: UUID
    private var available: [NoteCard] = []
    private var selectedIDs = Set<UUID>()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = .clear
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate   = self
        tv.register(NotePickerCell.self, forCellReuseIdentifier: NotePickerCell.reuseID)
        return tv
    }()

    private lazy var addBtn = UIBarButtonItem(
        title: "Добавить",
        style: .done,
        target: self,
        action: #selector(confirmTapped)
    )

    // MARK: - Init

    init(folderID: UUID) {
        self.folderID = folderID
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Добавить заметки"
        view.backgroundColor = DayPinDesign.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена", style: .plain, target: self, action: #selector(cancel)
        )
        addBtn.isEnabled = false
        addBtn.tintColor = DayPinDesign.accent
        navigationItem.rightBarButtonItem = addBtn

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadNotes()
    }

    // MARK: - Data

    private func loadNotes() {
        // Все заметки которые НЕ находятся уже в этой папке
        available = CardStore.shared.allCards().filter { $0.folderID != folderID }
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func confirmTapped() {
        let selected = available.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { dismiss(animated: true); return }
        onAdd?(selected)
        dismiss(animated: true)
    }

    private func updateAddButton() {
        let n = selectedIDs.count
        addBtn.isEnabled = n > 0
        addBtn.title = n > 0 ? "Добавить (\(n))" : "Добавить"
    }
}

// MARK: - UITableViewDataSource + Delegate

extension NotePickerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        available.isEmpty ? 1 : available.count
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if available.isEmpty {
            let cell = UITableViewCell()
            cell.textLabel?.text      = "Все заметки уже в этой папке"
            cell.textLabel?.textColor = .secondaryLabel
            cell.textLabel?.textAlignment = .center
            cell.backgroundColor = .clear
            cell.isUserInteractionEnabled = false
            return cell
        }
        let cell = tv.dequeueReusableCell(withIdentifier: NotePickerCell.reuseID, for: indexPath) as! NotePickerCell
        let card = available[indexPath.row]
        cell.configure(card: card, isSelected: selectedIDs.contains(card.id))
        return cell
    }

    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        guard !available.isEmpty else { return }
        let card = available[indexPath.row]
        if selectedIDs.contains(card.id) {
            selectedIDs.remove(card.id)
        } else {
            selectedIDs.insert(card.id)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateAddButton()
        tv.reloadRows(at: [indexPath], with: .none)
    }

    func tableView(_ tv: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 60 }

    func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        available.isEmpty ? nil : "\(available.count) доступных заметок"
    }
}

// MARK: - NotePickerCell

private final class NotePickerCell: UITableViewCell {

    static let reuseID = "NotePickerCell"

    private let typeIcon    = UIImageView()
    private let titleLbl    = UILabel()
    private let dateLbl     = UILabel()
    private let checkCircle = UIView()
    private let checkMark   = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Type icon background
        let iconBg = UIView()
        iconBg.layer.cornerRadius   = 10
        iconBg.backgroundColor      = DayPinDesign.accent.withAlphaComponent(0.1)
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        typeIcon.contentMode = .scaleAspectFit
        typeIcon.tintColor   = DayPinDesign.accent
        typeIcon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(typeIcon)

        titleLbl.font          = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor     = .label
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        dateLbl.font      = .systemFont(ofSize: 12)
        dateLbl.textColor = .secondaryLabel
        dateLbl.translatesAutoresizingMaskIntoConstraints = false

        // Checkmark circle (right side)
        checkCircle.layer.cornerRadius  = 11
        checkCircle.layer.borderWidth   = 1.5
        checkCircle.layer.borderColor   = UIColor.systemGray3.cgColor
        checkCircle.translatesAutoresizingMaskIntoConstraints = false

        let checkCfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        checkMark.image       = UIImage(systemName: "checkmark", withConfiguration: checkCfg)
        checkMark.tintColor   = .white
        checkMark.contentMode = .scaleAspectFit
        checkMark.translatesAutoresizingMaskIntoConstraints = false
        checkMark.isHidden = true
        checkCircle.addSubview(checkMark)

        let textStack = UIStackView(arrangedSubviews: [titleLbl, dateLbl])
        textStack.axis    = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconBg)
        contentView.addSubview(textStack)
        contentView.addSubview(checkCircle)

        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconBg.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 36),
            iconBg.heightAnchor.constraint(equalToConstant: 36),

            typeIcon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            typeIcon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            typeIcon.widthAnchor.constraint(equalToConstant: 16),
            typeIcon.heightAnchor.constraint(equalToConstant: 16),

            textStack.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: checkCircle.leadingAnchor, constant: -12),

            checkCircle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkCircle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkCircle.widthAnchor.constraint(equalToConstant: 22),
            checkCircle.heightAnchor.constraint(equalToConstant: 22),

            checkMark.centerXAnchor.constraint(equalTo: checkCircle.centerXAnchor),
            checkMark.centerYAnchor.constraint(equalTo: checkCircle.centerYAnchor),
            checkMark.widthAnchor.constraint(equalToConstant: 11),
            checkMark.heightAnchor.constraint(equalToConstant: 11)
        ])
    }

    func configure(card: NoteCard, isSelected: Bool) {
        titleLbl.text = card.title.isEmpty ? "(без названия)" : card.title

        let df = DateFormatter()
        df.dateFormat = "d MMM, HH:mm"
        df.locale = Locale.current
        dateLbl.text = df.string(from: card.createdAt)

        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        switch card.type {
        case .text:
            typeIcon.image = UIImage(systemName: "text.alignleft", withConfiguration: cfg)
        case .image:
            typeIcon.image = UIImage(systemName: "photo", withConfiguration: cfg)
        case .link:
            typeIcon.image = UIImage(systemName: "link", withConfiguration: cfg)
        }

        UIView.animate(withDuration: 0.15) {
            self.checkCircle.backgroundColor  = isSelected ? DayPinDesign.accent : .clear
            self.checkCircle.layer.borderColor = isSelected
                ? UIColor.clear.cgColor
                : UIColor.systemGray3.cgColor
            self.checkMark.isHidden = !isSelected
        }
    }
}
