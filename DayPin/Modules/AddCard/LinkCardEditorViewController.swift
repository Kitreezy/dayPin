import UIKit
import LinkPresentation
import PhotosUI

final class LinkCardEditorViewController: UIViewController {

    var onSave: ((LinkCard) -> Void)?

    private let card: LinkCard?
    private let dayDate: Date
    private var resolvedURL: URL?
    private var fetchedMetadata: LPLinkMetadata?
    private var metadataTask: LPMetadataProvider?
    private var clipboardURL: URL?
    private var cardsRevealed = false

    /// Image from LP metadata (async-loaded)
    private var fetchedPreviewImage: UIImage?
    /// User-chosen custom cover (overrides metadata image)
    private var customCoverImage: UIImage?

    // MARK: - UI

    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()

    // URL row
    private let urlCard          = GlassCardView(style: .card)
    private let urlField         = UITextField()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // Clipboard suggestion
    private let clipboardBtn = UIButton(type: .system)

    // Preview card
    private let previewCard      = GlassCardView(style: .card)
    private let spinnerContainer = UIView()
    private var lpView: LPLinkView?

    // Details card
    private let detailsCard        = GlassCardView(style: .card)
    private let titleField         = UITextField()
    private let commentTextView    = UITextView()
    private let commentPlaceholder = UILabel()
    private let tagsInputView      = TagsInputView()

    // Cover button (shown after metadata fetched)
    private let coverCard = GlassCardView(style: .card)
    private let coverImageView = UIImageView()
    private let coverPlaceholderIcon = UIImageView(image: UIImage(systemName: "photo.badge.plus"))
    private let coverPlaceholderLabel = UILabel()

    // MARK: - Init

    init(card: LinkCard?, dayDate: Date) {
        self.card    = card
        self.dayDate = dayDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = card == nil ? L10n.newLink : L10n.edit
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupUI()
        addKeyboardDismissGesture()
        if let card { fillForEditing(card) }
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
        title = card == nil ? L10n.newLink : L10n.edit
        navigationItem.leftBarButtonItem?.title  = L10n.cancel
        navigationItem.rightBarButtonItem?.title = L10n.save
        urlField.placeholder         = L10n.urlPastePlaceholder
        titleField.placeholder       = L10n.linkNameLabel
        commentPlaceholder.text      = L10n.commentPlaceholder
        coverPlaceholderLabel.text   = L10n.addCover
    }

    @objc private func onColorSchemeChanged() {
        navigationItem.rightBarButtonItem?.tintColor = DayPinDesign.accent
        clipboardBtn.setTitleColor(DayPinDesign.accent, for: .normal)
        (urlCard.stackView.arrangedSubviews.first as? UIStackView)?
            .arrangedSubviews.compactMap { $0 as? UIImageView }.first?.tintColor = DayPinDesign.accent
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if card == nil {
            urlField.becomeFirstResponder()
            detectClipboard()
        }
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem  = UIBarButtonItem(title: L10n.cancel, style: .plain,  target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.save,   style: .done,   target: self, action: #selector(save))
    }

    // MARK: - UI Setup

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis    = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        buildURLCard()
        buildClipboardHint()
        buildPreviewCard()
        buildDetailsCard()
        buildCoverCard()

        contentStack.addArrangedSubview(urlCard)
        contentStack.addArrangedSubview(clipboardBtn)
        contentStack.addArrangedSubview(previewCard)
        contentStack.addArrangedSubview(detailsCard)
        contentStack.addArrangedSubview(coverCard)

        clipboardBtn.isHidden = true
        previewCard.isHidden  = true
        previewCard.alpha     = 0
        detailsCard.isHidden  = true
        detailsCard.alpha     = 0
        coverCard.isHidden    = true
        coverCard.alpha       = 0
    }

    private func buildURLCard() {
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let linkIcon = UIImageView(image: UIImage(systemName: "link", withConfiguration: iconCfg))
        linkIcon.tintColor = DayPinDesign.accent
        linkIcon.setContentHuggingPriority(.required, for: .horizontal)

        urlField.placeholder            = L10n.urlPastePlaceholder
        urlField.font                   = .inter(ofSize: 15)
        urlField.borderStyle            = .none
        urlField.keyboardType           = .URL
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType     = .no
        urlField.returnKeyType          = .go
        urlField.clearButtonMode        = .whileEditing
        urlField.delegate               = self
        urlField.addTarget(self, action: #selector(urlFieldChanged), for: .editingChanged)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .secondaryLabel
        loadingIndicator.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [linkIcon, urlField, loadingIndicator])
        row.axis      = .horizontal
        row.spacing   = 10
        row.alignment = .center
        row.heightAnchor.constraint(equalToConstant: 48).isActive = true
        urlCard.stackView.addArrangedSubview(row)
    }

    private func buildClipboardHint() {
        clipboardBtn.setTitleColor(DayPinDesign.accent, for: .normal)
        clipboardBtn.titleLabel?.font = .inter(ofSize: 13)
        clipboardBtn.contentHorizontalAlignment = .leading
        clipboardBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        clipboardBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        clipboardBtn.addTarget(self, action: #selector(pasteClipboard), for: .touchUpInside)
    }

    private func buildPreviewCard() {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinnerContainer.heightAnchor.constraint(equalToConstant: 72).isActive = true
        spinnerContainer.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: spinnerContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: spinnerContainer.centerYAnchor)
        ])
        previewCard.stackView.addArrangedSubview(spinnerContainer)
    }

    private func buildDetailsCard() {
        titleField.placeholder = L10n.linkNameLabel
        titleField.font        = .inter(ofSize: 15)
        titleField.borderStyle = .none
        titleField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        commentTextView.font            = .inter(ofSize: 15)
        commentTextView.backgroundColor = .clear
        commentTextView.isScrollEnabled = false
        commentTextView.delegate        = self
        commentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true

        commentPlaceholder.text      = L10n.commentPlaceholder
        commentPlaceholder.font      = .inter(ofSize: 15)
        commentPlaceholder.textColor = .placeholderText
        commentPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        commentTextView.addSubview(commentPlaceholder)

        let tagsDivider = UIView()
        tagsDivider.backgroundColor = .separator
        tagsDivider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        tagsInputView.heightAnchor.constraint(equalToConstant: 36).isActive = true

        detailsCard.stackView.addArrangedSubview(titleField)
        detailsCard.stackView.addArrangedSubview(divider)
        detailsCard.stackView.addArrangedSubview(commentTextView)
        detailsCard.stackView.addArrangedSubview(tagsDivider)
        detailsCard.stackView.addArrangedSubview(tagsInputView)

        NSLayoutConstraint.activate([
            commentPlaceholder.topAnchor.constraint(equalTo: commentTextView.topAnchor, constant: 8),
            commentPlaceholder.leadingAnchor.constraint(equalTo: commentTextView.leadingAnchor, constant: 5)
        ])
    }

    private func buildCoverCard() {
        // Tap gesture to pick cover
        let tap = UITapGestureRecognizer(target: self, action: #selector(coverTapped))
        coverCard.addGestureRecognizer(tap)
        coverCard.isUserInteractionEnabled = true

        // Image preview (hidden until image selected)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.layer.cornerRadius = 10
        coverImageView.layer.masksToBounds = true
        coverImageView.isHidden = true
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        coverImageView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        // Placeholder
        coverPlaceholderIcon.tintColor = .tertiaryLabel
        coverPlaceholderIcon.contentMode = .scaleAspectFit
        coverPlaceholderIcon.translatesAutoresizingMaskIntoConstraints = false
        coverPlaceholderIcon.heightAnchor.constraint(equalToConstant: 28).isActive = true

        coverPlaceholderLabel.text = L10n.addCover
        coverPlaceholderLabel.font = .inter(ofSize: 13)
        coverPlaceholderLabel.textColor = .secondaryLabel
        coverPlaceholderLabel.textAlignment = .center

        let placeholder = UIStackView(arrangedSubviews: [coverPlaceholderIcon, coverPlaceholderLabel])
        placeholder.axis = .vertical
        placeholder.spacing = 6
        placeholder.alignment = .center

        let headerLabel = UILabel()
        headerLabel.text = L10n.cover
        headerLabel.font = .inter(ofSize: 13, weight: .medium)
        headerLabel.textColor = .secondaryLabel

        coverCard.stackView.addArrangedSubview(headerLabel)
        coverCard.stackView.addArrangedSubview(coverImageView)
        coverCard.stackView.addArrangedSubview(placeholder)
        coverCard.stackView.spacing = 8
    }

    // MARK: - Clipboard

    private func detectClipboard() {
        let pb  = UIPasteboard.general
        let str = (pb.url?.absoluteString ?? pb.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return }
        let normalized = str.hasPrefix("http") ? str : "https://\(str)"
        guard let url = URL(string: normalized), url.host != nil else { return }
        clipboardURL = url
        let domain = url.host ?? str
        clipboardBtn.setTitle("📋  \(domain)", for: .normal)
        UIView.animate(withDuration: 0.2) { self.clipboardBtn.isHidden = false }
    }

    @objc private func pasteClipboard() {
        guard let url = clipboardURL else { return }
        urlField.text = url.absoluteString
        resolvedURL   = url
        UIView.animate(withDuration: 0.15) { self.clipboardBtn.isHidden = true }
        fetchAndReveal(url: url)
    }

    // MARK: - URL field

    @objc private func urlFieldChanged() {
        guard !(urlField.text?.isEmpty ?? true) else { return }
        UIView.animate(withDuration: 0.15) { self.clipboardBtn.isHidden = true }
    }

    // MARK: - Fetch & reveal

    private func fetchAndReveal(url: URL) {
        metadataTask?.cancel()
        metadataTask = nil
        resolvedURL  = url

        revealCards()
        loadingIndicator.startAnimating()

        let provider = LPMetadataProvider()
        metadataTask = provider
        provider.startFetchingMetadata(for: url) { [weak self] meta, _ in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                guard let meta else { return }
                self?.applyMetadata(meta)
            }
        }
    }

    private func revealCards() {
        guard !cardsRevealed else { return }
        cardsRevealed = true

        let cards = [previewCard, detailsCard, coverCard]
        cards.forEach {
            $0.isHidden  = false
            $0.alpha     = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 16)
        }
        for (i, card) in cards.enumerated() {
            let delay = Double(i) * 0.08
            UIView.animate(withDuration: 0.45, delay: delay,
                           usingSpringWithDamping: 0.78, initialSpringVelocity: 0.2) {
                card.alpha     = 1
                card.transform = .identity
            }
        }
    }

    private func applyMetadata(_ meta: LPLinkMetadata) {
        fetchedMetadata = meta

        if titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            titleField.text = meta.title
        }

        spinnerContainer.removeFromSuperview()
        lpView?.removeFromSuperview()

        let lp = LPLinkView(metadata: meta)
        lp.isUserInteractionEnabled = false
        lp.translatesAutoresizingMaskIntoConstraints = false
        previewCard.stackView.addArrangedSubview(lp)
        lpView = lp

        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }

        // Async-load thumbnail from metadata (only if user hasn't picked a custom cover)
        meta.imageProvider?.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, self.customCoverImage == nil, let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self.fetchedPreviewImage = image
                self.showCoverPreview(image)
            }
        }
    }

    private func showCoverPreview(_ image: UIImage) {
        coverImageView.image   = image
        coverImageView.isHidden = false
        // Hide placeholder text when image is present
        coverCard.stackView.arrangedSubviews.last?.isHidden = true
    }

    // MARK: - Cover picker

    @objc private func coverTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Fill for editing

    private func fillForEditing(_ card: LinkCard) {
        urlField.text        = card.url.absoluteString
        titleField.text      = card.title
        commentTextView.text = card.comment
        commentPlaceholder.isHidden = !card.comment.isEmpty
        tagsInputView.tagIDs = card.tagIDs
        resolvedURL   = card.url
        cardsRevealed = true

        [previewCard, detailsCard, coverCard].forEach { $0.isHidden = false; $0.alpha = 1 }

        // Show existing preview image if available
        if let data = card.previewImageData, let image = UIImage(data: data) {
            fetchedPreviewImage = image
            showCoverPreview(image)
        }

        fetchAndReveal(url: card.url)
    }

    // MARK: - Actions

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let urlText = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !urlText.isEmpty,
              let url = resolvedURL ?? URL(string: urlText.hasPrefix("http") ? urlText : "https://\(urlText)") else {
            urlField.shake(); return
        }

        let rawTitle = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title    = rawTitle.isEmpty ? (url.host ?? urlText) : rawTitle

        let saved = card ?? LinkCard(title: title, dayDate: dayDate, url: url)
        saved.title              = title
        saved.comment            = commentTextView.text ?? ""
        saved.url                = url
        saved.extraURLs          = card?.extraURLs ?? []
        saved.previewTitle       = fetchedMetadata?.title ?? card?.previewTitle
        saved.previewDescription = card?.previewDescription
        saved.tagIDs             = tagsInputView.selectedTagIDs

        // Priority: custom cover > fetched metadata image > existing saved image
        let coverImage = customCoverImage ?? fetchedPreviewImage
        saved.previewImageData = coverImage?.jpegData(compressionQuality: 0.72) ?? card?.previewImageData

        onSave?(saved)
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension LinkCardEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder(); return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard textField === urlField else { return }
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }
        let normalized = text.hasPrefix("http") ? text : "https://\(text)"
        guard let url = URL(string: normalized), url.host != nil else { return }
        guard url.absoluteString != resolvedURL?.absoluteString else { return }
        fetchAndReveal(url: url)
    }
}

// MARK: - UITextViewDelegate

extension LinkCardEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        commentPlaceholder.isHidden = !textView.text.isEmpty
    }
}

// MARK: - PHPickerViewControllerDelegate

extension LinkCardEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.customCoverImage = image
                self?.fetchedPreviewImage = nil
                self?.showCoverPreview(image)
            }
        }
    }
}
