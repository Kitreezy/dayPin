import UIKit

final class CardDetailViewController: UIViewController {

    private let card: TextCard
    private var bellButton: UIBarButtonItem?

    init(card: TextCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        title = card.title
        setupNav()
        setupUI()
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
        setupNav()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        refreshBellButton()
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(goBack)
        )

        let editBtn = UIBarButtonItem(image: UIImage(systemName: "pencil"),
                                      style: .plain, target: self, action: #selector(edit))

        let bellSymbol = (card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date())
            ? "bell.fill" : "bell"
        let bell = UIBarButtonItem(image: UIImage(systemName: bellSymbol),
                                   style: .plain, target: self, action: #selector(bellTapped))
        bell.tintColor = (card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date())
            ? DayPinDesign.accent : nil
        bellButton = bell

        let shareAction = UIAction(title: L10n.share,    image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in self?.share() }
        let folderAction = UIAction(title: L10n.inFolder, image: UIImage(systemName: "folder.badge.plus"))  { [weak self] _ in self?.addToFolder() }
        let menu = UIMenu(children: [shareAction, folderAction])
        let moreBtn = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                      menu: menu)

        navigationItem.rightBarButtonItems = [moreBtn, editBtn, bell]
    }

    private func refreshBellButton() {
        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        let symbol = hasReminder ? "bell.fill" : "bell"
        bellButton?.image = UIImage(systemName: symbol)
        bellButton?.tintColor = hasReminder ? DayPinDesign.accent : nil
    }

    @objc private func bellTapped() {
        let picker = ReminderPickerViewController(existingDate: card.reminderDate)
        picker.onConfirm = { [weak self] date in
            guard let self else { return }
            ReminderManager.shared.schedule(for: self.card, at: date) { [weak self] notifID in
                guard let self else { return }
                self.card.reminderDate = date
                self.card.reminderNotificationID = notifID
                CardStore.shared.save(card: self.card)
                self.refreshBellButton()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        if card.reminderDate != nil {
            picker.onRemove = { [weak self] in
                guard let self else { return }
                ReminderManager.shared.cancel(for: self.card)
                self.card.reminderDate = nil
                self.card.reminderNotificationID = nil
                CardStore.shared.save(card: self.card)
                self.refreshBellButton()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(picker, animated: true)
    }

    // MARK: - UI

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func setupUI() {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scroll.topAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        let cardView = GlassCardView(style: .card)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cardView)

        // Date
        let df = DateFormatter()
        df.dateFormat = "d MMMM yyyy · HH:mm"
        df.locale = L10n.activeLocale
        let dateLabel = UILabel()
        dateLabel.text = df.string(from: card.createdAt)
        dateLabel.font = .inter(ofSize: 12, weight: .regular)
        dateLabel.textColor = .tertiaryLabel

        // Title
        let titleLabel = UILabel()
        titleLabel.text = card.title
        titleLabel.font = .inter(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        cardView.stackView.spacing = 10
        cardView.stackView.addArrangedSubview(dateLabel)
        cardView.stackView.addArrangedSubview(titleLabel)

        let displayText: NSAttributedString? = card.attributedComment ?? (
            card.comment.isEmpty ? nil : NSAttributedString(
                string: card.comment,
                attributes: [.font: UIFont.inter(ofSize: 16), .foregroundColor: UIColor.secondaryLabel]
            )
        )

        if let displayText, displayText.length > 0 {
            let sep = UIView()
            sep.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
            sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

            let commentLabel = UILabel()
            commentLabel.attributedText = displayText.applying(baseColor: .secondaryLabel, baseFont: .inter(ofSize: 16))
            commentLabel.numberOfLines = 0
            commentLabel.lineBreakMode = .byWordWrapping

            cardView.stackView.addArrangedSubview(sep)
            cardView.stackView.addArrangedSubview(commentLabel)
        }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Actions

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func share() {
        var items: [Any] = [card.title]
        if !card.comment.isEmpty { items.append(card.comment) }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }

    @objc private func edit() {
        let vc = TextCardEditorViewController(card: card, dayDate: card.dayDate)
        vc.onSave = { [weak self] saved in
            CardStore.shared.save(card: saved)
            self?.navigationController?.popViewController(animated: true)
        }
        presentEditorSheet(vc)
    }

    @objc private func addToFolder() {
        let folders = FolderStore.shared.all()
        let sheet = UIAlertController(title: L10n.addToFolder, message: nil, preferredStyle: .actionSheet)
        for folder in folders {
            let isCurrent = card.folderID == folder.id
            let title = isCurrent ? "✓ \(folder.name)" : folder.name
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                self.card.folderID = isCurrent ? nil : folder.id
                CardStore.shared.save(card: self.card)
            })
        }
        if folders.isEmpty {
            sheet.addAction(UIAlertAction(title: L10n.noFoldersHint, style: .default, handler: nil))
        }
        sheet.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(sheet, animated: true)
    }
}
