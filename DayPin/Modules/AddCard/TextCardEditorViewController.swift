import UIKit

final class TextCardEditorViewController: UIViewController {

    var onSave: ((TextCard) -> Void)?

    private let card: TextCard?
    private let dayDate: Date

    private let titleField           = UITextField()
    private let commentTextView      = UITextView()
    private let commentPlaceholder   = UILabel()
    private let formattingBar        = FormattingToolbar()
    private let tagsInputView        = TagsInputView()

    init(card: TextCard?, dayDate: Date) {
        self.card    = card
        self.dayDate = dayDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = card == nil ? L10n.newNote : L10n.edit
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupUI()
        fillIfEditing()
        addKeyboardDismissGesture()
        observeKeyboard()
        observeNotifications()

        formattingBar.onAction = { [weak self] action in self?.applyFormat(action) }
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
        title = card == nil ? L10n.newNote : L10n.edit
        navigationItem.leftBarButtonItem?.title  = L10n.cancel
        navigationItem.rightBarButtonItem?.title = L10n.save
        titleField.placeholder       = L10n.titleOptionalPlaceholder
        commentPlaceholder.text      = L10n.commentPlaceholder
    }

    @objc private func onColorSchemeChanged() {
        navigationItem.rightBarButtonItem?.tintColor = DayPinDesign.accent
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        commentTextView.becomeFirstResponder()
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem  = UIBarButtonItem(title: L10n.cancel, style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.save,   style: .done,  target: self, action: #selector(save))
    }

    // MARK: - UI

    private func setupUI() {
        let formCard = GlassCardView(style: .card)
        formCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formCard)

        titleField.placeholder = L10n.titleOptionalPlaceholder
        titleField.font = .inter(ofSize: 15, weight: .regular)
        titleField.borderStyle = .none
        titleField.returnKeyType = .next
        titleField.delegate = self
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        commentTextView.font = .inter(ofSize: 15)
        commentTextView.backgroundColor = .clear
        commentTextView.isScrollEnabled = true
        commentTextView.textContainer.lineBreakMode = .byWordWrapping
        commentTextView.allowsEditingTextAttributes = true
        commentTextView.translatesAutoresizingMaskIntoConstraints = false
        commentTextView.delegate = self
        commentTextView.inputAccessoryView = formattingBar

        commentPlaceholder.text = L10n.commentPlaceholder
        commentPlaceholder.font = .inter(ofSize: 15)
        commentPlaceholder.textColor = .placeholderText
        commentPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        commentTextView.addSubview(commentPlaceholder)

        let tagsDivider = UIView()
        tagsDivider.backgroundColor = .separator
        tagsDivider.translatesAutoresizingMaskIntoConstraints = false

        tagsInputView.translatesAutoresizingMaskIntoConstraints = false

        formCard.stackView.addArrangedSubview(titleField)
        formCard.stackView.addArrangedSubview(divider)
        formCard.stackView.addArrangedSubview(commentTextView)
        formCard.stackView.addArrangedSubview(tagsDivider)
        formCard.stackView.addArrangedSubview(tagsInputView)

        NSLayoutConstraint.activate([
            formCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            formCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            formCard.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -12),

            titleField.heightAnchor.constraint(equalToConstant: 44),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            commentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            tagsDivider.heightAnchor.constraint(equalToConstant: 0.5),
            tagsInputView.heightAnchor.constraint(equalToConstant: 36),

            commentPlaceholder.topAnchor.constraint(equalTo: commentTextView.topAnchor, constant: 8),
            commentPlaceholder.leadingAnchor.constraint(equalTo: commentTextView.leadingAnchor, constant: 5)
        ])
    }

    private func fillIfEditing() {
        guard let card else { return }
        titleField.text = card.title
        if let attributed = card.attributedComment {
            commentTextView.attributedText = attributed.applying(baseFont: .inter(ofSize: 15))
        } else {
            commentTextView.text = card.comment
        }
        commentPlaceholder.isHidden = !commentTextView.text.isEmpty
        tagsInputView.tagIDs = card.tagIDs
    }

    // MARK: - Formatting

    private func applyFormat(_ action: FormattingToolbar.Action) {
        guard commentTextView.isFirstResponder else { return }

        if case .dismissKeyboard = action {
            commentTextView.resignFirstResponder(); return
        }

        // List actions always operate on the paragraph, not a character range
        switch action {
        case .listBullet:    toggleListPrefix("• ");  formattingBar.updateState(for: commentTextView); return
        case .listNumbered:  toggleListPrefix(nil, numbered: true); formattingBar.updateState(for: commentTextView); return
        case .listDash:      toggleListPrefix("- ");  formattingBar.updateState(for: commentTextView); return
        default: break
        }

        let range = commentTextView.selectedRange

        if range.length == 0 {
            applyToTypingAttributes(action)
            formattingBar.updateState(for: commentTextView)
            return
        }

        let mas = NSMutableAttributedString(attributedString: commentTextView.attributedText)

        switch action {
        case .fontSmaller:   mas.adjustFontSize(by: -2, in: range, min: 10)
        case .fontLarger:    mas.adjustFontSize(by: +2, in: range, max: 36)
        case .bold:          mas.toggleTrait(.traitBold,   in: range, baseSize: 15)
        case .italic:        mas.toggleTrait(.traitItalic, in: range, baseSize: 15)
        case .underline:     mas.toggleUnderline(in: range)
        case .strikethrough: mas.toggleStrikethrough(in: range)
        case .heading:       mas.toggleHeading(in: range)
        default: break
        }

        let sel = commentTextView.selectedRange
        commentTextView.attributedText = mas
        commentTextView.selectedRange  = sel
        if sel.location > 0, let attrText = commentTextView.attributedText {
            let idx = min(sel.location, attrText.length) - 1
            var newAttrs = attrText.attributes(at: max(0, idx), effectiveRange: nil)
            newAttrs[.foregroundColor] = UIColor.label
            commentTextView.typingAttributes = newAttrs
        } else {
            commentTextView.typingAttributes = typingAttrs()
        }
        formattingBar.updateState(for: commentTextView)
    }

    /// Toggles a list prefix on the current paragraph.
    /// Pass `prefix` for bullet/dash, or `numbered: true` for numbered lists.
    private func toggleListPrefix(_ prefix: String?, numbered: Bool = false) {
        guard let text = commentTextView.text else { return }
        let nsText = text as NSString
        let cursorPos = commentTextView.selectedRange.location
        let paraRange = nsText.paragraphRange(for: NSRange(location: min(cursorPos, max(0, nsText.length - 1)), length: 0))
        let para = nsText.substring(with: paraRange)

        // Detect existing prefix to toggle off
        let existingPrefix: String?
        if para.hasPrefix("• ") { existingPrefix = "• " }
        else if para.hasPrefix("- ") { existingPrefix = "- " }
        else if let n = formattingBar.numberedListPrefix(in: para) { existingPrefix = "\(n). " }
        else { existingPrefix = nil }

        let mas = NSMutableAttributedString(attributedString: commentTextView.attributedText)
        let insertAt = paraRange.location

        if let existing = existingPrefix {
            // Remove existing prefix
            let removeRange = NSRange(location: insertAt, length: existing.count)
            if insertAt + existing.count <= mas.length {
                mas.deleteCharacters(in: removeRange)
            }
            // If toggling to a different type, add the new one
            let wantPrefix: String?
            if numbered {
                wantPrefix = existingPrefix?.first?.isNumber == true ? nil : "1. "
            } else {
                wantPrefix = (existing == prefix) ? nil : prefix
            }
            if let wp = wantPrefix {
                mas.insert(NSAttributedString(string: wp, attributes: typingAttrs()), at: insertAt)
            }
        } else {
            // Add prefix
            let newPrefix: String
            if numbered {
                // Count existing numbered items above to determine next number
                newPrefix = "1. "
            } else {
                newPrefix = prefix ?? "• "
            }
            mas.insert(NSAttributedString(string: newPrefix, attributes: typingAttrs()), at: insertAt)
        }

        let sel = commentTextView.selectedRange
        commentTextView.attributedText = mas
        commentTextView.selectedRange = NSRange(location: min(sel.location, mas.length), length: 0)
    }

    /// Toggles a format on `typingAttributes` (no text selected — applies to future input).
    private func applyToTypingAttributes(_ action: FormattingToolbar.Action) {
        var attrs = commentTextView.typingAttributes
        let font = attrs[.font] as? UIFont ?? .inter(ofSize: 15)

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
                ? UIFont.inter(ofSize: 15, weight: .regular)
                : UIFont.inter(ofSize: 22, weight: .bold)
        case .fontSmaller:
            let sz = max(10, font.pointSize - 2)
            attrs[.font] = UIFont(descriptor: font.fontDescriptor, size: sz)
        case .fontLarger:
            let sz = min(36, font.pointSize + 2)
            attrs[.font] = UIFont(descriptor: font.fontDescriptor, size: sz)
        default: break
        }

        attrs[.foregroundColor] = UIColor.label
        commentTextView.typingAttributes = attrs
    }

    private func typingAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.inter(ofSize: 15), .foregroundColor: UIColor.label]
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        // Using UIKeyboardLayoutGuide so formCard bottom constraint handles it automatically.
    }

    // MARK: - Actions

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        var titleText = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bodyText  = commentTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if titleText.isEmpty && bodyText.isEmpty { commentTextView.shake(); return }

        if titleText.isEmpty {
            let firstLine = bodyText
                .components(separatedBy: .newlines)
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
                .trimmingCharacters(in: .whitespaces) ?? L10n.untitledNote
            titleText = firstLine.count > 60 ? String(firstLine.prefix(57)) + "…" : firstLine
        }

        let saved = card ?? TextCard(title: titleText, dayDate: dayDate)
        saved.title  = titleText
        saved.tagIDs = tagsInputView.selectedTagIDs

        let attributed = commentTextView.attributedText ?? NSAttributedString()
        if attributed.length > 0 {
            saved.setAttributedComment(attributed)
        } else {
            saved.comment = commentTextView.text ?? ""
            saved.rtfData = nil
        }

        onSave?(saved)
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension TextCardEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        commentTextView.becomeFirstResponder(); return false
    }
}

// MARK: - UITextViewDelegate

extension TextCardEditorViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n" else { return true }
        let nsText = textView.text as NSString
        let cursorPos = range.location
        let paraRange = nsText.paragraphRange(for: NSRange(location: min(cursorPos, max(0, nsText.length - 1)), length: 0))
        let para = nsText.substring(with: paraRange)

        // Detect list prefix
        let prefix: String?
        if para.hasPrefix("• ") {
            let content = para.dropFirst(2).trimmingCharacters(in: .newlines)
            prefix = content.isEmpty ? nil : "• "    // empty item → end list
        } else if para.hasPrefix("- ") {
            let content = para.dropFirst(2).trimmingCharacters(in: .newlines)
            prefix = content.isEmpty ? nil : "- "
        } else if let n = formattingBar.numberedListPrefix(in: para) {
            let pfx = "\(n). "
            let content = para.dropFirst(pfx.count).trimmingCharacters(in: .newlines)
            if content.isEmpty {
                prefix = nil   // end list
            } else {
                prefix = "\(n + 1). "
            }
        } else {
            return true   // no list → normal newline
        }

        let mas = NSMutableAttributedString(attributedString: textView.attributedText)
        if let p = prefix {
            // Insert newline + next prefix
            let insertion = NSAttributedString(string: "\n" + p, attributes: typingAttrs())
            mas.replaceCharacters(in: range, with: insertion)
            textView.attributedText = mas
            textView.selectedRange = NSRange(location: range.location + insertion.length, length: 0)
        } else {
            // Empty list item → remove the prefix on this line and insert a plain newline
            let prefixLen: Int
            if para.hasPrefix("• ") || para.hasPrefix("- ") { prefixLen = 2 }
            else if let n = formattingBar.numberedListPrefix(in: para) { prefixLen = "\(n). ".count }
            else { prefixLen = 0 }
            // Delete the prefix characters from the current paragraph start
            if prefixLen > 0 {
                let removeRange = NSRange(location: paraRange.location, length: prefixLen)
                mas.deleteCharacters(in: removeRange)
            }
            textView.attributedText = mas
            let newCursor = paraRange.location + (prefixLen > 0 ? 0 : 0)
            textView.selectedRange = NSRange(location: newCursor, length: 0)
        }

        commentPlaceholder.isHidden = true
        formattingBar.updateState(for: textView)
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        commentPlaceholder.isHidden = !textView.text.isEmpty
    }
    func textViewDidChangeSelection(_ textView: UITextView) {
        formattingBar.updateState(for: textView)
    }
}

// MARK: - NSAttributedString helpers

private extension NSAttributedString {
    func applying(baseFont: UIFont) -> NSAttributedString {
        let mas = NSMutableAttributedString(attributedString: self)
        mas.enumerateAttribute(.font, in: NSRange(location: 0, length: length)) { val, range, _ in
            if val == nil { mas.addAttribute(.font, value: baseFont, range: range) }
        }
        // Apply foreground for dark mode compatibility
        mas.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: length))
        return mas
    }
}

private extension NSMutableAttributedString {
    func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in range: NSRange, baseSize: CGFloat) {
        var allHaveTrait = true
        enumerateAttribute(.font, in: range) { val, _, _ in
            guard let font = val as? UIFont else { allHaveTrait = false; return }
            if !font.fontDescriptor.symbolicTraits.contains(trait) { allHaveTrait = false }
        }
        enumerateAttribute(.font, in: range) { val, r, _ in
            let base = (val as? UIFont) ?? .inter(ofSize: baseSize)
            var traits = base.fontDescriptor.symbolicTraits
            if allHaveTrait { traits.remove(trait) } else { traits.insert(trait) }
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

    func setFont(_ font: UIFont, in range: NSRange) {
        addAttribute(.font, value: font, range: range)
    }

    func adjustFontSize(by delta: CGFloat, in range: NSRange, min minSize: CGFloat = 10, max maxSize: CGFloat = 36) {
        enumerateAttribute(.font, in: range) { val, r, _ in
            let base = (val as? UIFont) ?? .inter(ofSize: 15)
            let newSize = min(max(base.pointSize + delta, minSize), maxSize)
            let newFont = UIFont(descriptor: base.fontDescriptor, size: newSize)
            addAttribute(.font, value: newFont, range: r)
        }
    }

    func toggleHeading(in range: NSRange) {
        var allHeading = true
        enumerateAttribute(.font, in: range) { val, _, _ in
            if let f = val as? UIFont, f.pointSize < 20 { allHeading = false }
        }
        let targetFont: UIFont = allHeading
            ? .inter(ofSize: 15, weight: .regular)
            : .inter(ofSize: 22, weight: .bold)
        addAttribute(.font, value: targetFont, range: range)
    }
}

// MARK: - FormattingToolbar

final class FormattingToolbar: UIInputView {

    enum Action {
        case bold, italic, underline, strikethrough
        case heading
        case listBullet, listNumbered, listDash
        case fontSmaller, fontLarger
        case dismissKeyboard
    }

    var onAction: ((Action) -> Void)?

    // Indices 0-3: bold, italic, underline, strikethrough
    private var formatButtons: [UIButton] = []
    private let fontSizeLabel = UILabel()
    private var headingBtn: UIButton?
    private var listBtn: UIButton?

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 52),
                   inputViewStyle: .keyboard)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.16, alpha: 1)
                : UIColor(white: 0.86, alpha: 1)
        }

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        let closeBtn = makeToolButton(systemName: "keyboard.chevron.compact.down", action: .dismissKeyboard, isFormat: false)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeBtn)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -4),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            closeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            closeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 40),
            closeBtn.heightAnchor.constraint(equalToConstant: 36)
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        // Font-size group: [A−] [15] [A+]
        stack.addArrangedSubview(makeToolButton(systemName: "textformat.size.smaller", action: .fontSmaller, isFormat: false))

        fontSizeLabel.text = "15"
        fontSizeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        fontSizeLabel.textAlignment = .center
        fontSizeLabel.textColor = .label
        fontSizeLabel.widthAnchor.constraint(equalToConstant: 26).isActive = true
        stack.addArrangedSubview(fontSizeLabel)

        stack.addArrangedSubview(makeToolButton(systemName: "textformat.size.larger", action: .fontLarger, isFormat: false))
        stack.addArrangedSubview(makeSeparator())

        // Inline formatting: B I U S
        let formatSpecs: [(String, Action)] = [
            ("bold",          .bold),
            ("italic",        .italic),
            ("underline",     .underline),
            ("strikethrough", .strikethrough)
        ]
        for (icon, action) in formatSpecs {
            let btn = makeToolButton(systemName: icon, action: action, isFormat: true)
            stack.addArrangedSubview(btn)
            formatButtons.append(btn)
        }
        stack.addArrangedSubview(makeSeparator())

        // Paragraph: [H] [list▾]
        let hBtn = makeToolButton(systemName: "h.square", action: .heading, isFormat: true)
        headingBtn = hBtn
        stack.addArrangedSubview(hBtn)

        let lBtn = makeListButton()
        listBtn = lBtn
        stack.addArrangedSubview(lBtn)
    }

    // MARK: List button with menu

    private func makeListButton() -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        btn.setImage(UIImage(systemName: "list.bullet", withConfiguration: cfg), for: .normal)
        btn.tintColor = .label
        btn.layer.cornerRadius = 7
        btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        btn.showsMenuAsPrimaryAction = true

        let bulletAction = UIAction(title: L10n.listBullet,   image: UIImage(systemName: "list.bullet"))  { [weak self] _ in self?.onAction?(.listBullet) }
        let numberedAction = UIAction(title: L10n.listNumbered, image: UIImage(systemName: "list.number")) { [weak self] _ in self?.onAction?(.listNumbered) }
        let dashAction = UIAction(title: L10n.listDash,      image: UIImage(systemName: "list.dash"))   { [weak self] _ in self?.onAction?(.listDash) }
        btn.menu = UIMenu(children: [bulletAction, numberedAction, dashAction])
        return btn
    }

    // MARK: Helpers

    private func makeToolButton(systemName: String, action: Action, isFormat: Bool) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        btn.tintColor = .label
        btn.layer.cornerRadius = 7
        btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        btn.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        return btn
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.15)
                : UIColor(white: 0, alpha: 0.2)
        }
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 20).isActive = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    // MARK: State update

    func updateState(for textView: UITextView) {
        let activeColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.25)
                : UIColor(white: 0, alpha: 0.15)
        }

        let range = textView.selectedRange

        // Font size label — use cursor/selection start character or typing attrs
        let displayFont: UIFont
        if range.length > 0, let attrText = textView.attributedText, attrText.length > 0 {
            let idx = min(range.location, attrText.length - 1)
            displayFont = (attrText.attribute(.font, at: idx, effectiveRange: nil) as? UIFont)
                ?? .inter(ofSize: 15)
        } else {
            displayFont = (textView.typingAttributes[.font] as? UIFont) ?? .inter(ofSize: 15)
        }
        fontSizeLabel.text = "\(Int(displayFont.pointSize))"

        // Inline formatting
        if range.length > 0, let attrText = textView.attributedText {
            func allHaveTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> Bool {
                var ok = true
                attrText.enumerateAttribute(.font, in: range) { val, _, _ in
                    if let f = val as? UIFont, !f.fontDescriptor.symbolicTraits.contains(trait) { ok = false }
                }
                return ok
            }
            func allHaveInt(_ key: NSAttributedString.Key) -> Bool {
                var ok = true
                attrText.enumerateAttribute(key, in: range) { val, _, _ in
                    if (val as? Int) == nil || (val as? Int) == 0 { ok = false }
                }
                return ok
            }
            formatButtons[0].backgroundColor = allHaveTrait(.traitBold)       ? activeColor : .clear
            formatButtons[1].backgroundColor = allHaveTrait(.traitItalic)      ? activeColor : .clear
            formatButtons[2].backgroundColor = allHaveInt(.underlineStyle)     ? activeColor : .clear
            formatButtons[3].backgroundColor = allHaveInt(.strikethroughStyle) ? activeColor : .clear

            // Heading active state — check if font size ≥ 20
            headingBtn?.backgroundColor = displayFont.pointSize >= 20 ? activeColor : .clear
        } else {
            let typing = textView.typingAttributes
            let font   = typing[.font] as? UIFont ?? .inter(ofSize: 15)
            formatButtons[0].backgroundColor = font.fontDescriptor.symbolicTraits.contains(.traitBold)   ? activeColor : .clear
            formatButtons[1].backgroundColor = font.fontDescriptor.symbolicTraits.contains(.traitItalic) ? activeColor : .clear
            formatButtons[2].backgroundColor = (typing[.underlineStyle]     as? Int ?? 0) != 0 ? activeColor : .clear
            formatButtons[3].backgroundColor = (typing[.strikethroughStyle] as? Int ?? 0) != 0 ? activeColor : .clear
            headingBtn?.backgroundColor = font.pointSize >= 20 ? activeColor : .clear
        }

        // List button — detect list prefix of current paragraph
        guard let text = textView.text else { return }
        let nsText = text as NSString
        let cursorPos = range.location
        if cursorPos <= nsText.length {
            let paraRange = nsText.paragraphRange(for: NSRange(location: cursorPos, length: 0))
            let para = nsText.substring(with: paraRange)
            let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if para.hasPrefix("• ") {
                listBtn?.setImage(UIImage(systemName: "list.bullet", withConfiguration: cfg), for: .normal)
                listBtn?.backgroundColor = activeColor
            } else if para.hasPrefix("- ") {
                listBtn?.setImage(UIImage(systemName: "list.dash", withConfiguration: cfg), for: .normal)
                listBtn?.backgroundColor = activeColor
            } else if let _ = numberedListPrefix(in: para) {
                listBtn?.setImage(UIImage(systemName: "list.number", withConfiguration: cfg), for: .normal)
                listBtn?.backgroundColor = activeColor
            } else {
                listBtn?.setImage(UIImage(systemName: "list.bullet", withConfiguration: cfg), for: .normal)
                listBtn?.backgroundColor = .clear
            }
        }
    }

    // Detects "N. " at the start of a paragraph, returns the number.
    func numberedListPrefix(in paragraph: String) -> Int? {
        let trimmed = paragraph
        var i = trimmed.startIndex
        var digits = ""
        while i < trimmed.endIndex, trimmed[i].isNumber {
            digits.append(trimmed[i])
            i = trimmed.index(after: i)
        }
        guard !digits.isEmpty,
              i < trimmed.endIndex, trimmed[i] == ".",
              trimmed.index(after: i) < trimmed.endIndex,
              trimmed[trimmed.index(after: i)] == " " else { return nil }
        return Int(digits)
    }
}
