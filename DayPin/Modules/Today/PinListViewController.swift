import UIKit

/// Bottom-sheet listing all annotation pins for an image card.
/// Tap a row to dismiss and focus the map on that pin.
final class PinListViewController: UIViewController {

    private let annotations: [ImageAnnotation]
    var onSelectPin: ((ImageAnnotation) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(annotations: [ImageAnnotation]) {
        self.annotations = annotations
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.pinList
        view.backgroundColor = DayPinDesign.background

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - UITableViewDataSource + Delegate

extension PinListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        annotations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let annotation = annotations[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = annotation.title.isEmpty
            ? L10n.pinNumber(indexPath.row + 1)
            : annotation.title
        config.secondaryText = annotation.text.isEmpty ? nil : annotation.text
        config.secondaryTextProperties.numberOfLines = 2
        config.image = UIImage(systemName: "mappin.circle.fill")
        config.imageProperties.tintColor = annotation.color
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let annotation = annotations[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.onSelectPin?(annotation)
        }
    }
}
