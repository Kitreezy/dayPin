import UIKit
import SafariServices

final class LinkCardDetailViewController: UIViewController {

    private var card: LinkCard
    private var bellButton: UIBarButtonItem?
    private let cardView = GlassCardView(style: .card)
    private let titleLabel = UILabel()
    private let linksStack = UIStackView()
    private let commentLabel = UILabel()
    private let coverImageView = UIImageView()

    init(card: LinkCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        title = card.title
        setupNavButtons()
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
        render()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        refreshBellButton()
        render()
    }

    // MARK: - Navigation

    private func setupNavButtons() {
        let editBtn = UIBarButtonItem(image: UIImage(systemName: "pencil"),
                                     style: .plain, target: self, action: #selector(editTapped))

        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        let bell = UIBarButtonItem(
            image: UIImage(systemName: hasReminder ? "bell.fill" : "bell"),
            style: .plain, target: self, action: #selector(bellTapped))
        bell.tintColor = hasReminder ? DayPinDesign.accent : nil
        bellButton = bell

        navigationItem.rightBarButtonItems = [editBtn, bell]
    }

    private func refreshBellButton() {
        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        bellButton?.image = UIImage(systemName: hasReminder ? "bell.fill" : "bell")
        bellButton?.tintColor = hasReminder ? DayPinDesign.accent : nil
    }

    // MARK: - Actions

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

        coverImageView.contentMode = .scaleAspectFill
        coverImageView.layer.cornerRadius = 16
        coverImageView.layer.masksToBounds = true
        coverImageView.isUserInteractionEnabled = true
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        coverImageView.isHidden = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(coverTapped))
        coverImageView.addGestureRecognizer(tap)
        container.addSubview(coverImageView)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cardView)

        titleLabel.font = .inter(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 0

        linksStack.axis = .vertical
        linksStack.spacing = 8

        commentLabel.font = .inter(ofSize: 16)
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 0

        cardView.stackView.spacing = 12
        cardView.stackView.addArrangedSubview(titleLabel)
        cardView.stackView.addArrangedSubview(linksStack)
        cardView.stackView.addArrangedSubview(commentLabel)

        render()

        let hasCover = card.previewImageData != nil
        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: container.topAnchor, constant: hasCover ? 16 : 0),
            coverImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            coverImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            coverImageView.heightAnchor.constraint(equalToConstant: 180),

            cardView.topAnchor.constraint(equalTo: hasCover ? coverImageView.bottomAnchor : container.topAnchor,
                                          constant: 16),
            cardView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24)
        ])
    }

    private func render() {
        titleLabel.text = card.title
        title = card.title
        commentLabel.text = card.comment
        commentLabel.isHidden = card.comment.isEmpty

        if let data = card.previewImageData, let image = UIImage(data: data) {
            coverImageView.image = image
            coverImageView.isHidden = false
        } else {
            coverImageView.isHidden = true
        }

        linksStack.arrangedSubviews.forEach {
            linksStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let allLinks = [card.url] + card.extraURLs
        for (index, url) in allLinks.enumerated() {
            let button = UIButton(type: .system)
            var cfg = UIButton.Configuration.plain()
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            cfg.image = UIImage(systemName: "link.circle")
            cfg.imagePadding = 6
            cfg.baseForegroundColor = DayPinDesign.linkCardTint
            cfg.title = url.absoluteString
            button.configuration = cfg
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .inter(ofSize: 13, weight: .semibold)
            button.tag = index
            button.layer.cornerRadius = 10
            button.backgroundColor = DayPinDesign.linkCardTint.withAlphaComponent(0.08)
            button.addTarget(self, action: #selector(openLinkTapped(_:)), for: .touchUpInside)
            linksStack.addArrangedSubview(button)
        }
    }

    @objc private func coverTapped() {
        guard let image = coverImageView.image else { return }
        let viewer = FullScreenImageViewController(image: image, sourceView: coverImageView)
        viewer.modalPresentationStyle = .overFullScreen
        viewer.modalTransitionStyle = .crossDissolve
        present(viewer, animated: false)
    }

    @objc private func openLinkTapped(_ sender: UIButton) {
        let allLinks = [card.url] + card.extraURLs
        guard allLinks.indices.contains(sender.tag) else { return }
        let safari = SFSafariViewController(url: allLinks[sender.tag])
        safari.modalPresentationStyle = .pageSheet
        if let sheet = safari.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(safari, animated: true)
    }

    @objc private func editTapped() {
        let vc = LinkCardEditorViewController(card: card, dayDate: card.dayDate)
        vc.onSave = { [weak self] saved in
            CardStore.shared.save(card: saved)
            self?.card = saved
            self?.render()
        }
        presentEditorSheet(vc)
    }
}
