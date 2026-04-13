import UIKit

final class ImageCardDetailViewController: UIViewController {

    private let card: ImageCard
    private let annotationView = ImageAnnotationView()
    private var annotations: [ImageAnnotation]

    init(card: ImageCard) {
        self.card = card
        self.annotations = card.annotations
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = card.title
        view.backgroundColor = .black
        setupNav()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        navigationController?.navigationBar.barStyle = .default
        navigationController?.navigationBar.tintColor = nil
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(goBack)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(share)
        )
    }

    // MARK: - UI

    private func setupUI() {
        annotationView.translatesAutoresizingMaskIntoConstraints = false
        annotationView.layer.cornerRadius = 0
        annotationView.image = card.imageData.flatMap { UIImage(data: $0) }
        annotationView.delegate = self
        annotationView.load(annotations: annotations)
        view.addSubview(annotationView)

        // Hint label at bottom
        let hintLabel = UILabel()
        hintLabel.text = L10n.annotationHint
        hintLabel.font = .systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            annotationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            annotationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            annotationView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            annotationView.heightAnchor.constraint(equalTo: annotationView.widthAnchor, multiplier: 0.75),

            hintLabel.topAnchor.constraint(equalTo: annotationView.bottomAnchor, constant: 16),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Actions

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func share() {
        var items: [Any] = [card.title]
        if let data = card.imageData, let image = UIImage(data: data) { items.append(image) }
        let notes = annotations.map { "• \($0.text)" }.joined(separator: "\n")
        if !notes.isEmpty { items.append(notes) }
        present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
    }

    private func persist() {
        card.annotations = annotations
        CardStore.shared.save(card: card)
    }
}

// MARK: - ImageAnnotationViewDelegate

extension ImageCardDetailViewController: ImageAnnotationViewDelegate {
    func annotationView(_ view: ImageAnnotationView, didAddAnnotation annotation: ImageAnnotation) {
        annotations.append(annotation); persist()
    }
    func annotationView(_ view: ImageAnnotationView, didUpdateAnnotation annotation: ImageAnnotation) {
        if let i = annotations.firstIndex(where: { $0.id == annotation.id }) { annotations[i] = annotation }
        persist()
    }
    func annotationView(_ view: ImageAnnotationView, didDeleteAnnotation annotation: ImageAnnotation) {
        annotations.removeAll { $0.id == annotation.id }; persist()
    }
}
