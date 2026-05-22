import UIKit

final class TextCardEditorViewController: UIViewController {

    var onSave: ((TextCard) -> Void)?

    private let card: TextCard?
    private let dayDate: Date

    // MARK: - Scroll content

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let dateLabel = UILabel()

    // Single unified text view: first line = title (bold 24pt), rest = body (16pt)
    private let noteTextView = UITextView()
    private let notePlaceholder = UILabel()

    // MARK: - Control panel (floats above keyboard)

    private let controlContainer = UIView()
    private let formattingStrip = NoteFormattingStrip()
    private var stripHeightConstraint: NSLayoutConstraint!
    private let panelSeparator = UIView()
    private let bottomBar = UIView()
    private let tagPill = UIButton(type: .system)
    private let aaButton = UIButton(type: .system)
    private let tagsInputView = TagsInputView()
    private var tagPanelHeightConstraint: NSLayoutConstraint!
    private var stripVisible = false
    private var tagPanelVisible = false

    // MARK: - Init

    init(card: TextCard?, dayDate: Date) {
        self.card = card
        self.dayDate = dayDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupScrollContent()
        setupControlPanel()
        fillContent()
        observeNotifications()

        formattingStrip.onAction = { [weak self] action in self?.applyFormat(action) }
        presentationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        noteTextView.becomeFirstResponder()
        // Place cursor at end
        noteTextView.selectedRange = NSRange(location: noteTextView.text.count, length: 0)
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
        navigationItem.leftBarButtonItem?.title = L10n.cancel
        navigationItem.rightBarButtonItem?.title = L10n.save
        notePlaceholder.text = L10n.titleOptionalPlaceholder
        refreshTagPill()
    }

    @objc private func onColorSchemeChanged() {
        navigationItem.rightBarButtonItem?.tintColor = DayPinDesign.accent
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.cancel, style: .plain, target: self, action: #selector(cancel)
        )
        let saveBtn = UIBarButtonItem(
            title: L10n.save, style: .done, target: self, action: #selector(save)
        )
        saveBtn.tintColor = DayPinDesign.accent
        navigationItem.rightBarButtonItem = saveBtn
    }

    // MARK: - Scroll content

    private func setupScrollContent() {
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // Date label
        let displayDate = card?.createdAt ?? Date()
        let df = DateFormatter()
        df.dateFormat = "d MMMM, HH:mm"
        df.locale = L10n.activeLocale
        dateLabel.text = df.string(from: displayDate)
        dateLabel.font = .inter(ofSize: 13)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        // Note text view
        noteTextView.backgroundColor = .clear
        noteTextView.isScrollEnabled = false
        noteTextView.textContainerInset = .zero
        noteTextView.textContainer.lineFragmentPadding = 0
        noteTextView.allowsEditingTextAttributes = true
        noteTextView.delegate = self
        noteTextView.typingAttributes = titleTypingAttrs()
        noteTextView.translatesAutoresizingMaskIntoConstraints = false

        // Placeholder
        notePlaceholder.text = L10n.titleOptionalPlaceholder
        notePlaceholder.font = titleFont()
        notePlaceholder.textColor = .placeholderText
        notePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        noteTextView.addSubview(notePlaceholder)

        contentView.addSubview(dateLabel)
        contentView.addSubview(noteTextView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            noteTextView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 10),
            noteTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            noteTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            noteTextView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            noteTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            notePlaceholder.topAnchor.constraint(equalTo: noteTextView.topAnchor),
            notePlaceholder.leadingAnchor.constraint(equalTo: noteTextView.leadingAnchor)
        ])
    }

    // MARK: - Control panel

    private func setupControlPanel() {
        controlContainer.backgroundColor = .clear
        controlContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlContainer)

        formattingStrip.translatesAutoresizingMaskIntoConstraints = false
        formattingStrip.clipsToBounds = true

        let tagPanel = UIView()
        tagPanel.translatesAutoresizingMaskIntoConstraints = false
        tagPanel.clipsToBounds = true
        tagsInputView.translatesAutoresizingMaskIntoConstraints = false
        tagPanel.addSubview(tagsInputView)
        NSLayoutConstraint.activate([
            tagsInputView.topAnchor.constraint(equalTo: tagPanel.topAnchor, constant: 6),
            tagsInputView.leadingAnchor.constraint(equalTo: tagPanel.leadingAnchor, constant: 16),
            tagsInputView.trailingAnchor.constraint(equalTo: tagPanel.trailingAnchor, constant: -16),
            tagsInputView.bottomAnchor.constraint(equalTo: tagPanel.bottomAnchor, constant: -6)
        ])

        panelSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        panelSeparator.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        setupBottomBar()

        controlContainer.addSubview(formattingStrip)
        controlContainer.addSubview(tagPanel)
        controlContainer.addSubview(panelSeparator)
        controlContainer.addSubview(bottomBar)

        stripHeightConstraint = formattingStrip.heightAnchor.constraint(equalToConstant: 0)
        tagPanelHeightConstraint = tagPanel.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            scrollView.bottomAnchor.constraint(equalTo: controlContainer.topAnchor),

            controlContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlContainer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            formattingStrip.topAnchor.constraint(equalTo: controlContainer.topAnchor),
            formattingStrip.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor),
            formattingStrip.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor),
            stripHeightConstraint,

            tagPanel.topAnchor.constraint(equalTo: formattingStrip.bottomAnchor),
            tagPanel.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor),
            tagPanel.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor),
            tagPanelHeightConstraint,

            panelSeparator.topAnchor.constraint(equalTo: tagPanel.bottomAnchor),
            panelSeparator.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor),
            panelSeparator.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor),
            panelSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            bottomBar.topAnchor.constraint(equalTo: panelSeparator.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: controlContainer.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func setupBottomBar() {
        var tagCfg = UIButton.Configuration.filled()
        tagCfg.cornerStyle = .capsule
        tagCfg.baseBackgroundColor = DayPinDesign.accent.withAlphaComponent(0.12)
        tagCfg.baseForegroundColor = DayPinDesign.accent
        tagCfg.image = UIImage(systemName: "tag.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        tagCfg.imagePadding = 5
        tagCfg.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        tagPill.configuration = tagCfg
        refreshTagPill()
        tagPill.addAction(UIAction { [weak self] _ in self?.toggleTagPanel() }, for: .touchUpInside)
        tagPill.translatesAutoresizingMaskIntoConstraints = false

        let aaCfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        aaButton.setImage(UIImage(systemName: "textformat", withConfiguration: aaCfg), for: .normal)
        aaButton.tintColor = .secondaryLabel
        aaButton.addAction(UIAction { [weak self] _ in self?.toggleFormattingStrip() }, for: .touchUpInside)
        aaButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.addSubview(tagPill)
        bottomBar.addSubview(aaButton)

        NSLayoutConstraint.activate([
            tagPill.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            tagPill.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            aaButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            aaButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])

        tagsInputView.onTagsChanged = { [weak self] _ in self?.refreshTagPill() }
    }

    // MARK: - Fill content

    private func fillContent() {
        if let card {
            // Build attributed string: title (bold 24pt) + newline + body
            let mas = NSMutableAttributedString()
            mas.append(NSAttributedString(string: card.title, attributes: titleTypingAttrs()))

            let hasBody: Bool
            if let attributed = card.attributedComment, attributed.length > 0 {
                mas.append(NSAttributedString(string: "\n", attributes: bodyTypingAttrs()))
                let body = attributed.applying(baseColor: .label, baseFont: bodyFont())
                mas.append(body)
                hasBody = true
            } else if !card.comment.isEmpty {
                mas.append(NSAttributedString(string: "\n" + card.comment, attributes: bodyTypingAttrs()))
                hasBody = true
            } else {
                hasBody = false
            }

            noteTextView.attributedText = mas
            _ = hasBody
            notePlaceholder.isHidden = true
            tagsInputView.tagIDs = card.tagIDs
            refreshTagPill()
        } else {
            // New note - empty, show placeholder
            noteTextView.text = ""
            noteTextView.typingAttributes = titleTypingAttrs()
            notePlaceholder.isHidden = false
        }
    }

    // MARK: - Tag pill

    private func refreshTagPill() {
        let ids = tagsInputView.selectedTagIDs
        var cfg = tagPill.configuration ?? UIButton.Configuration.filled()
        cfg.title = ids.isEmpty ? L10n.addTag : "\(ids.count)"
        cfg.baseBackgroundColor = ids.isEmpty
            ? DayPinDesign.accent.withAlphaComponent(0.12)
            : DayPinDesign.accent.withAlphaComponent(0.20)
        tagPill.configuration = cfg
    }

    // MARK: - Toggle panels

    private func toggleFormattingStrip() {
        stripVisible.toggle()
        if stripVisible { tagPanelVisible = false }
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseInOut) {
            self.stripHeightConstraint.constant = self.stripVisible ? 44 : 0
            self.tagPanelHeightConstraint.constant = self.tagPanelVisible ? 52 : 0
            self.aaButton.tintColor = self.stripVisible ? DayPinDesign.accent : .secondaryLabel
            self.view.layoutIfNeeded()
        }
        if stripVisible { noteTextView.becomeFirstResponder() }
    }

    private func toggleTagPanel() {
        tagPanelVisible.toggle()
        if tagPanelVisible { stripVisible = false }
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseInOut) {
            self.tagPanelHeightConstraint.constant = self.tagPanelVisible ? 52 : 0
            self.stripHeightConstraint.constant = self.stripVisible ? 44 : 0
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Font helpers

    private func titleFont() -> UIFont { .inter(ofSize: 24, weight: .bold) }
    private func bodyFont() -> UIFont { .inter(ofSize: 16, weight: .regular) }

    private func titleTypingAttrs() -> [NSAttributedString.Key: Any] {
        [.font: titleFont(), .foregroundColor: UIColor.label]
    }
    private func bodyTypingAttrs() -> [NSAttributedString.Key: Any] {
        [.font: bodyFont(), .foregroundColor: UIColor.label]
    }

    // Whether the cursor is inside the first paragraph (title line)
    private func cursorIsOnFirstLine() -> Bool {
        let ns = noteTextView.text as NSString
        guard ns.length > 0 else { return true }
        let cursorPos = noteTextView.selectedRange.location
        let firstParaRange = ns.paragraphRange(for: NSRange(location: 0, length: 0))
        // Cursor is on first line if it is within or right after the first paragraph
        return cursorPos <= firstParaRange.location + firstParaRange.length
    }

    // Re-apply title styling to the first paragraph (keeps bold even after paste)
    private func enforceFirstLineStyle() {
        guard let text = noteTextView.text, !text.isEmpty else { return }
        let ns = text as NSString
        let firstParaRange = ns.paragraphRange(for: NSRange(location: 0, length: 0))
        // Only the title text itself (without trailing newline)
        let titleRange = NSRange(location: firstParaRange.location,
                                 length: max(0, firstParaRange.length - (text.hasPrefix("\n") ? 0 : (ns.substring(with: firstParaRange).hasSuffix("\n") ? 1 : 0))))
        let mas = NSMutableAttributedString(attributedString: noteTextView.attributedText)
        mas.addAttribute(.font, value: titleFont(), range: titleRange)
        let sel = noteTextView.selectedRange
        noteTextView.attributedText = mas
        noteTextView.selectedRange = NSRange(location: min(sel.location, mas.length), length: 0)
    }

    // MARK: - Formatting

    private func applyFormat(_ action: NoteFormattingStrip.Action) {
        if case .dismissKeyboard = action {
            view.endEditing(true)
            stripVisible = false
            UIView.animate(withDuration: 0.22) {
                self.stripHeightConstraint.constant = 0
                self.aaButton.tintColor = .secondaryLabel
                self.view.layoutIfNeeded()
            }
            return
        }

        guard noteTextView.isFirstResponder else { return }

        // Don't apply body formatting to the title line
        let onTitle = cursorIsOnFirstLine()

        switch action {
        case .listBullet:
            if !onTitle { toggleListPrefix("• "); formattingStrip.updateState(for: noteTextView) }
            return
        case .listNumbered:
            if !onTitle { toggleListPrefix(nil, numbered: true); formattingStrip.updateState(for: noteTextView) }
            return
        case .listDash:
            if !onTitle { toggleListPrefix("- "); formattingStrip.updateState(for: noteTextView) }
            return
        default: break
        }

        let range = noteTextView.selectedRange
        if range.length == 0 {
            applyToTypingAttributes(action)
            formattingStrip.updateState(for: noteTextView)
            return
        }

        let mas = NSMutableAttributedString(attributedString: noteTextView.attributedText)
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

        let sel = noteTextView.selectedRange
        noteTextView.attributedText = mas
        noteTextView.selectedRange = sel
        if sel.location > 0, let attr = noteTextView.attributedText {
            let idx = min(sel.location, attr.length) - 1
            var attrs = attr.attributes(at: max(0, idx), effectiveRange: nil)
            attrs[.foregroundColor] = UIColor.label
            noteTextView.typingAttributes = attrs
        }
        enforceFirstLineStyle()
        formattingStrip.updateState(for: noteTextView)
    }

    private func toggleListPrefix(_ prefix: String?, numbered: Bool = false) {
        guard let text = noteTextView.text else { return }
        let ns = text as NSString
        let pos = noteTextView.selectedRange.location
        let paraRange = ns.paragraphRange(for: NSRange(location: min(pos, max(0, ns.length - 1)), length: 0))
        let para = ns.substring(with: paraRange)

        let existing: String?
        if para.hasPrefix("• ") { existing = "• " }
        else if para.hasPrefix("- ") { existing = "- " }
        else if let n = formattingStrip.numberedListPrefix(in: para) { existing = "\(n). " }
        else { existing = nil }

        let mas = NSMutableAttributedString(attributedString: noteTextView.attributedText)
        let insertAt = paraRange.location

        if let ex = existing {
            if insertAt + ex.count <= mas.length {
                mas.deleteCharacters(in: NSRange(location: insertAt, length: ex.count))
            }
            let want: String?
            if numbered { want = ex.first?.isNumber == true ? nil : "1. " }
            else { want = (ex == prefix) ? nil : prefix }
            if let w = want { mas.insert(NSAttributedString(string: w, attributes: bodyTypingAttrs()), at: insertAt) }
        } else {
            let newPrefix = numbered ? "1. " : (prefix ?? "• ")
            mas.insert(NSAttributedString(string: newPrefix, attributes: bodyTypingAttrs()), at: insertAt)
        }

        let sel = noteTextView.selectedRange
        noteTextView.attributedText = mas
        noteTextView.selectedRange = NSRange(location: min(sel.location, mas.length), length: 0)
    }

    private func applyToTypingAttributes(_ action: NoteFormattingStrip.Action) {
        var attrs = noteTextView.typingAttributes
        let font = attrs[.font] as? UIFont ?? bodyFont()
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
            attrs[.font] = isHeading ? UIFont.inter(ofSize: 16, weight: .regular) : UIFont.inter(ofSize: 22, weight: .bold)
        case .fontSmaller:
            attrs[.font] = UIFont(descriptor: font.fontDescriptor, size: max(10, font.pointSize - 2))
        case .fontLarger:
            attrs[.font] = UIFont(descriptor: font.fontDescriptor, size: min(36, font.pointSize + 2))
        default: break
        }
        attrs[.foregroundColor] = UIColor.label
        noteTextView.typingAttributes = attrs
    }

    // MARK: - Save logic

    private func buildAndSave() {
        guard let attrText = noteTextView.attributedText, attrText.length > 0 else { return }
        let fullText = attrText.string
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let ns = fullText as NSString
        let firstParaRange = ns.paragraphRange(for: NSRange(location: 0, length: 0))
        var rawTitle = ns.substring(with: firstParaRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Body starts after the first paragraph
        let bodyStart = firstParaRange.location + firstParaRange.length
        let bodyAttr: NSAttributedString?
        if bodyStart < attrText.length {
            bodyAttr = attrText.attributedSubstring(from: NSRange(location: bodyStart, length: attrText.length - bodyStart))
        } else {
            bodyAttr = nil
        }

        if rawTitle.isEmpty, let body = bodyAttr?.string {
            let first = body.components(separatedBy: .newlines)
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
                .trimmingCharacters(in: .whitespaces) ?? L10n.untitledNote
            rawTitle = first.count > 60 ? String(first.prefix(57)) + "…" : first
        }
        if rawTitle.isEmpty { rawTitle = L10n.untitledNote }

        let saved = card ?? TextCard(title: rawTitle, dayDate: dayDate)
        saved.title = rawTitle
        saved.tagIDs = tagsInputView.selectedTagIDs

        if let body = bodyAttr, body.length > 0 {
            saved.setAttributedComment(body)
        } else {
            saved.comment = ""
            saved.rtfData = nil
        }

        onSave?(saved)
    }

    // MARK: - Actions

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let text = noteTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { noteTextView.shake(); return }
        buildAndSave()
        dismiss(animated: true)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension TextCardEditorViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        buildAndSave()
    }
}

// MARK: - UITextViewDelegate

extension TextCardEditorViewController: UITextViewDelegate {

    func textViewDidBeginEditing(_ textView: UITextView) {
        formattingStrip.updateState(for: textView)
    }

    func textViewDidChange(_ textView: UITextView) {
        notePlaceholder.isHidden = !textView.text.isEmpty
        formattingStrip.updateState(for: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        // Adjust typing attributes based on whether cursor is on title or body line
        let onTitle = cursorIsOnFirstLine()
        if onTitle {
            // Preserve bold for title line
            var attrs = textView.typingAttributes
            attrs[.font] = titleFont()
            textView.typingAttributes = attrs
        }
        formattingStrip.updateState(for: textView)
    }

    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        guard text == "\n" else { return true }

        let ns = textView.text as NSString
        let pos = range.location
        // Check if Enter is pressed while on the first line
        let firstParaRange = ns.paragraphRange(for: NSRange(location: 0, length: 0))
        let isOnFirstLine = pos <= firstParaRange.location + firstParaRange.length

        if isOnFirstLine {
            // Enforce first-line style then insert newline with body attrs
            let mas = NSMutableAttributedString(attributedString: textView.attributedText)
            let newline = NSAttributedString(string: "\n", attributes: bodyTypingAttrs())
            mas.replaceCharacters(in: range, with: newline)
            // Ensure title line stays bold
            mas.addAttribute(.font, value: titleFont(), range: firstParaRange)
            textView.attributedText = mas
            textView.selectedRange = NSRange(location: range.location + 1, length: 0)
            textView.typingAttributes = bodyTypingAttrs()
            notePlaceholder.isHidden = true
            formattingStrip.updateState(for: textView)
            return false
        }

        // For body lines — handle list continuation
        let paraRange = ns.paragraphRange(for: NSRange(location: min(pos, max(0, ns.length - 1)), length: 0))
        let para = ns.substring(with: paraRange)

        let prefix: String?
        if para.hasPrefix("• ") {
            let content = para.dropFirst(2).trimmingCharacters(in: .newlines)
            prefix = content.isEmpty ? nil : "• "
        } else if para.hasPrefix("- ") {
            let content = para.dropFirst(2).trimmingCharacters(in: .newlines)
            prefix = content.isEmpty ? nil : "- "
        } else if let n = formattingStrip.numberedListPrefix(in: para) {
            let pfx = "\(n). "
            let content = para.dropFirst(pfx.count).trimmingCharacters(in: .newlines)
            prefix = content.isEmpty ? nil : "\(n + 1). "
        } else {
            return true
        }

        let mas = NSMutableAttributedString(attributedString: textView.attributedText)
        if let p = prefix {
            let ins = NSAttributedString(string: "\n" + p, attributes: bodyTypingAttrs())
            mas.replaceCharacters(in: range, with: ins)
            textView.attributedText = mas
            textView.selectedRange = NSRange(location: range.location + ins.length, length: 0)
        } else {
            let prefixLen: Int
            if para.hasPrefix("• ") || para.hasPrefix("- ") { prefixLen = 2 }
            else if let n = formattingStrip.numberedListPrefix(in: para) { prefixLen = "\(n). ".count }
            else { prefixLen = 0 }
            if prefixLen > 0 {
                mas.deleteCharacters(in: NSRange(location: paraRange.location, length: prefixLen))
            }
            textView.attributedText = mas
            textView.selectedRange = NSRange(location: paraRange.location, length: 0)
        }

        formattingStrip.updateState(for: textView)
        return false
    }
}

// MARK: - NSMutableAttributedString helpers

extension NSMutableAttributedString {
    func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in range: NSRange, baseSize: CGFloat) {
        var allHave = true
        enumerateAttribute(.font, in: range) { val, _, _ in
            guard let f = val as? UIFont else { allHave = false; return }
            if !f.fontDescriptor.symbolicTraits.contains(trait) { allHave = false }
        }
        enumerateAttribute(.font, in: range) { val, r, _ in
            let base = (val as? UIFont) ?? .inter(ofSize: baseSize)
            var traits = base.fontDescriptor.symbolicTraits
            if allHave { traits.remove(trait) } else { traits.insert(trait) }
            if let desc = base.fontDescriptor.withSymbolicTraits(traits) {
                addAttribute(.font, value: UIFont(descriptor: desc, size: 0), range: r)
            }
        }
    }

    func toggleUnderline(in range: NSRange) {
        var allHave = true
        enumerateAttribute(.underlineStyle, in: range) { val, _, _ in
            if (val as? Int) == nil || (val as? Int) == 0 { allHave = false }
        }
        addAttribute(.underlineStyle, value: allHave ? 0 : NSUnderlineStyle.single.rawValue, range: range)
    }

    func toggleStrikethrough(in range: NSRange) {
        var allHave = true
        enumerateAttribute(.strikethroughStyle, in: range) { val, _, _ in
            if (val as? Int) == nil || (val as? Int) == 0 { allHave = false }
        }
        addAttribute(.strikethroughStyle, value: allHave ? 0 : NSUnderlineStyle.single.rawValue, range: range)
    }

    func adjustFontSize(by delta: CGFloat, in range: NSRange, min minS: CGFloat = 10, max maxS: CGFloat = 36) {
        enumerateAttribute(.font, in: range) { val, r, _ in
            let base = (val as? UIFont) ?? .inter(ofSize: 16)
            let sz = Swift.min(Swift.max(base.pointSize + delta, minS), maxS)
            addAttribute(.font, value: UIFont(descriptor: base.fontDescriptor, size: sz), range: r)
        }
    }

    func toggleHeading(in range: NSRange) {
        var allHeading = true
        enumerateAttribute(.font, in: range) { val, _, _ in
            if let f = val as? UIFont, f.pointSize < 20 { allHeading = false }
        }
        addAttribute(.font, value: allHeading
            ? UIFont.inter(ofSize: 16, weight: .regular)
            : UIFont.inter(ofSize: 22, weight: .bold),
            range: range)
    }
}
