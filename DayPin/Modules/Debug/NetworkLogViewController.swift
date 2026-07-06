#if DEBUG
import UIKit

// MARK: - NetworkLogViewController
// Embeddable panel (no nav bar of its own) showing every API call made this
// session - method, path, status, timing. Hosted inside DebugOverlayManager's
// shake-to-debug overlay, switched to via the Layout/Network mode toggle.

final class NetworkLogViewController: UIViewController {

    var onSelectEntry: ((NetworkLogEntry) -> Void)?

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let clearButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        setupHeader()
        setupTable()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .dayPinNetworkLogUpdated, object: nil
        )
        reload()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        titleLabel.text = "Network"
        titleLabel.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        countLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(countLabel)

        clearButton.setImage(UIImage(systemName: "trash"), for: .normal)
        clearButton.tintColor = .white
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(clearButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            headerView.heightAnchor.constraint(equalToConstant: 30),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 30),
            clearButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.12)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func clearTapped() {
        NetworkLogger.shared.clear()
    }

    @objc private func reload() {
        countLabel.text = "(\(NetworkLogger.shared.entries.count))"
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
        config.textProperties.color = .white

        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        var subtitle = "\(df.string(from: entry.timestamp)) \u{00B7} \(String(format: "%.0fms", entry.duration * 1000))"
        if let error = entry.errorMessage { subtitle += " \u{00B7} \(error)" }
        config.secondaryText = subtitle

        config.textProperties.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        config.secondaryTextProperties.color = entry.isSuccess
            ? UIColor.white.withAlphaComponent(0.55)
            : UIColor.systemRed.withAlphaComponent(0.9)

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectEntry?(NetworkLogger.shared.entries[indexPath.row])
    }
}
#endif
