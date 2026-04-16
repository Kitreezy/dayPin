import UIKit
import LinkPresentation

final class LinkCardEditorViewController: UIViewController {

    var onSave: ((LinkCard) -> Void)?

    private let card: LinkCard?
    private let dayDate: Date

    private let urlField = UITextField()
    private let linksTextView = UITextView()
    private let linksPlaceholder = UILabel()
    private let titleField = UITextField()
    private let commentTextView = UITextView()
    private let commentPlaceholder = UILabel()
    private let previewContainer = UIView()
    private var lpView: LPLinkView?
    private var resolvedURL: URL?

    init(card: LinkCard?, dayDate: Date) {
        self.card = card
        self.dayDate = dayDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = card == nil ? "Новая ссылка" : "Редактировать ссылку"
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupUI()
        fillIfEditing()
        addKeyboardDismissGesture()
    }

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", style: .done, target: self, action: #selector(save))
    }

    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.topAnchor.constraint(equalTo: scrollView.topAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        let formCard = GlassCardView(style: .card)
        formCard.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(formCard)

        urlField.placeholder = "https://..."
        urlField.font = .systemFont(ofSize: 15)
        urlField.borderStyle = .none
        urlField.keyboardType = .URL
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.returnKeyType = .go
        urlField.addTarget(self, action: #selector(urlDidChange), for: .editingDidEndOnExit)

        let div1 = makeDivider()

        linksTextView.font = .systemFont(ofSize: 14)
        linksTextView.backgroundColor = .clear
        linksTextView.isScrollEnabled = false
        linksTextView.delegate = self
        linksTextView.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)

        linksPlaceholder.text = "Дополнительные ссылки (каждая с новой строки)"
        linksPlaceholder.font = .systemFont(ofSize: 14)
        linksPlaceholder.textColor = .placeholderText
        linksPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        titleField.placeholder = "Название (необязательно)"
        titleField.font = .systemFont(ofSize: 15)
        titleField.borderStyle = .none

        let div2 = makeDivider()
        let div3 = makeDivider()

        commentTextView.font = .systemFont(ofSize: 15)
        commentTextView.backgroundColor = .clear
        commentTextView.isScrollEnabled = false
        commentTextView.delegate = self

        commentPlaceholder.text = "Комментарий..."
        commentPlaceholder.font = .systemFont(ofSize: 15)
        commentPlaceholder.textColor = .placeholderText
        commentPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        formCard.stackView.addArrangedSubview(urlField)
        formCard.stackView.addArrangedSubview(div1)
        formCard.stackView.addArrangedSubview(linksTextView)
        formCard.stackView.addArrangedSubview(div2)
        formCard.stackView.addArrangedSubview(titleField)
        formCard.stackView.addArrangedSubview(div3)
        formCard.stackView.addArrangedSubview(commentTextView)
        linksTextView.addSubview(linksPlaceholder)
        commentTextView.addSubview(commentPlaceholder)

        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.isHidden = true
        container.addSubview(previewContainer)

        NSLayoutConstraint.activate([
            formCard.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            formCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            formCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            urlField.heightAnchor.constraint(equalToConstant: 44),
            linksTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
            titleField.heightAnchor.constraint(equalToConstant: 44),
            div1.heightAnchor.constraint(equalToConstant: 0.5),
            div2.heightAnchor.constraint(equalToConstant: 0.5),
            div3.heightAnchor.constraint(equalToConstant: 0.5),
            commentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),

            linksPlaceholder.topAnchor.constraint(equalTo: linksTextView.topAnchor, constant: 8),
            linksPlaceholder.leadingAnchor.constraint(equalTo: linksTextView.leadingAnchor, constant: 5),
            commentPlaceholder.topAnchor.constraint(equalTo: commentTextView.topAnchor, constant: 8),
            commentPlaceholder.leadingAnchor.constraint(equalTo: commentTextView.leadingAnchor, constant: 5),

            previewContainer.topAnchor.constraint(equalTo: formCard.bottomAnchor, constant: 16),
            previewContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            previewContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            previewContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }

    private func makeDivider() -> UIView {
        let v = UIView()
        v.backgroundColor = .separator
        return v
    }

    private func fillIfEditing() {
        guard let card else { return }
        urlField.text = card.url.absoluteString
        linksTextView.text = card.extraURLs.map(\.absoluteString).joined(separator: "\n")
        linksPlaceholder.isHidden = !linksTextView.text.isEmpty
        titleField.text = card.title
        commentTextView.text = card.comment
        commentPlaceholder.isHidden = !card.comment.isEmpty
        resolvedURL = card.url
        fetchLinkPreview(url: card.url)
    }

    @objc private func urlDidChange() {
        guard let text = urlField.text, !text.isEmpty,
              let url = URL(string: text.hasPrefix("http") ? text : "https://\(text)") else { return }
        resolvedURL = url
        fetchLinkPreview(url: url)
    }

    private func fetchLinkPreview(url: URL) {
        lpView?.removeFromSuperview()

        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { [weak self] meta, _ in
            guard let self, let meta else { return }
            DispatchQueue.main.async {
                let lp = LPLinkView(metadata: meta)
                lp.translatesAutoresizingMaskIntoConstraints = false
                self.previewContainer.addSubview(lp)
                NSLayoutConstraint.activate([
                    lp.topAnchor.constraint(equalTo: self.previewContainer.topAnchor),
                    lp.leadingAnchor.constraint(equalTo: self.previewContainer.leadingAnchor),
                    lp.trailingAnchor.constraint(equalTo: self.previewContainer.trailingAnchor),
                    lp.bottomAnchor.constraint(equalTo: self.previewContainer.bottomAnchor),
                    lp.heightAnchor.constraint(equalToConstant: 180)
                ])
                self.lpView = lp
                self.previewContainer.isHidden = false

                if self.titleField.text?.isEmpty == true {
                    self.titleField.text = meta.title
                }
            }
        }
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        guard let urlText = urlField.text, !urlText.isEmpty,
              let url = resolvedURL ?? URL(string: urlText.hasPrefix("http") ? urlText : "https://\(urlText)") else {
            urlField.shake()
            return
        }
        let title = titleField.text?.isEmpty == false ? titleField.text! : url.host ?? urlText
        let saved = card ?? LinkCard(title: title, dayDate: dayDate, url: url)
        let parsedExtras = linksTextView.text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { URL(string: $0.hasPrefix("http") ? $0 : "https://\($0)") }
        saved.title = title
        saved.comment = commentTextView.text ?? ""
        saved.url = url
        saved.extraURLs = parsedExtras.filter { $0.absoluteString != url.absoluteString }
        onSave?(saved)
        dismiss(animated: true)
    }
}

extension LinkCardEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView === commentTextView {
            commentPlaceholder.isHidden = !textView.text.isEmpty
        } else if textView === linksTextView {
            linksPlaceholder.isHidden = !textView.text.isEmpty
        }
    }
}
