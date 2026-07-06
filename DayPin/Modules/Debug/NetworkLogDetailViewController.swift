#if DEBUG
import UIKit

// MARK: - NetworkLogDetailViewController

final class NetworkLogDetailViewController: UIViewController {

    private let entry: NetworkLogEntry
    private let textView = UITextView()

    init(entry: NetworkLogEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = entry.path
        view.backgroundColor = DayPinDesign.background

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.text = buildText()
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain, target: self, action: #selector(copyTapped)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.done, style: .done, target: self, action: #selector(closeTapped)
        )
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = textView.text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func buildText() -> String {
        var lines: [String] = []
        lines.append("\(entry.method) \(entry.path)")
        lines.append("Duration: \(String(format: "%.0f", entry.duration * 1000))ms")
        if let error = entry.errorMessage {
            lines.append("Error: \(error)")
        }
        lines.append("")
        lines.append("--- Request Body ---")
        lines.append(prettyPrint(entry.requestBody) ?? "(none)")
        lines.append("")
        lines.append("--- Response Body ---")
        lines.append(prettyPrint(entry.responseBody) ?? "(none)")
        return lines.joined(separator: "\n")
    }

    private func prettyPrint(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return str
        }
        return String(data: data, encoding: .utf8)
    }
}
#endif
