#if DEBUG
import UIKit

// MARK: - NetworkLogViewController
// Debug-only tab listing every API call made during this session - method,
// path, status, timing, request/response bodies. Never ships in release.

final class NetworkLogViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Network"
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupTable()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .dayPinNetworkLogUpdated, object: nil
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func setupNav() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain, target: self, action: #selector(clearTapped)
        )
    }

    @objc private func clearTapped() {
        NetworkLogger.shared.clear()
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func reload() {
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource + Delegate

extension NetworkLogViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        NetworkLogger.shared.entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let entry = NetworkLogger.shared.entries[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        var config = UIListContentConfiguration.subtitleCell()
        let statusEmoji = entry.isSuccess ? "\u{2705}" : "\u{274C}"
        config.text = "\(statusEmoji) \(entry.method) \(entry.path)"

        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        var subtitle = "\(df.string(from: entry.timestamp)) \u{00B7} \(String(format: "%.0fms", entry.duration * 1000))"
        if let error = entry.errorMessage { subtitle += " \u{00B7} \(error)" }
        config.secondaryText = subtitle

        config.textProperties.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        config.secondaryTextProperties.color = entry.isSuccess ? .secondaryLabel : .systemRed

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = NetworkLogger.shared.entries[indexPath.row]
        navigationController?.pushViewController(NetworkLogDetailViewController(entry: entry), animated: true)
    }
}
#endif
