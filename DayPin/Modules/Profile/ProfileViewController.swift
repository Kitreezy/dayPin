import UIKit
import PhotosUI

final class ProfileViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let headerView = ProfileHeaderView()

    private enum Section: Int, CaseIterable {
        case profile, sync, notifications
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.profile
        view.backgroundColor = DayPinDesign.background
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close)
        )
        setupTable()
        observeNotifications()
        refreshHeader()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onProfileUpdated),
            name: .dayPinProfileUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onSyncStatusChanged),
            name: .dayPinSyncStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onProfileUpdated() {
        refreshHeader()
        tableView.reloadData()
    }

    @objc private func onSyncStatusChanged() {
        tableView.reloadSections(IndexSet(integer: Section.sync.rawValue), with: .none)
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        tableView.reloadData()
    }

    // MARK: - Setup

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Header
        headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 130)
        headerView.onChangePhoto = { [weak self] in self?.changePhoto() }
        tableView.tableHeaderView = headerView
    }

    private func refreshHeader() {
        headerView.configure(
            image: ProfileManager.shared.avatarImage,
            initials: ProfileManager.shared.initials,
            name: ProfileManager.shared.displayName.isEmpty ? L10n.iCloudAccount : ProfileManager.shared.displayName,
            email: ProfileManager.shared.email
        )
    }

    // MARK: - Actions

    @objc private func close() { dismiss(animated: true) }

    private func changePhoto() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func syncNow() {
        Task { await CloudSyncManager.shared.syncAll() }
    }

    private func toggleNotifications(_ isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: "daypin.notifications.syncChanges")
    }

    private func disconnectICloud() {
        GlassAlert.confirm(
            in: self,
            title: L10n.disconnectICloud,
            message: L10n.disconnectICloudMessage,
            confirmTitle: L10n.disconnect
        ) {
            // In a real implementation: disable sync, clear cloud sub
            UserDefaults.standard.set(false, forKey: "daypin.icloud.enabled")
            NotificationCenter.default.post(name: .dayPinSyncStatusChanged, object: nil)
        }
    }
}

// MARK: - UITableViewDataSource + Delegate

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .profile: return 1
        case .sync: return 2
        case .notifications: return 2
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .profile: return nil
        case .sync: return L10n.iCloudSync
        case .notifications: return L10n.notifications
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.selectionStyle = .default

        switch Section(rawValue: indexPath.section) {

        case .profile:
            var cfg = cell.defaultContentConfiguration()
            cfg.text = L10n.editProfile
            cfg.image = UIImage(systemName: "person.crop.circle")
            cfg.imageProperties.tintColor = DayPinDesign.accent
            cell.contentConfiguration = cfg
            cell.accessoryType = .disclosureIndicator

        case .sync:
            switch indexPath.row {
            case 0:
                var cfg = cell.defaultContentConfiguration()
                cfg.image = UIImage(systemName: "icloud.and.arrow.up")
                cfg.imageProperties.tintColor = DayPinDesign.accent
                cfg.text = L10n.syncNow

                switch CloudSyncManager.shared.status {
                case .idle:
                    cfg.secondaryText = L10n.syncReady
                case .syncing:
                    cfg.secondaryText = L10n.syncing
                    cell.selectionStyle = .none
                case .synced(let date):
                    let df = DateFormatter()
                    df.timeStyle = .short
                    df.locale = L10n.activeLocale
                    cfg.secondaryText = L10n.syncedAt(df.string(from: date))
                case .error(let msg):
                    cfg.secondaryText = msg
                    cfg.secondaryTextProperties.color = .systemRed
                case .disabled:
                    cfg.text = L10n.iCloudNotAvailable
                    cfg.secondaryText = L10n.iCloudNotAvailableHint
                    cfg.secondaryTextProperties.numberOfLines = 0
                    cell.selectionStyle = .none
                }
                cell.contentConfiguration = cfg

            case 1:
                var cfg = cell.defaultContentConfiguration()
                cfg.image = UIImage(systemName: "xmark.icloud")
                cfg.imageProperties.tintColor = .systemRed
                cfg.text = L10n.disconnectICloud
                cfg.textProperties.color = .systemRed
                cell.contentConfiguration = cfg

            default: break
            }

        case .notifications:
            switch indexPath.row {
            case 0:
                var cfg = cell.defaultContentConfiguration()
                cfg.image = UIImage(systemName: "bell")
                cfg.imageProperties.tintColor = DayPinDesign.accent
                cfg.text = L10n.notifyOnChanges
                cfg.secondaryText = L10n.notifyOnChangesHint
                cfg.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = cfg
                let toggle = UISwitch()
                toggle.isOn = UserDefaults.standard.bool(forKey: "daypin.notifications.syncChanges")
                toggle.onTintColor = DayPinDesign.accent
                toggle.addAction(UIAction { [weak self] _ in self?.toggleNotifications(toggle.isOn) }, for: .valueChanged)
                cell.accessoryView = toggle
                cell.selectionStyle = .none

            case 1:
                var cfg = cell.defaultContentConfiguration()
                cfg.image = UIImage(systemName: "iphone.radiowaves.left.and.right")
                cfg.imageProperties.tintColor = .secondaryLabel
                cfg.text = L10n.pushWhenAppClosed
                cfg.textProperties.color = .secondaryLabel
                cfg.secondaryText = L10n.pushWhenAppClosedHint
                cfg.secondaryTextProperties.numberOfLines = 0
                cell.contentConfiguration = cfg
                cell.selectionStyle = .none

            default: break
            }

        default: break
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .profile:
            changePhoto()
        case .sync:
            if indexPath.row == 0 { syncNow() }
            else if indexPath.row == 1 { disconnectICloud() }
        default: break
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ProfileViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            Task {
                await ProfileManager.shared.uploadAvatar(image)
            }
        }
    }
}

// MARK: - ProfileHeaderView

private final class ProfileHeaderView: UIView {

    var onChangePhoto: (() -> Void)?

    private let avatarView = AvatarView(size: 72)
    private let cameraBtn = UIButton(type: .system)
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        // Camera badge on avatar
        let camCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        cameraBtn.setImage(UIImage(systemName: "camera.fill", withConfiguration: camCfg), for: .normal)
        cameraBtn.backgroundColor = DayPinDesign.accent
        cameraBtn.tintColor = .white
        cameraBtn.layer.cornerRadius = 12
        cameraBtn.layer.borderWidth = 2
        cameraBtn.layer.borderColor = UIColor.systemBackground.cgColor
        cameraBtn.translatesAutoresizingMaskIntoConstraints = false
        cameraBtn.addAction(UIAction { [weak self] _ in self?.onChangePhoto?() }, for: .touchUpInside)

        nameLabel.font = .inter(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        emailLabel.font = .inter(ofSize: 13)
        emailLabel.textColor = .secondaryLabel
        emailLabel.textAlignment = .center
        emailLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(avatarView)
        addSubview(cameraBtn)
        addSubview(nameLabel)
        addSubview(emailLabel)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            avatarView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 72),
            avatarView.heightAnchor.constraint(equalToConstant: 72),

            cameraBtn.widthAnchor.constraint(equalToConstant: 24),
            cameraBtn.heightAnchor.constraint(equalToConstant: 24),
            cameraBtn.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            cameraBtn.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),

            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            emailLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            emailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            emailLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }

    func configure(image: UIImage?, initials: String, name: String, email: String) {
        avatarView.configure(image: image, initials: initials)
        nameLabel.text = name
        emailLabel.text = email.isEmpty ? " " : email
    }
}
