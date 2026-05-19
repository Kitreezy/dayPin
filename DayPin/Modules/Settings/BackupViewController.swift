import UIKit
import UniformTypeIdentifiers

// MARK: - BackupViewController

final class BackupViewController: UIViewController {

    // MARK: - State

    /// Tracks whether the currently-presented document picker is for export or import.
    /// The delegate method is identical for both — we must distinguish via this flag.
    private enum PickerMode { case export, restore }
    private var pickerMode: PickerMode = .export

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum Section: Int, CaseIterable {
        case export, restore, info
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.backup
        view.backgroundColor = DayPinDesign.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close)
        )
        setupTable()
        observeNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        title = L10n.backup
        tableView.reloadData()
    }

    @objc private func onColorSchemeChanged() {
        // No accent-colored elements in this screen
    }

    // MARK: - Setup

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func close() { dismiss(animated: true) }

    // MARK: - Export

    private func exportBackup() {
        do {
            let data = try BackupManager.shared.makeBackupData()
            let filename = BackupManager.shared.suggestedFilename()

            // Write to a temp file — document picker will copy it to the chosen destination
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(filename)
            try data.write(to: tempURL, options: .atomic)

            pickerMode = .export   // ← mark BEFORE presenting
            let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
            picker.delegate = self
            present(picker, animated: true)
        } catch {
            showAlert(title: L10n.exportError, message: error.localizedDescription)
        }
    }

    // MARK: - Import

    private func importBackup() {
        pickerMode = .restore   // ← mark BEFORE presenting
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.json, .data], asCopy: true
        )
        picker.delegate = self
        present(picker, animated: true)
    }

    private func processImport(url: URL) {
        // Show spinner — file can be 10-30MB (images encoded as base64)
        let spinner = showSpinner(message: L10n.readingFile)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // asCopy:true already places file in sandbox — no security scope needed
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let preview = try BackupManager.shared.peekBackup(from: data)

                DispatchQueue.main.async {
                    spinner.dismiss(animated: false) {
                        self?.showRestoreConfirmation(data: data, preview: preview)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    spinner.dismiss(animated: false) {
                        self?.showAlert(
                            title: L10n.fileError,
                            message: "\(L10n.fileCorrupted)\n\n\(error.localizedDescription)"
                        )
                    }
                }
            }
        }
    }

    private func showRestoreConfirmation(data: Data, preview: DayPinBackup) {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = L10n.activeLocale
        let dateStr  = df.string(from: preview.exportDate)
        let cards    = preview.cards.count
        let folders  = preview.folders.count
        let imgCards = preview.cards.filter { $0.imageData != nil }.count

        let alert = UIAlertController(
            title: L10n.restoreDataTitle,
            message: L10n.restoreConfirmMessage(date: dateStr, cards: cards, imgCards: imgCards, folders: folders),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.backupRestore, style: .destructive) { [weak self] _ in
            self?.performRestore(data: data)
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func performRestore(data: Data) {
        let spinner = showSpinner(message: L10n.restoring)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try BackupManager.shared.restore(from: data)
                DispatchQueue.main.async {
                    spinner.dismiss(animated: false) {
                        let alert = UIAlertController(
                            title: L10n.restoreDone,
                            message: L10n.restoreSuccess(cards: result.cards, folders: result.folders),
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                            NotificationCenter.default.post(name: .dayPinDataRestored, object: nil)
                            self?.dismiss(animated: true)
                        })
                        self?.present(alert, animated: true)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    spinner.dismiss(animated: false) {
                        self?.showAlert(title: L10n.restoreError, message: error.localizedDescription)
                    }
                }
            }
        }
    }

    // MARK: - Spinner helper

    private func showSpinner(message: String) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
            indicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor)
        ])
        present(alert, animated: true)
        return alert
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource + Delegate

extension BackupViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let s = Section(rawValue: section) else { return nil }
        switch s {
        case .export:  return L10n.backupSave
        case .restore: return L10n.backupRestore
        case .info:    return L10n.backupStats
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let s = Section(rawValue: section) else { return nil }
        switch s {
        case .export:  return L10n.backupDescription
        case .restore: return L10n.restoreDescription
        case .info:
            return nil
        }
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let section = Section(rawValue: indexPath.section) else { return cell }

        switch section {
        case .export:
            var cfg = cell.defaultContentConfiguration()
            cfg.text = L10n.backupCreate
            let allCards  = CardStore.shared.allDTOs().count
            let allDays   = Set(CardStore.shared.allDTOs().map {
                Calendar.current.startOfDay(for: $0.dayDate)
            }).count
            cfg.secondaryText = L10n.notesDayCount(notes: allCards, days: allDays)
            cfg.image = UIImage(systemName: "arrow.up.doc.fill")
            cfg.imageProperties.tintColor = .systemBlue
            cell.contentConfiguration = cfg
            cell.accessoryType = .disclosureIndicator

        case .restore:
            var cfg = cell.defaultContentConfiguration()
            cfg.text = L10n.backupRestoreFromFile
            cfg.secondaryText = L10n.backupChooseFile
            cfg.image = UIImage(systemName: "arrow.down.doc.fill")
            cfg.imageProperties.tintColor = .systemOrange
            cell.contentConfiguration = cfg
            cell.accessoryType = .disclosureIndicator

        case .info:
            var cfg = cell.defaultContentConfiguration()
            let dtos    = CardStore.shared.allDTOs()
            let cards   = dtos.count
            let imgs    = dtos.filter { $0.imageData != nil }.count
            let folders = FolderStore.shared.all().count
            let days    = Set(dtos.map { Calendar.current.startOfDay(for: $0.dayDate) }).count
            cfg.text = L10n.backupSummary(cards: cards, days: days, imgs: imgs, folders: folders)
            cfg.textProperties.font = .inter(ofSize: 14)
            cfg.textProperties.color = .secondaryLabel
            cfg.textProperties.numberOfLines = 0
            cell.contentConfiguration = cfg
            cell.selectionStyle = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .export:  exportBackup()
        case .restore: importBackup()
        case .info:    break
        }
    }

}

// MARK: - UIDocumentPickerDelegate

extension BackupViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        // IMPORTANT: this delegate fires for BOTH export and import.
        // We distinguish via `pickerMode` set before presenting each picker.
        switch pickerMode {
        case .export:
            // Export finished — nothing to do (file is already saved by the picker)
            break
        case .restore:
            guard let url = urls.first else { return }
            processImport(url: url)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
}

// MARK: - Notification

extension Notification.Name {
    static let dayPinDataRestored = Notification.Name("dayPinDataRestored")
}
