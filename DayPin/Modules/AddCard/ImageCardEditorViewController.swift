import UIKit

final class ImageCardEditorViewController: UIViewController {

    var onSave: ((ImageCard) -> Void)?

    private let imageData: Data?
    private let dayDate: Date
    private let existingCard: ImageCard?

    private let titleField = UITextField()
    private let annotationView = ImageAnnotationView()
    private var annotations: [ImageAnnotation] = []

    init(imageData: Data?, dayDate: Date, existingCard: ImageCard?) {
        self.imageData = imageData
        self.dayDate = dayDate
        self.existingCard = existingCard
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existingCard == nil ? "Новое фото" : "Редактировать"
        view.backgroundColor = .systemGroupedBackground
        setupNav()
        setupUI()
        fillIfEditing()
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

        // Title card
        let titleCard = GlassCardView(style: .card)
        titleCard.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleCard)

        titleField.placeholder = "Название фото"
        titleField.font = .systemFont(ofSize: 17, weight: .semibold)
        titleField.borderStyle = .none
        titleCard.stackView.addArrangedSubview(titleField)

        // Image annotation view
        annotationView.translatesAutoresizingMaskIntoConstraints = false
        annotationView.delegate = self
        if let data = imageData {
            annotationView.image = UIImage(data: data)
        }
        container.addSubview(annotationView)

        // Hint label
        let hintLabel = UILabel()
        hintLabel.text = "Нажмите на изображение, чтобы добавить аннотацию"
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            titleCard.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            titleField.heightAnchor.constraint(equalToConstant: 44),

            annotationView.topAnchor.constraint(equalTo: titleCard.bottomAnchor, constant: 16),
            annotationView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            annotationView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            annotationView.heightAnchor.constraint(equalTo: annotationView.widthAnchor, multiplier: 0.75),

            hintLabel.topAnchor.constraint(equalTo: annotationView.bottomAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            hintLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
    }

    private func fillIfEditing() {
        guard let card = existingCard else { return }
        titleField.text = card.title
        annotations = card.annotations
        annotationView.load(annotations: annotations)
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        guard let title = titleField.text, !title.isEmpty else {
            titleField.shake()
            return
        }
        let saved = existingCard ?? ImageCard(title: title, dayDate: dayDate)
        saved.title = title
        saved.imageData = imageData ?? existingCard?.imageData
        saved.annotations = annotations
        onSave?(saved)
        dismiss(animated: true)
    }
}

extension ImageCardEditorViewController: ImageAnnotationViewDelegate {
    func annotationView(_ view: ImageAnnotationView, didAddAnnotation annotation: ImageAnnotation) {
        annotations.append(annotation)
    }
    func annotationView(_ view: ImageAnnotationView, didUpdateAnnotation annotation: ImageAnnotation) {
        if let i = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[i] = annotation
        }
    }
    func annotationView(_ view: ImageAnnotationView, didDeleteAnnotation annotation: ImageAnnotation) {
        annotations.removeAll { $0.id == annotation.id }
    }
}
