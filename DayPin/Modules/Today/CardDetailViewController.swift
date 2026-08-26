import UIKit

final class CardDetailViewController: UIViewController {

    private let card: TextCard
    private var bellButton: UIBarButtonItem?
    private var doneButton: UIBarButtonItem?

    private var isNoteEditing = false

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let dateLabel = UILabel()
    private let titleTextView = UITextView()
    private let bodyTextView = UITextView()

    // Formatting strip + container that tracks keyboard
    private let stripContainer = UIView()
    private let formattingStrip = NoteFormattingStrip()
    private let stripSeparator = UIView()

    init(card: TextCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupScrollContent()
        setupStripContainer()
        populateContent()
        addTapToEditGesture()
        observeNotifications()
        observeKeyboard()

        formattingStrip.onAction = { [weak self] action in self?.applyFormat(action) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
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

    @objc private func onLanguageChanged() { refreshNav() }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        refreshBellButton()
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(goBack)
        )
        refreshNav()
    }

    private func refreshNav() {
        let bell = buildBellButton()
        bellButton = bell

        let shareAction = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in self?.share() }
        let shareLinkAction = UIAction(title: L10n.shareViaLink, image: UIImage(systemName: "link")) { [weak self] _ in
            guard let self else { return }
            ShareLinkPresenter.shareCard(self.card, from: self)
        }
        let folderAction = UIAction(title: L10n.inFolder, image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in self?.addToFolder() }
        let moreBtn = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: [shareAction, shareLinkAction, folderAction]))

        if isNoteEditing {
            let done = UIBarButtonItem(title: L10n.done, style: .done, target: self, action: #selector(finishEditing))
            done.tintColor = DayPinDesign.accent
            doneButton = done
            navigationItem.rightBarButtonItems = [done, bell]
        } else {
            doneButton = nil
            navigationItem.rightBarButtonItems = [moreBtn, bell]
        }
    }

    private func buildBellButton() -> UIBarButtonItem {
        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        let symbol = hasReminder ? "bell.fill" : "bell"
        let btn = UIBarButtonItem(image: UIImage(systemName: symbol), style: .plain,
                                  target: self, action: #selector(bellTapped))
        btn.tintColor = hasReminder ? DayPinDesign.accent : nil
        return btn
    }

    private func refreshBellButton() {
        let hasReminder = card.reminderDate != nil && (card.reminderDate ?? .distantPast) > Date()
        bellButton?.image = UIImage(systemName: hasReminder ? "bell.fill" : "bell")
        bellButton?.tintColor = hasReminder ? DayPinDesign.accent : nil
    }

    // MARK: - Scroll content

    private func setupScrollContent() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // Date
        let df = DateFormatter()
        df.dateFormat = "d MMMM yyyy · HH:mm"
        df.locale = L10n.activeLocale
        dateLabel.text = df.string(from: card.createdAt)
        dateLabel.font = .inter(ofSize: 13)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        // Title text view (read-only)
        titleTextView.font = .inter(ofSize: 24, weight: .bold)
        titleTextView.textColor = .label
        titleTextView.backgroundColor = .clear
        titleTextView.isScrollEnabled = false
        titleTextView.textContainerInset = .zero
        titleTextView.textContainer.lineFragmentPadding = 0
        titleTextView.isEditable = false
        titleTextView.isSelectable = false
        titleTextView.delegate = self
        titleTextView.translatesAutoresizingMaskIntoConstraints = false

        // Body text view (read-only)
        bodyTextView.font = .inter(ofSize: 16)
        bodyTextView.textColor = .secondaryLabel
        bodyTextView.backgroundColor = .clear
        bodyTextView.isScrollEnabled = false
        bodyTextView.textContainerInset = .zero
        bodyTextView.textContainer.lineFragmentPadding = 0
        bodyTextView.allowsEditingTextAttributes = true
        bodyTextView.isEditable = false
        bodyTextView.isSelectable = false
        bodyTextView.delegate = self
        bodyTextView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(dateLabel)
        contentView.addSubview(titleTextView)
        contentView.addSubview(bodyTextView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // bottom attached to stripContainer

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            titleTextView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 10),
            titleTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            bodyTextView.topAnchor.constraint(equalTo: titleTextView.bottomAnchor, constant: 12),
            bodyTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bodyTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bodyTextView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    // MARK: - Formatting strip container

    private func setupStripContainer() {
        stripContainer.backgroundColor = .clear
        stripContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stripContainer)

        stripSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        stripSeparator.translatesAutoresizingMaskIntoConstraints = false
        stripSeparator.isHidden = true

        formattingStrip.translatesAutoresizingMaskIntoConstraints = false
        formattingStrip.isHidden = true

        stripContainer.addSubview(stripSeparator)
        stripContainer.addSubview(formattingStrip)

        NSLayoutConstraint.activate([
            scrollView.bottomAnchor.constraint(equalTo: stripContainer.topAnchor),
            stripContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stripContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stripContainer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            stripSeparator.topAnchor.constraint(equalTo: stripContainer.topAnchor),
            stripSeparator.leadingAnchor.constraint(equalTo: stripContainer.leadingAnchor),
            stripSeparator.trailingAnchor.constraint(equalTo: stripContainer.trailingAnchor),
            stripSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            formattingStrip.topAnchor.constraint(equalTo: stripSeparator.bottomAnchor),
            formattingStrip.leadingAnchor.constraint(equalTo: stripContainer.leadingAnchor),
            formattingStrip.trailingAnchor.constraint(equalTo: stripContainer.trailingAnchor),
            formattingStrip.heightAnchor.constraint(equalToConstant: 44),
            formattingStrip.bottomAnchor.constraint(equalTo: stripContainer.bottomAnchor)
        ])
    }

    // MARK: - Populate

    private func populateContent() {
        titleTextView.text = card.title

        if let attributed = card.attributedComment, attributed.length > 0 {
            bodyTextView.attributedText = attributed.applying(baseColor: .secondaryLabel, baseFont: .inter(ofSize: 16))
        } else if !card.comment.isEmpty {
            bodyTextView.text = card.comment
        }
    }

    // MARK: - Tap to edit

    private func addTapToEditGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(enterEditMode))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
    }

    @objc private func enterEditMode() {
        guard !isNoteEditing else { return }
        isNoteEditing = true

        titleTextView.isEditable = true
        titleTextView.isSelectable = true
        bodyTextView.isEditable = true
        bodyTextView.isSelectable = true

        // Apply correct text color in editing mode
        titleTextView.textColor = .label
        bodyTextView.textColor = .label
        if let attr = bodyTextView.attributedText {
            let mas = NSMutableAttributedString(attributedString: attr)
            mas.addAttribute(.foregroundColor, value: UIColor.label,
                             range: NSRange(location: 0, length: mas.length))
            bodyTextView.attributedText = mas
        }

        refreshNav()

        UIView.animate(withDuration: 0.22) {
            self.formattingStrip.isHidden = false
            self.stripSeparator.isHidden = false
        }

        // Focus body if it has content, otherwise title
        if bodyTextView.text.isEmpty {
            titleTextView.becomeFirstResponder()
        } else {
            bodyTextView.becomeFirstResponder()
        }
    }

    @objc private func finishEditing() {
        saveChanges()
        exitEditMode()
    }

    private func exitEditMode() {
        isNoteEditing = false
        view.endEditing(true)

        titleTextView.isEditable = false
        titleTextView.isSelectable = false
        bodyTextView.isEditable = false
        bodyTextView.isSelectable = false

        // Restore reading colors
        bodyTextView.textColor = .secondaryLabel
        if let attr = bodyTextView.attributedText {
            let mas = NSMutableAttributedString(attributedString: attr)
            mas.addAttribute(.foregroundColor, value: UIColor.secondaryLabel,
                             range: NSRange(location: 0, length: mas.length))
            bodyTextView.attributedText = mas
        }

        refreshNav()

        UIView.animate(withDuration: 0.22) {
            self.formattingStrip.isHidden = true
            self.stripSeparator.isHidden = true
        }
    }

    // MARK: - Save

    private func saveChanges() {
        var titleText = titleTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bodyText = bodyTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !(titleText.isEmpty && bodyText.isEmpty) else { return }

        if titleText.isEmpty {
            let first = bodyText
                .components(separatedBy: .newlines)
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
                .trimmingCharacters(in: .whitespaces) ?? L10n.untitledNote
            titleText = first.count > 60 ? String(first.prefix(57)) + "…" : first
        }

        card.title = titleText
        title = titleText

        let attributed = bodyTextView.attributedText ?? NSAttributedString()
        if attributed.length > 0 {
            card.setAttributedComment(attributed)
        } else {
            card.comment = bodyText
            card.rtfData = nil
        }

        CardStore.shared.save(card: card)
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard isNoteEditing else { return }
        saveChanges()
        exitEditMode()
    }

    // MARK: - Formatting

    private func applyFormat(_ action: NoteFormattingStrip.Action) {
        if case .dismissKeyboard = action {
            view.endEditing(true)
            return
        }

        let tv = bodyTextView.isFirstResponder ? bodyTextView : titleTextView
        guard tv.isFirstResponder else { return }

        switch action {
        case .listBullet:   toggleListPrefix("• ", in: tv);           formattingStrip.updateState(for: tv); return
        case .listNumbered: toggleListPrefix(nil, numbered: true, in: tv); formattingStrip.updateState(for: tv); return
        case .listDash:     toggleListPrefix("- ", in: tv);           formattingStrip.updateState(for: tv); return
        default: break
        }

        let range = tv.selectedRange
        if range.length == 0 {
            applyToTypingAttributes(action, in: tv)
            formattingStrip.updateState(for: tv)
            return
        }

        let mas = NSMutableAttributedString(attributedString: tv.attributedText)
        switch action {
        case .fontSmaller:   mas.adjustFontSize(by: -2, in: range, min: 10)
        case .fontLarger:    mas.adjustFontSize(by: +2, in: range, max: 36)
        case .bold:          mas.toggleTrait(.traitBold,   in: range, baseSize: 16)
        case .italic:        mas.toggleTrait(.traitItalic, in: range, baseSize: 16)
        case .underline:     mas.toggleUnderline(in: range)
        case .strikethrough: mas.toggleStrikethrough(in: range)
        case .heading:       mas.toggleHeading(in: range)
        default: break
        }

        let sel = tv.selectedRange
        tv.attributedText = mas
        tv.selectedRange = sel
        if sel.location > 0, let attr = tv.attributedText {
            let idx = min(sel.location, attr.length) - 1
            var attrs = attr.attributes(at: max(0, idx), effectiveRange: nil)
            attrs[.foregroundColor] = UIColor.label
            tv.typingAttributes = attrs
        }
        formattingStrip.updateState(for: tv)
    }

    private func toggleListPrefix(_ prefix: String?, numbered: Bool = false, in tv: UITextView) {
        guard let text = tv.text else { return }
        let ns = text as NSString
        let pos = tv.selectedRange.location
        let paraRange = ns.paragraphRange(for: NSRange(location: min(pos, max(0, ns.length - 1)), length: 0))
        let para = ns.substring(with: paraRange)

        let existing: String?
        if para.hasPrefix("• ") { existing = "• " }
        else if para.hasPrefix("- ") { existing = "- " }
        else if let n = formattingStrip.numberedListPrefix(in: para) { existing = "\(n). " }
        else { existing = nil }

        let mas = NSMutableAttributedString(attributedString: tv.attributedText)
        let insertAt = paraRange.location

        if let ex = existing {
            if insertAt + ex.count <= mas.length {
                mas.deleteCharacters(in: NSRange(location: insertAt, length: ex.count))
            }
            let want: String?
            if numbered { want = ex.first?.isNumber == true ? nil : "1. " }
            else { want = (ex == prefix) ? nil : prefix }
            if let w = want {
                mas.insert(NSAttributedString(string: w, attributes: typingAttrs()), at: insertAt)
            }
        } else {
            let newPrefix = numbered ? "1. " : (prefix ?? "• ")
            mas.insert(NSAttributedString(string: newPrefix, attributes: typingAttrs()), at: insertAt)
        }

        let sel = tv.selectedRange
        tv.attributedText = mas
        tv.selectedRange = NSRange(location: min(sel.location, mas.length), length: 0)
    }

    private func applyToTypingAttributes(_ action: NoteFormattingStrip.Action, in tv: UITextView) {
        var attrs = tv.typingAttributes
        let font = attrs[.font] as? UIFont ?? .inter(ofSize: 16)
        switch action {
        case .bold:
            var t = font.fontDescriptor.symbolicTraits
            if t.contains(.traitBold) { t.remove(.traitBold) } else { t.insert(.traitBold) }
            if let d = font.fontDescriptor.withSymbolicTraits(t) { attrs[.font] = UIFont(descriptor: d, size: 0) }
        case .italic:
            var t = font.fontDescriptor.symbolicTraits
            if t.contains(.traitItalic) { t.remove(.traitItalic) } else { t.insert(.traitItalic) }
            if let d = font.fontDescriptor.withSymbolicTraits(t) { attrs[.font] = UIFont(descriptor: d, size: 0) }
        case .underline:
            let cur = attrs[.underlineStyle] as? Int ?? 0
            attrs[.underlineStyle] = cur == 0 ? NSUnderlineStyle.single.rawValue : 0
        case .strikethrough:
            let cur = attrs[.strikethroughStyle] as? Int ?? 0
            attrs[.strikethroughStyle] = cur == 0 ? NSUnderlineStyle.single.rawValue : 0
        case .heading:
            let isHeading = font.pointSize >= 20
            attrs[.font] = isHeading
                ? UIFont.inter(ofSize: 16, weight: .regular)
                : UIFont.inter(ofSize: 22, weight: .bold)
        case .fontSmaller:
            attrs[.font] = UIFont(descriptor: font.fontDescriptor, size: max(10, font.pointSize - 2))
        case .fontLarger:
            attrs[.font] = UIFont(descriptor: font.fontDescriptor, size: min(36, font.pointSize + 2))
        default: break
        }
        attrs[.foregroundColor] = UIColor.label
        tv.typingAttributes = attrs
    }

    private func typingAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.inter(ofSize: 16), .foregroundColor: UIColor.label]
    }

    // MARK: - Actions

    @objc private func goBack() {
        if isNoteEditing { saveChanges() }
        navigationController?.popViewController(animated: true)
    }

    @objc private func share() {
        var items: [Any] = [card.title]
        if !card.comment.isEmpty { items.append(card.comment) }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
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

    @objc private func addToFolder() {
        let folders = FolderStore.shared.all()
        guard !folders.isEmpty else {
            GlassAlert.show(in: self, title: L10n.addToFolder, message: L10n.noFoldersHint)
            return
        }
        let actions: [GlassAction] = folders.map { folder in
            let isCurrent = card.folderID == folder.id
            let icon = isCurrent ? "checkmark.circle.fill" : "folder"
            return GlassAction(isCurrent ? "✓ \(folder.name)" : folder.name, icon: icon) { [weak self] in
                guard let self else { return }
                self.card.folderID = isCurrent ? nil : folder.id
                CardStore.shared.save(card: self.card)
            }
        }
        GlassActionSheet.show(title: L10n.addToFolder, actions: actions, from: self)
    }
}

// MARK: - UITextViewDelegate

extension CardDetailViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        formattingStrip.updateState(for: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        if isNoteEditing { formattingStrip.updateState(for: textView) }
    }
}
