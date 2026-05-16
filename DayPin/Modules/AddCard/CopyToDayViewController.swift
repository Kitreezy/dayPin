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
        title = "Скопировать в день"
        view.backgroundColor = DayPinDesign.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain, target: self, action: #selector(dismissSelf)
        )

        setupPicker()
        setupCopyButton()
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
            UIColor(red: 0.56, green: 0.35, blue: 1.0, alpha: 1).cgColor,
            UIColor(red: 0.40, green: 0.20, blue: 0.90, alpha: 1).cgColor
        ]
        gradient.startPoint   = CGPoint(x: 0, y: 0)
        gradient.endPoint     = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = 14
        copyButton.layer.insertSublayer(gradient, at: 0)
        copyButton.layer.cornerRadius = 14
        copyButton.clipsToBounds = true

        copyButton.setTitle("Скопировать", for: .normal)
        copyButton.setTitleColor(.white, for: .normal)
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
            let src = self as! TextCard
            let c   = TextCard(title: src.title, comment: src.comment, dayDate: date)
            c.rtfData  = src.rtfData
            c.folderID = src.folderID
            return c
        case .image:
            let src = self as! ImageCard
            let c   = ImageCard(title: src.title, comment: src.comment, dayDate: date,
                                imageData: src.imageData, annotations: src.annotations)
            c.folderID = src.folderID
            return c
        case .link:
            let src = self as! LinkCard
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
