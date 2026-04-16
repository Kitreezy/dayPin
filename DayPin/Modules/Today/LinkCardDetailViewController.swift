import UIKit
import SafariServices

final class LinkCardDetailViewController: UIViewController {

    private let card: LinkCard
    private let cardView = GlassCardView(style: .card)
    private let titleLabel = UILabel()
    private let linksStack = UIStackView()
    private let commentLabel = UILabel()

    init(card: LinkCard) {
        self.card = card
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        title = card.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain,
            target: self,
            action: #selector(editTapped)
        )
        setupUI()
    }

    private func setupUI() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 0

        linksStack.axis = .vertical
        linksStack.spacing = 8

        commentLabel.font = .systemFont(ofSize: 16)
        commentLabel.textColor = .secondaryLabel
        commentLabel.numberOfLines = 0

        cardView.stackView.spacing = 12
        cardView.stackView.addArrangedSubview(titleLabel)
        cardView.stackView.addArrangedSubview(linksStack)
        cardView.stackView.addArrangedSubview(commentLabel)
        render()

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func render() {
        titleLabel.text = card.title
        title = card.title
        commentLabel.text = card.comment
        commentLabel.isHidden = card.comment.isEmpty

        linksStack.arrangedSubviews.forEach {
            linksStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let allLinks = [card.url] + card.extraURLs
        for (index, url) in allLinks.enumerated() {
            let button = UIButton(type: .system)
            var cfg = UIButton.Configuration.plain()
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            cfg.image = UIImage(systemName: "link.circle")
            cfg.imagePadding = 6
            cfg.baseForegroundColor = .systemBlue
            cfg.title = url.absoluteString
            button.configuration = cfg
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.tag = index
            button.layer.cornerRadius = 10
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            button.addTarget(self, action: #selector(openLinkTapped(_:)), for: .touchUpInside)
            linksStack.addArrangedSubview(button)
        }
    }

    @objc private func openLinkTapped(_ sender: UIButton) {
        let allLinks = [card.url] + card.extraURLs
        guard allLinks.indices.contains(sender.tag) else { return }
        let safari = SFSafariViewController(url: allLinks[sender.tag])
        safari.modalPresentationStyle = .pageSheet
        if let sheet = safari.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(safari, animated: true)
    }

    @objc private func editTapped() {
        let vc = LinkCardEditorViewController(card: card, dayDate: card.dayDate)
        vc.onSave = { [weak self] saved in
            CardStore.shared.save(card: saved)
            self?.render()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }
}
