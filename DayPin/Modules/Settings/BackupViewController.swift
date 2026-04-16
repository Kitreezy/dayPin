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
        title = "Резервная копия"
        view.backgroundColor = DayPinDesign.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close)
        )
        setupTable()
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
            showAlert(title: "Ошибка экспорта", message: error.localizedDescription)
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
        let spinner = showSpinner(message: "Читаем файл…")

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
                            title: "Ошибка файла",
                            message: "Файл повреждён или имеет неверный формат.\n\n\(error.localizedDescription)"
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
        let dateStr  = df.string(from: preview.exportDate)
        let cards    = preview.cards.count
        let folders  = preview.folders.count
        let imgCards = preview.cards.filter { $0.imageData != nil }.count

        let alert = UIAlertController(
            title: "Восстановить данные?",
            message: """
            Файл создан: \(dateStr)

            Заметок: \(cards) (\(imgCards) с фото)
            Папок: \(folders)

            ⚠️ Текущие данные будут полностью заменены.
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Восстановить", style: .destructive) { [weak self] _ in
            self?.performRestore(data: data)
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    private func performRestore(data: Data) {
        let spinner = showSpinner(message: "Восстанавливаем…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try BackupManager.shared.restore(from: data)
                DispatchQueue.main.async {
                    spinner.dismiss(animated: false) {
                        let alert = UIAlertController(
                            title: "Готово ✓",
                            message: "Восстановлено:\nЗаметок: \(result.cards)\nПапок: \(result.folders)",
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
                        self?.showAlert(title: "Ошибка восстановления", message: error.localizedDescription)
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
        switch Section(rawValue: section)! {
        case .export:  return "Сохранить копию"
        case .restore: return "Восстановить"
        case .info:    return "Статистика"
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .export:
            return "Включает ВСЕ заметки за все дни, изображения и папки. Сохраняется как .json — откройте в Files, сохраните в iCloud Drive или отправьте на другое устройство."
        case .restore:
            return "Текущие данные будут полностью заменены. Выберите файл .json, созданный этим приложением."
        case .info:
            return nil
        }
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .export:
            var cfg = cell.defaultContentConfiguration()
            cfg.text = "Создать резервную копию"
            let allCards  = CardStore.shared.allDTOs().count
            let allDays   = Set(CardStore.shared.allDTOs().map {
                Calendar.current.startOfDay(for: $0.dayDate)
            }).count
            cfg.secondaryText = "\(allCards) заметок за \(allDays) \(dayWord(allDays))"
            cfg.image = UIImage(systemName: "arrow.up.doc.fill")
            cfg.imageProperties.tintColor = .systemBlue
            cell.contentConfiguration = cfg
            cell.accessoryType = .disclosureIndicator

        case .restore:
            var cfg = cell.defaultContentConfiguration()
            cfg.text = "Восстановить из файла"
            cfg.secondaryText = "Выбрать .json файл резервной копии"
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
            cfg.text = """
            Заметок всего: \(cards)
            Дней с заметками: \(days)
            С изображениями: \(imgs)
            Папок: \(folders)
            """
            cfg.textProperties.font = .systemFont(ofSize: 14)
            cfg.textProperties.color = .secondaryLabel
            cfg.textProperties.numberOfLines = 0
            cell.contentConfiguration = cfg
            cell.selectionStyle = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .export:  exportBackup()
        case .restore: importBackup()
        case .info:    break
        }
    }

    // MARK: Word forms

    private func dayWord(_ n: Int) -> String {
        let mod10  = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 { return "дней" }
        switch mod10 {
        case 1:  return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
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
