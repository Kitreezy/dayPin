import UIKit

/// Bottom-sheet that lets the user pick a reminder date/time.
/// Present modally; set `onConfirm` and optionally `onRemove` before presenting.
final class ReminderPickerViewController: UIViewController {

    /// Called when the user taps "Set" with the chosen date.
    var onConfirm: ((Date) -> Void)?

    /// Called when the user taps "Remove reminder". Set to non-nil only if card already has a reminder.
    var onRemove: (() -> Void)?

    // MARK: - Init

    /// - Parameter existingDate: Pass the current reminder date (if any) to pre-fill the picker and show the remove button.
    init(existingDate: Date? = nil) {
        self.existingDate = existingDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private let existingDate: Date?

    // MARK: - UI

    private let blurBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let datePicker = UIDatePicker()
    private let setButton = GradientButton()
    private let removeButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Glass background fills the whole view
        blurBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurBackground)
        NSLayoutConstraint.activate([
            blurBackground.topAnchor.constraint(equalTo: view.topAnchor),
            blurBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Accent tint overlay for glass aesthetic
        let tintOverlay = UIView()
        tintOverlay.isUserInteractionEnabled = false
        tintOverlay.backgroundColor = DayPinDesign.accent.withAlphaComponent(0.06)
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        blurBackground.contentView.addSubview(tintOverlay)
        NSLayoutConstraint.activate([
            tintOverlay.topAnchor.constraint(equalTo: blurBackground.contentView.topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: blurBackground.contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: blurBackground.contentView.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: blurBackground.contentView.bottomAnchor)
        ])

        // Title
        titleLabel.text = L10n.remindMe
        titleLabel.font = .inter(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Date picker
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .inline
        datePicker.minimumDate = Date()
        datePicker.tintColor = DayPinDesign.accent
        if let existing = existingDate {
            datePicker.date = existing
        } else {
            // Default to 1 hour from now
            datePicker.date = Date().addingTimeInterval(3600)
        }
        datePicker.translatesAutoresizingMaskIntoConstraints = false

        // Set button
        setButton.setTitle(L10n.setReminder, for: .normal)
        setButton.setTitleColor(.white, for: .normal)
        setButton.titleLabel?.font = .inter(ofSize: 17, weight: .semibold)
        setButton.layer.cornerRadius = 14
        setButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        setButton.translatesAutoresizingMaskIntoConstraints = false

        // Remove button (only shown if a reminder already exists)
        removeButton.setTitle(L10n.removeReminder, for: .normal)
        removeButton.setTitleColor(.systemRed, for: .normal)
        removeButton.titleLabel?.font = .inter(ofSize: 16, weight: .medium)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.isHidden = (existingDate == nil || onRemove == nil)

        // Cancel button
        cancelButton.setTitle(L10n.cancel, for: .normal)
        cancelButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelButton.titleLabel?.font = .inter(ofSize: 16, weight: .regular)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonStack = UIStackView(arrangedSubviews: [setButton, removeButton, cancelButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [titleLabel, datePicker, buttonStack])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        blurBackground.contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            setButton.heightAnchor.constraint(equalToConstant: 50),

            contentStack.topAnchor.constraint(equalTo: blurBackground.contentView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: blurBackground.contentView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: blurBackground.contentView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: blurBackground.contentView.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Actions

    @objc private func confirmTapped() {
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.onConfirm?(self.datePicker.date)
        }
    }

    @objc private func removeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onRemove?()
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
