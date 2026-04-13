import UIKit

final class TextCardEditorViewController: UIViewController {

    var onSave: ((TextCard) -> Void)?

    private let card: TextCard?
    private let dayDate: Date

    private let titleField = UITextField()
    private let commentTextView = UITextView()
    private let commentPlaceholder = UILabel()

    init(card: TextCard?, dayDate: Date) {
        self.card = card
        self.dayDate = dayDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = card == nil ? "Новая заметка" : "Редактировать"
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
        let formCard = GlassCardView(style: .card)
        formCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formCard)

        titleField.placeholder = "Заголовок"
        titleField.font = .systemFont(ofSize: 17, weight: .semibold)
        titleField.borderStyle = .none
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        commentTextView.font = .systemFont(ofSize: 15)
        commentTextView.backgroundColor = .clear
        commentTextView.isScrollEnabled = false
        commentTextView.textContainer.lineBreakMode = .byWordWrapping
        commentTextView.translatesAutoresizingMaskIntoConstraints = false
        commentTextView.delegate = self

        commentPlaceholder.text = "Комментарий (необязательно)"
        commentPlaceholder.font = .systemFont(ofSize: 15)
        commentPlaceholder.textColor = .placeholderText
        commentPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        formCard.stackView.addArrangedSubview(titleField)
        formCard.stackView.addArrangedSubview(divider)
        formCard.stackView.addArrangedSubview(commentTextView)
        commentTextView.addSubview(commentPlaceholder)

        NSLayoutConstraint.activate([
            formCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            formCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            titleField.heightAnchor.constraint(equalToConstant: 44),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            commentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            commentPlaceholder.topAnchor.constraint(equalTo: commentTextView.topAnchor, constant: 8),
            commentPlaceholder.leadingAnchor.constraint(equalTo: commentTextView.leadingAnchor, constant: 5)
        ])
    }

    private func fillIfEditing() {
        guard let card else { return }
        titleField.text = card.title
        commentTextView.text = card.comment
        commentPlaceholder.isHidden = !card.comment.isEmpty
    }

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        guard let title = titleField.text, !title.isEmpty else {
            titleField.shake()
            return
        }
        let saved = card ?? TextCard(title: title, dayDate: dayDate)
        saved.title = title
        saved.comment = commentTextView.text ?? ""
        onSave?(saved)
        dismiss(animated: true)
    }
}

extension TextCardEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        commentPlaceholder.isHidden = !textView.text.isEmpty
    }
}
