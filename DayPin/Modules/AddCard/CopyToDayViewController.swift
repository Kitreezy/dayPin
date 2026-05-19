import UIKit

/// Modal sheet for copying / duplicating one or more cards to a chosen day.
final class CopyToDayViewController: UIViewController {

    /// Called with the chosen destination date when user taps "Скопировать".
    var onCopy: ((Date) -> Void)?

    private var selectedDate = Calendar.current.startOfDay(for: Date())

    private let picker     = UIDatePicker()
    private let copyButton = UIButton(type: .custom)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.copyToDay
        view.backgroundColor = DayPinDesign.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain, target: self, action: #selector(dismissSelf)
        )

        setupPicker()
        setupCopyButton()
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
        title = L10n.copyToDay
        copyButton.setTitle(L10n.copyAction, for: .normal)
    }

    @objc private func onColorSchemeChanged() {
        picker.tintColor = DayPinDesign.accent
    }

    // MARK: - UI

    private func setupPicker() {
        picker.datePickerMode          = .date
        picker.preferredDatePickerStyle = .inline
        picker.date                    = selectedDate
        picker.maximumDate             = Date()
        picker.tintColor               = DayPinDesign.accent
        picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
    }

    private func setupCopyButton() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor { trait in UIColor(red: 0.56, green: 0.35, blue: 1.0, alpha: 1) }.cgColor,
            UIColor { trait in UIColor(red: 0.40, green: 0.20, blue: 0.90, alpha: 1) }.cgColor
        ]
        gradient.startPoint   = CGPoint(x: 0, y: 0)
        gradient.endPoint     = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = 14
        copyButton.layer.insertSublayer(gradient, at: 0)
        copyButton.layer.cornerRadius = 14
        copyButton.clipsToBounds = true

        copyButton.setTitle(L10n.copyAction, for: .normal)
        copyButton.setTitleColor(UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }, for: .normal)
        copyButton.titleLabel?.font = .inter(ofSize: 16, weight: .semibold)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(copyButton)
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 12),
            copyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            copyButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let g = copyButton.layer.sublayers?.first as? CAGradientLayer {
            g.frame = copyButton.bounds
        }
    }

    // MARK: - Actions

    @objc private func dateChanged() {
        selectedDate = Calendar.current.startOfDay(for: picker.date)
    }

    @objc private func copyTapped() {
        onCopy?(selectedDate)
        dismiss(animated: true)
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

// MARK: - NoteCard duplication helper

extension NoteCard {
    /// Returns a brand-new card with a new UUID targeting `date`, with all content copied.
    func duplicated(to date: Date) -> NoteCard {
        switch type {
        case .text:
            guard let src = self as? TextCard else { return TextCard(title: title, comment: comment, dayDate: date) }
            let c   = TextCard(title: src.title, comment: src.comment, dayDate: date)
            c.rtfData  = src.rtfData
            c.folderID = src.folderID
            return c
        case .image:
            guard let src = self as? ImageCard else { return ImageCard(title: title, comment: comment, dayDate: date, imageData: nil, annotations: []) }
            let c   = ImageCard(title: src.title, comment: src.comment, dayDate: date,
                                imageData: src.imageData, annotations: src.annotations)
            c.folderID = src.folderID
            return c
        case .link:
            guard let src = self as? LinkCard else { return LinkCard(title: title, comment: comment, dayDate: date, url: URL(fileURLWithPath: ""), extraURLs: []) }
            let c   = LinkCard(title: src.title, comment: src.comment, dayDate: date,
                               url: src.url, extraURLs: src.extraURLs)
            c.previewTitle       = src.previewTitle
            c.previewDescription = src.previewDescription
            c.previewImageData   = src.previewImageData
            c.folderID           = src.folderID
            return c
        }
    }
}
