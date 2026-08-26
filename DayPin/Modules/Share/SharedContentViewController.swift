import UIKit

// MARK: - SharedContentViewController
// Read-only viewer for content opened via a public share link (Universal Link
// to https://daypin-server.onrender.com/s/:id). No editing, no context menus -
// this is someone else's shared card/collection, not local data.

final class SharedContentViewController: UIViewController {

    private let shareID: String
    private var content: SharedContentResponse?
    private var displayCards: [NoteCard] = []

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let errorLabel = UILabel()

    private let cardsCollectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            return section
        }
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    init(shareID: String) {
        self.shareID = shareID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        addStandardBackground()
        setupNav()
        setupUI()
        load()
    }

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain, target: self, action: #selector(closeTapped)
        )
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Setup

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        errorLabel.font = .inter(ofSize: 15, weight: .medium)
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)

        cardsCollectionView.backgroundColor = .clear
        cardsCollectionView.isScrollEnabled = false
        cardsCollectionView.register(TextCardCell.self, forCellWithReuseIdentifier: TextCardCell.reuseID)
        cardsCollectionView.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cardsCollectionView.register(LinkCardCell.self, forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cardsCollectionView.dataSource = self
        cardsCollectionView.delegate = self
        cardsCollectionView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    // MARK: - Load

    private func load() {
        Task {
            do {
                let response = try await ShareService.shared.fetchSharedContent(id: shareID)
                content = response
                render(response)
            } catch APIClientError.serverError(let message) where message.lowercased().contains("expired") {
                showError(L10n.isRussian ? "Срок действия ссылки истёк" : "This link has expired")
            } catch {
                showError(L10n.isRussian ? "Ссылка не найдена или недоступна" : "Link not found or unavailable")
            }
        }
    }

    private func showError(_ text: String) {
        spinner.stopAnimating()
        errorLabel.text = text
        errorLabel.isHidden = false
    }

    // MARK: - Render

    private func render(_ response: SharedContentResponse) {
        spinner.stopAnimating()
        title = response.title.isEmpty
            ? (L10n.isRussian ? "Общий доступ" : "Shared")
            : response.title

        let headerLabel = UILabel()
        headerLabel.text = response.title.isEmpty ? title : response.title
        headerLabel.font = .inter(ofSize: 22, weight: .bold)
        headerLabel.textColor = .label
        headerLabel.numberOfLines = 0
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let df = DateFormatter()
        df.locale = L10n.activeLocale
        df.dateStyle = .medium
        df.timeStyle = .short

        let metaLabel = UILabel()
        var metaText = "\(L10n.isRussian ? "Опубликовано" : "Shared") \(df.string(from: response.createdAt))"
        if let expiresAt = response.expiresAt {
            metaText += "\n\(L10n.isRussian ? "Истекает" : "Expires") \(df.string(from: expiresAt))"
        }
        metaLabel.text = metaText
        metaLabel.font = .inter(ofSize: 12, weight: .regular)
        metaLabel.textColor = .tertiaryLabel
        metaLabel.numberOfLines = 0
        metaLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerPadding = UIView()
        headerPadding.translatesAutoresizingMaskIntoConstraints = false
        headerPadding.addSubview(headerLabel)
        headerPadding.addSubview(metaLabel)
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: headerPadding.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: headerPadding.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: headerPadding.trailingAnchor, constant: -16),

            metaLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: headerLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: headerLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: headerPadding.bottomAnchor)
        ])
        stack.addArrangedSubview(headerPadding)

        switch response.type {
        case "card":
            guard let dto = response.card, let card = dto.toModel() else {
                showError(L10n.isRussian ? "Не удалось прочитать карточку" : "Couldn't read this card")
                return
            }
            displayCards = [card]
        default:
            displayCards = (response.cards ?? []).compactMap { $0.toModel() }
        }

        guard !displayCards.isEmpty else {
            showError(L10n.isRussian ? "В этой ссылке нет содержимого" : "This link has no content")
            return
        }

        let rows = (displayCards.count + 1) / 2
        let height = CGFloat(rows) * 160 + CGFloat(max(0, rows - 1)) * 0
        cardsCollectionView.heightAnchor.constraint(equalToConstant: height).isActive = true
        stack.addArrangedSubview(cardsCollectionView)
        cardsCollectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource + Delegate

extension SharedContentViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayCards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let card = displayCards[indexPath.item]
        switch card.type {
        case .text:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as? TextCardCell,
                  let textCard = card as? TextCard else { return UICollectionViewCell() }
            c.configure(with: textCard)
            return c
        case .image:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as? ImageCardCell,
                  let imageCard = card as? ImageCard else { return UICollectionViewCell() }
            c.configure(with: imageCard)
            return c
        case .link:
            guard let c = collectionView.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as? LinkCardCell,
                  let linkCard = card as? LinkCard else { return UICollectionViewCell() }
            c.configure(with: linkCard)
            return c
        }
    }

    // Read-only: tapping does nothing, no context menu, no editing.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
