import UIKit

final class CardDetailViewController: UIViewController {

    private let card: TextCard

    init(card: TextCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = card.title
        setupNav()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(goBack)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(share)),
            UIBarButtonItem(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(edit))
        ]
    }

    // MARK: - UI

    private func setupUI() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scroll.topAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            container.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        let cardView = GlassCardView(style: .card)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cardView)

        // Date
        let df = DateFormatter()
        df.dateFormat = "d MMMM yyyy · HH:mm"
        df.locale = Locale.current
        let dateLabel = UILabel()
        dateLabel.text = df.string(from: card.createdAt)
        dateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = .tertiaryLabel

        // Title
        let titleLabel = UILabel()
        titleLabel.text = card.title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        cardView.stackView.spacing = 10
        cardView.stackView.addArrangedSubview(dateLabel)
        cardView.stackView.addArrangedSubview(titleLabel)

        if !card.comment.isEmpty {
            let sep = UIView()
            sep.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
            sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

            let commentLabel = UILabel()
            commentLabel.text = card.comment
            commentLabel.font = .systemFont(ofSize: 16, weight: .regular)
            commentLabel.textColor = .secondaryLabel
            commentLabel.numberOfLines = 0
            commentLabel.lineBreakMode = .byWordWrapping

            cardView.stackView.addArrangedSubview(sep)
            cardView.stackView.addArrangedSubview(commentLabel)
        }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Actions

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func share() {
        var items: [Any] = [card.title]
        if !card.comment.isEmpty { items.append(card.comment) }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }

    @objc private func edit() {
        let vc = TextCardEditorViewController(card: card, dayDate: card.dayDate)
        vc.onSave = { [weak self] saved in
            CardStore.shared.save(card: saved)
            self?.navigationController?.popViewController(animated: true)
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }
}
