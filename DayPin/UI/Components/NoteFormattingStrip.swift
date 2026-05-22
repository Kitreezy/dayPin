import UIKit

// Shared horizontal formatting strip used by TextCardEditorViewController and CardDetailViewController.
// It is a plain UIView (NOT UIInputView) so it can be animated independently of the keyboard.

final class NoteFormattingStrip: UIView {

    enum Action {
        case bold, italic, underline, strikethrough
        case heading
        case listBullet, listNumbered, listDash
        case fontSmaller, fontLarger
        case dismissKeyboard
    }

    var onAction: ((Action) -> Void)?

    private var formatButtons: [UIButton] = []
    private let fontSizeLabel = UILabel()
    private var headingBtn: UIButton?
    private var listBtn: UIButton?

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let tint = UIView()
    private let topSep = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        // Blur fill
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Dynamic tint overlay
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.04)
                : UIColor(white: 1.0, alpha: 0.50)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        // Top separator
        topSep.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        topSep.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(topSep)
        NSLayoutConstraint.activate([
            topSep.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            topSep.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            topSep.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            topSep.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        // Dismiss keyboard button (pinned to right)
        let closeBtn = makeToolButton(systemName: "keyboard.chevron.compact.down", action: .dismissKeyboard)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(closeBtn)

        // Scrollable buttons row
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(scroll)

        NSLayoutConstraint.activate([
            closeBtn.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -10),
            closeBtn.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 38),
            closeBtn.heightAnchor.constraint(equalToConstant: 34),

            scroll.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 5),
            scroll.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -4),
            scroll.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -5)
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

        // Font size controls
        stack.addArrangedSubview(makeToolButton(systemName: "textformat.size.smaller", action: .fontSmaller))

        fontSizeLabel.text = "16"
        fontSizeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        fontSizeLabel.textAlignment = .center
        fontSizeLabel.textColor = .label
        fontSizeLabel.widthAnchor.constraint(equalToConstant: 26).isActive = true
        stack.addArrangedSubview(fontSizeLabel)

        stack.addArrangedSubview(makeToolButton(systemName: "textformat.size.larger", action: .fontLarger))
        stack.addArrangedSubview(makeDivider())

        // Bold / Italic / Underline / Strikethrough
        let specs: [(String, Action)] = [
            ("bold", .bold),
            ("italic", .italic),
            ("underline", .underline),
            ("strikethrough", .strikethrough)
        ]
        for (icon, action) in specs {
            let btn = makeToolButton(systemName: icon, action: action)
            stack.addArrangedSubview(btn)
            formatButtons.append(btn)
        }
        stack.addArrangedSubview(makeDivider())

        // Heading
        let hBtn = makeToolButton(systemName: "h.square", action: .heading)
        headingBtn = hBtn
        stack.addArrangedSubview(hBtn)

        // List (with sub-menu)
        let lBtn = makeListButton()
        listBtn = lBtn
        stack.addArrangedSubview(lBtn)
    }

    // MARK: - List button

    private func makeListButton() -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        btn.setImage(UIImage(systemName: "list.bullet", withConfiguration: cfg), for: .normal)
        btn.tintColor = .label
        btn.layer.cornerRadius = 7
        btn.widthAnchor.constraint(equalToConstant: 38).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
        btn.showsMenuAsPrimaryAction = true
        btn.menu = UIMenu(children: [
            UIAction(title: L10n.listBullet,   image: UIImage(systemName: "list.bullet")) { [weak self] _ in self?.onAction?(.listBullet) },
            UIAction(title: L10n.listNumbered, image: UIImage(systemName: "list.number")) { [weak self] _ in self?.onAction?(.listNumbered) },
            UIAction(title: L10n.listDash,     image: UIImage(systemName: "list.dash"))   { [weak self] _ in self?.onAction?(.listDash) }
        ])
        return btn
    }

    // MARK: - Helpers

    private func makeToolButton(systemName: String, action: Action) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        btn.tintColor = .label
        btn.layer.cornerRadius = 7
        btn.widthAnchor.constraint(equalToConstant: 38).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 34).isActive = true
        btn.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        return btn
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        v.widthAnchor.constraint(equalToConstant: 0.5).isActive = true
        v.heightAnchor.constraint(equalToConstant: 20).isActive = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    // MARK: - State

    func updateState(for textView: UITextView) {
        let accent = DayPinDesign.accent.withAlphaComponent(0.15)
        let range = textView.selectedRange

        let displayFont: UIFont
        if range.length > 0, let attr = textView.attributedText, attr.length > 0 {
            let idx = min(range.location, attr.length - 1)
            displayFont = (attr.attribute(.font, at: idx, effectiveRange: nil) as? UIFont) ?? .inter(ofSize: 16)
        } else {
            displayFont = (textView.typingAttributes[.font] as? UIFont) ?? .inter(ofSize: 16)
        }
        fontSizeLabel.text = "\(Int(displayFont.pointSize))"

        if range.length > 0, let attr = textView.attributedText {
            func trait(_ t: UIFontDescriptor.SymbolicTraits) -> Bool {
                var all = true
                attr.enumerateAttribute(.font, in: range) { v, _, _ in
                    if let f = v as? UIFont, !f.fontDescriptor.symbolicTraits.contains(t) { all = false }
                }
                return all
            }
            func intAttr(_ k: NSAttributedString.Key) -> Bool {
                var all = true
                attr.enumerateAttribute(k, in: range) { v, _, _ in
                    if (v as? Int) == nil || (v as? Int) == 0 { all = false }
                }
                return all
            }
            formatButtons[0].backgroundColor = trait(.traitBold)           ? accent : .clear
            formatButtons[1].backgroundColor = trait(.traitItalic)         ? accent : .clear
            formatButtons[2].backgroundColor = intAttr(.underlineStyle)    ? accent : .clear
            formatButtons[3].backgroundColor = intAttr(.strikethroughStyle) ? accent : .clear
            headingBtn?.backgroundColor = displayFont.pointSize >= 20      ? accent : .clear
        } else {
            let typing = textView.typingAttributes
            let font = typing[.font] as? UIFont ?? .inter(ofSize: 16)
            formatButtons[0].backgroundColor = font.fontDescriptor.symbolicTraits.contains(.traitBold)   ? accent : .clear
            formatButtons[1].backgroundColor = font.fontDescriptor.symbolicTraits.contains(.traitItalic) ? accent : .clear
            formatButtons[2].backgroundColor = (typing[.underlineStyle]      as? Int ?? 0) != 0 ? accent : .clear
            formatButtons[3].backgroundColor = (typing[.strikethroughStyle]  as? Int ?? 0) != 0 ? accent : .clear
            headingBtn?.backgroundColor = font.pointSize >= 20 ? accent : .clear
        }

        guard let text = textView.text else { return }
        let ns = text as NSString
        let pos = min(range.location, ns.length)
        let para = ns.substring(with: ns.paragraphRange(for: NSRange(location: pos, length: 0)))
        let iCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if para.hasPrefix("• ") {
            listBtn?.setImage(UIImage(systemName: "list.bullet", withConfiguration: iCfg), for: .normal)
            listBtn?.backgroundColor = accent
        } else if para.hasPrefix("- ") {
            listBtn?.setImage(UIImage(systemName: "list.dash", withConfiguration: iCfg), for: .normal)
            listBtn?.backgroundColor = accent
        } else if numberedListPrefix(in: para) != nil {
            listBtn?.setImage(UIImage(systemName: "list.number", withConfiguration: iCfg), for: .normal)
            listBtn?.backgroundColor = accent
        } else {
            listBtn?.setImage(UIImage(systemName: "list.bullet", withConfiguration: iCfg), for: .normal)
            listBtn?.backgroundColor = .clear
        }
    }

    func numberedListPrefix(in para: String) -> Int? {
        var i = para.startIndex
        var digits = ""
        while i < para.endIndex, para[i].isNumber {
            digits.append(para[i])
            i = para.index(after: i)
        }
        guard !digits.isEmpty,
              i < para.endIndex, para[i] == ".",
              para.index(after: i) < para.endIndex,
              para[para.index(after: i)] == " " else { return nil }
        return Int(digits)
    }
}
