import UIKit

// MARK: - ProfileViewController

final class ProfileViewController: UIViewController {

    // MARK: - State

    private var shares: [ShareItem] = []
    private var syncStatus: SyncStatusResponse?
    private var isLoadingShares = true
    private var isLoadingStatus = true

    // Skeleton placeholders
    private let statusSkeletons: [SkeletonView] = (0..<3).map { _ in
        let s = SkeletonView()
        s.layer.cornerRadius = 10
        return s
    }
    private let shareSkeletons: [SkeletonView] = (0..<2).map { _ in
        let s = SkeletonView()
        s.layer.cornerRadius = 14
        return s
    }

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    // Profile header card
    private let headerCard = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let emailLabel = UILabel()
    private let userIDLabel = UILabel()

    // Sync card
    private let syncCard = UIView()
    private let syncBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let syncTitleLabel = UILabel()
    private let syncInfoLabel = UILabel()
    private let pushBtn = UIButton(type: .system)
    private let pullBtn = UIButton(type: .system)
    private let syncSpinner = UIActivityIndicatorView(style: .medium)
    private let cacheRestoreBtn = UIButton(type: .system)

    // Shares section
    private let sharesSectionLabel = UILabel()
    private let sharesStack = UIStackView()

    // Footer
    private let signOutBtn = UIButton(type: .system)
    private let signInPromptBtn = UIButton(type: .system)
    private let deleteAccountBtn = UIButton(type: .system)
    private let serverURLLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.isRussian ? "Профиль" : "Profile"
        view.backgroundColor = DayPinDesign.background
        addStandardBackground()
        setupUI()
        observeNotifications()
        renderAuthState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        renderAuthState()
        loadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(onAuthChanged),
            name: .dayPinAuthStateChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onSyncStateChanged),
            name: .dayPinSyncStateChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil
        )
    }

    @objc private func onAuthChanged() {
        renderAuthState()
        if AuthService.shared.isLoggedIn {
            loadData()
        } else {
            shares = []
            syncStatus = nil
            isLoadingShares = false
            isLoadingStatus = false
            updateSkeletonVisibility()
            rebuildShareRows()
            updateSyncCard()
        }
    }

    @objc private func onSyncStateChanged() {
        let syncing = SyncService.shared.isSyncing
        pushBtn.isEnabled = !syncing
        pullBtn.isEnabled = !syncing
        if syncing {
            syncSpinner.startAnimating()
        } else {
            syncSpinner.stopAnimating()
            loadSyncStatus()
        }
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        renderAuthState()
        updateSyncCard()
    }

    // MARK: - Setup

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40)
        ])

        buildHeaderCard()
        buildSyncCard()
        buildSharesSection()
        buildFooter()
    }

    // MARK: - Header card

    private func buildHeaderCard() {
        headerCard.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.12, alpha: 1)
                : UIColor(white: 0.97, alpha: 1)
        }
        headerCard.layer.cornerRadius = 20
        headerCard.layer.borderWidth = 0.5
        headerCard.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(headerCard)

        // Avatar circle
        avatarView.layer.cornerRadius = 28
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.font = .inter(ofSize: 20, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarLabel)
        headerCard.addSubview(avatarView)

        emailLabel.font = .inter(ofSize: 16, weight: .semibold)
        emailLabel.textColor = .label
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(emailLabel)

        userIDLabel.font = .inter(ofSize: 11, weight: .regular)
        userIDLabel.textColor = .tertiaryLabel
        userIDLabel.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(userIDLabel)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 20),
            avatarView.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            emailLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor, constant: -8),
            emailLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            emailLabel.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -16),

            userIDLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 4),
            userIDLabel.leadingAnchor.constraint(equalTo: emailLabel.leadingAnchor),
            userIDLabel.trailingAnchor.constraint(equalTo: emailLabel.trailingAnchor),
            userIDLabel.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -20)
        ])

        refreshHeaderBorderColor()
    }

    // MARK: - Sync card (glass blur)

    private func buildSyncCard() {
        let shadow = UIView()
        shadow.layer.cornerRadius = 20
        shadow.layer.shadowColor = UIColor.black.cgColor
        shadow.layer.shadowOpacity = 0.10
        shadow.layer.shadowRadius = 16
        shadow.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(shadow)

        syncBlur.layer.cornerRadius = 20
        syncBlur.layer.borderWidth = 0.5
        syncBlur.clipsToBounds = true
        syncBlur.translatesAutoresizingMaskIntoConstraints = false
        shadow.addSubview(syncBlur)

        let tint = UIView()
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.07)
                : UIColor(white: 1, alpha: 0.55)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        syncBlur.contentView.addSubview(tint)

        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)

        syncTitleLabel.text = L10n.isRussian ? "Облако" : "Cloud Sync"
        syncTitleLabel.font = .inter(ofSize: 15, weight: .semibold)
        syncTitleLabel.textColor = .label
        syncTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        syncBlur.contentView.addSubview(syncTitleLabel)

        syncInfoLabel.font = .inter(ofSize: 13, weight: .regular)
        syncInfoLabel.textColor = .secondaryLabel
        syncInfoLabel.numberOfLines = 2
        syncInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        syncBlur.contentView.addSubview(syncInfoLabel)

        syncSpinner.color = DayPinDesign.accent
        syncSpinner.hidesWhenStopped = true
        syncSpinner.translatesAutoresizingMaskIntoConstraints = false
        syncBlur.contentView.addSubview(syncSpinner)

        pushBtn.setImage(UIImage(systemName: "arrow.up.to.line.circle.fill", withConfiguration: cfg), for: .normal)
        pushBtn.setTitle(L10n.isRussian ? "  Загрузить" : "  Push", for: .normal)
        pushBtn.titleLabel?.font = .inter(ofSize: 13, weight: .medium)
        pushBtn.tintColor = DayPinDesign.accent
        pushBtn.backgroundColor = DayPinDesign.accent.withAlphaComponent(0.12)
        pushBtn.layer.cornerRadius = 12
        pushBtn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        pushBtn.translatesAutoresizingMaskIntoConstraints = false
        pushBtn.addTarget(self, action: #selector(pushTapped), for: .touchUpInside)
        syncBlur.contentView.addSubview(pushBtn)

        pullBtn.setImage(UIImage(systemName: "arrow.down.to.line.circle.fill", withConfiguration: cfg), for: .normal)
        pullBtn.setTitle(L10n.isRussian ? "  Скачать" : "  Pull", for: .normal)
        pullBtn.titleLabel?.font = .inter(ofSize: 13, weight: .medium)
        pullBtn.tintColor = .secondaryLabel
        pullBtn.backgroundColor = UIColor.secondarySystemFill
        pullBtn.layer.cornerRadius = 12
        pullBtn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        pullBtn.translatesAutoresizingMaskIntoConstraints = false
        pullBtn.addTarget(self, action: #selector(pullTapped), for: .touchUpInside)
        syncBlur.contentView.addSubview(pullBtn)

        cacheRestoreBtn.setTitle(
            L10n.isRussian ? "Восстановить из кэша" : "Restore from cache",
            for: .normal
        )
        cacheRestoreBtn.titleLabel?.font = .inter(ofSize: 12, weight: .regular)
        cacheRestoreBtn.tintColor = .tertiaryLabel
        cacheRestoreBtn.translatesAutoresizingMaskIntoConstraints = false
        cacheRestoreBtn.isHidden = !SyncService.shared.hasCachedBackup
        cacheRestoreBtn.addTarget(self, action: #selector(restoreFromCacheTapped), for: .touchUpInside)
        syncBlur.contentView.addSubview(cacheRestoreBtn)

        // Skeleton placeholders (positioned in layoutSubviews via constraints after view loads)
        let skTexts: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 120), (0, 20, 80), (40, 0, 160)
        ]
        for (i, sk) in statusSkeletons.enumerated() {
            sk.translatesAutoresizingMaskIntoConstraints = false
            syncBlur.contentView.addSubview(sk)
            NSLayoutConstraint.activate([
                sk.topAnchor.constraint(equalTo: syncInfoLabel.topAnchor, constant: skTexts[i].0),
                sk.leadingAnchor.constraint(equalTo: syncInfoLabel.leadingAnchor, constant: skTexts[i].1),
                sk.widthAnchor.constraint(equalToConstant: skTexts[i].2),
                sk.heightAnchor.constraint(equalToConstant: 14)
            ])
            sk.startAnimating()
        }

        NSLayoutConstraint.activate([
            shadow.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            syncBlur.topAnchor.constraint(equalTo: shadow.topAnchor),
            syncBlur.leadingAnchor.constraint(equalTo: shadow.leadingAnchor),
            syncBlur.trailingAnchor.constraint(equalTo: shadow.trailingAnchor),
            syncBlur.bottomAnchor.constraint(equalTo: shadow.bottomAnchor),

            tint.topAnchor.constraint(equalTo: syncBlur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: syncBlur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: syncBlur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: syncBlur.contentView.bottomAnchor),

            syncTitleLabel.topAnchor.constraint(equalTo: syncBlur.contentView.topAnchor, constant: 16),
            syncTitleLabel.leadingAnchor.constraint(equalTo: syncBlur.contentView.leadingAnchor, constant: 16),

            syncSpinner.centerYAnchor.constraint(equalTo: syncTitleLabel.centerYAnchor),
            syncSpinner.leadingAnchor.constraint(equalTo: syncTitleLabel.trailingAnchor, constant: 8),

            syncInfoLabel.topAnchor.constraint(equalTo: syncTitleLabel.bottomAnchor, constant: 6),
            syncInfoLabel.leadingAnchor.constraint(equalTo: syncBlur.contentView.leadingAnchor, constant: 16),
            syncInfoLabel.trailingAnchor.constraint(equalTo: syncBlur.contentView.trailingAnchor, constant: -16),
            syncInfoLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),

            pushBtn.topAnchor.constraint(equalTo: syncInfoLabel.bottomAnchor, constant: 12),
            pushBtn.leadingAnchor.constraint(equalTo: syncBlur.contentView.leadingAnchor, constant: 16),

            pullBtn.topAnchor.constraint(equalTo: pushBtn.topAnchor),
            pullBtn.leadingAnchor.constraint(equalTo: pushBtn.trailingAnchor, constant: 10),

            cacheRestoreBtn.topAnchor.constraint(equalTo: pushBtn.bottomAnchor, constant: 8),
            cacheRestoreBtn.leadingAnchor.constraint(equalTo: syncBlur.contentView.leadingAnchor, constant: 16),
            cacheRestoreBtn.bottomAnchor.constraint(equalTo: syncBlur.contentView.bottomAnchor, constant: -14)
        ])

        refreshSyncBlurBorder()
    }

    // MARK: - Shares section

    private func buildSharesSection() {
        let header = UILabel()
        header.font = .inter(ofSize: 17, weight: .semibold)
        header.textColor = .label
        header.text = L10n.isRussian ? "Мои ссылки" : "My Links"
        header.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)

        sharesSectionLabel.font = .inter(ofSize: 13, weight: .regular)
        sharesSectionLabel.textColor = .secondaryLabel
        sharesSectionLabel.isHidden = true
        sharesSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sharesSectionLabel)

        sharesStack.axis = .vertical
        sharesStack.spacing = 10
        sharesStack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(sharesStack)

        // Skeleton rows while loading
        for sk in shareSkeletons {
            sk.translatesAutoresizingMaskIntoConstraints = false
            sharesStack.addArrangedSubview(sk)
            sk.heightAnchor.constraint(equalToConstant: 72).isActive = true
            sk.startAnimating()
        }
    }

    // MARK: - Footer

    private func buildFooter() {
        serverURLLabel.font = .inter(ofSize: 11, weight: .regular)
        serverURLLabel.textColor = .tertiaryLabel
        serverURLLabel.textAlignment = .center
        serverURLLabel.text = "Server: \(APIClient.baseURL)"
        serverURLLabel.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(serverURLLabel)

        signOutBtn.setTitle(L10n.isRussian ? "Выйти" : "Sign Out", for: .normal)
        signOutBtn.titleLabel?.font = .inter(ofSize: 15, weight: .medium)
        signOutBtn.tintColor = DayPinDesign.accent
        signOutBtn.backgroundColor = DayPinDesign.accent.withAlphaComponent(0.10)
        signOutBtn.layer.cornerRadius = 14
        signOutBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        signOutBtn.translatesAutoresizingMaskIntoConstraints = false
        signOutBtn.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        stack.addArrangedSubview(signOutBtn)

        signInPromptBtn.setTitle(L10n.isRussian ? "Войти" : "Sign In", for: .normal)
        signInPromptBtn.titleLabel?.font = .inter(ofSize: 15, weight: .semibold)
        signInPromptBtn.tintColor = .white
        signInPromptBtn.backgroundColor = DayPinDesign.accent
        signInPromptBtn.layer.cornerRadius = 14
        signInPromptBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        signInPromptBtn.translatesAutoresizingMaskIntoConstraints = false
        signInPromptBtn.addTarget(self, action: #selector(signInPromptTapped), for: .touchUpInside)
        stack.addArrangedSubview(signInPromptBtn)

        deleteAccountBtn.setTitle(
            L10n.isRussian ? "Удалить аккаунт" : "Delete Account",
            for: .normal
        )
        deleteAccountBtn.titleLabel?.font = .inter(ofSize: 14, weight: .regular)
        deleteAccountBtn.tintColor = .systemRed
        deleteAccountBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteAccountBtn.addTarget(self, action: #selector(deleteAccountTapped), for: .touchUpInside)
        stack.addArrangedSubview(deleteAccountBtn)
    }

    // MARK: - Data loading

    private func loadData() {
        guard AuthService.shared.isLoggedIn else { return }
        loadSyncStatus()
        loadShares()
    }

    private func loadSyncStatus() {
        isLoadingStatus = true
        updateSkeletonVisibility()
        Task {
            do {
                syncStatus = try await SyncService.shared.fetchStatus()
            } catch {
                syncStatus = nil
            }
            isLoadingStatus = false
            updateSkeletonVisibility()
            updateSyncCard()
        }
    }

    private func loadShares() {
        isLoadingShares = true
        updateSkeletonVisibility()
        Task {
            do {
                shares = try await ShareService.shared.myShares()
            } catch {
                shares = []
            }
            isLoadingShares = false
            updateSkeletonVisibility()
            rebuildShareRows()
        }
    }

    // MARK: - Render

    private func renderAuthState() {
        guard let user = AuthService.shared.currentUser else {
            avatarLabel.text = "?"
            avatarView.backgroundColor = .tertiarySystemFill
            emailLabel.text = L10n.isRussian ? "Вы не авторизованы" : "Not signed in"
            userIDLabel.text = L10n.isRussian
                ? "Войдите, чтобы синхронизировать заметки"
                : "Sign in to sync your notes"

            signOutBtn.isHidden = true
            deleteAccountBtn.isHidden = true
            signInPromptBtn.isHidden = false

            pushBtn.isEnabled = false
            pullBtn.isEnabled = false
            pushBtn.alpha = 0.5
            pullBtn.alpha = 0.5

            refreshHeaderBorderColor()
            return
        }

        let initials = user.email.prefix(2).uppercased()
        avatarLabel.text = initials
        avatarView.backgroundColor = DayPinDesign.accent
        emailLabel.text = user.email
        userIDLabel.text = "ID: \(user.id)"

        signOutBtn.isHidden = false
        deleteAccountBtn.isHidden = false
        signInPromptBtn.isHidden = true

        pushBtn.isEnabled = true
        pullBtn.isEnabled = true
        pushBtn.alpha = 1
        pullBtn.alpha = 1

        refreshHeaderBorderColor()
    }

    @objc private func signInPromptTapped() {
        let signIn = SignInViewController()
        let nav = UINavigationController(rootViewController: signIn)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func updateSyncCard() {
        guard AuthService.shared.isLoggedIn else {
            syncInfoLabel.text = L10n.isRussian ? "Требуется вход" : "Sign in required"
            cacheRestoreBtn.isHidden = !SyncService.shared.hasCachedBackup
            return
        }
        guard let status = syncStatus else {
            syncInfoLabel.text = L10n.isRussian ? "Нет данных на сервере" : "No data on server"
            cacheRestoreBtn.isHidden = !SyncService.shared.hasCachedBackup
            return
        }
        if status.hasBacup, let syncedAt = status.syncedAt {
            let df = DateFormatter()
            df.locale = L10n.activeLocale
            df.dateStyle = .medium
            df.timeStyle = .short
            let sizeStr = status.sizeBytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? ""
            syncInfoLabel.text = "\(L10n.isRussian ? "Синхр." : "Synced") \(df.string(from: syncedAt))\n\(sizeStr)"
        } else {
            syncInfoLabel.text = L10n.isRussian ? "Ещё не синхронизировано" : "Not synced yet"
        }
        cacheRestoreBtn.isHidden = !SyncService.shared.hasCachedBackup
    }

    private func rebuildShareRows() {
        sharesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if shares.isEmpty {
            sharesSectionLabel.text = AuthService.shared.isLoggedIn
                ? (L10n.isRussian ? "Нет активных ссылок" : "No active links")
                : (L10n.isRussian ? "Войдите, чтобы видеть ссылки" : "Sign in to view your links")
            sharesSectionLabel.isHidden = false
            return
        }
        sharesSectionLabel.isHidden = true

        for item in shares {
            let row = buildShareRow(item)
            sharesStack.addArrangedSubview(row)
        }
    }

    private func buildShareRow(_ item: ShareItem) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.12, alpha: 1)
                : UIColor(white: 0.97, alpha: 1)
        }
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 0.5
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.3).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView()
        let iconName = item.type == "card" ? "doc.text" : "folder"
        icon.image = UIImage(systemName: iconName)
        icon.tintColor = DayPinDesign.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = item.title.isEmpty ? (L10n.isRussian ? "Без названия" : "Untitled") : item.title
        titleLbl.font = .inter(ofSize: 14, weight: .medium)
        titleLbl.textColor = .label
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        let viewsLbl = UILabel()
        viewsLbl.text = "\(item.viewCount) " + (L10n.isRussian ? "просм." : "views")
        viewsLbl.font = .inter(ofSize: 11, weight: .regular)
        viewsLbl.textColor = .tertiaryLabel
        viewsLbl.translatesAutoresizingMaskIntoConstraints = false

        let copyBtn = UIButton(type: .system)
        let copyCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        copyBtn.setImage(UIImage(systemName: "doc.on.doc", withConfiguration: copyCfg), for: .normal)
        copyBtn.tintColor = DayPinDesign.accent
        copyBtn.translatesAutoresizingMaskIntoConstraints = false

        let deleteBtn = UIButton(type: .system)
        let delCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        deleteBtn.setImage(UIImage(systemName: "trash", withConfiguration: delCfg), for: .normal)
        deleteBtn.tintColor = .systemRed
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false

        let shareID = item.shareID
        let shareURL = item.url

        copyBtn.addAction(UIAction { [weak self] _ in
            UIPasteboard.general.string = shareURL
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.showCopiedToast()
        }, for: .touchUpInside)

        deleteBtn.addAction(UIAction { [weak self] _ in
            self?.confirmDeleteShare(id: shareID)
        }, for: .touchUpInside)

        card.addSubview(icon)
        card.addSubview(titleLbl)
        card.addSubview(viewsLbl)
        card.addSubview(copyBtn)
        card.addSubview(deleteBtn)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 72),

            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            deleteBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            deleteBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            deleteBtn.widthAnchor.constraint(equalToConstant: 32),
            deleteBtn.heightAnchor.constraint(equalToConstant: 32),

            copyBtn.trailingAnchor.constraint(equalTo: deleteBtn.leadingAnchor, constant: -4),
            copyBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            copyBtn.widthAnchor.constraint(equalToConstant: 32),
            copyBtn.heightAnchor.constraint(equalToConstant: 32),

            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            titleLbl.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            titleLbl.trailingAnchor.constraint(equalTo: copyBtn.leadingAnchor, constant: -8),

            viewsLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 3),
            viewsLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor)
        ])

        return card
    }

    private func updateSkeletonVisibility() {
        // Status skeletons
        statusSkeletons.forEach { $0.isHidden = !isLoadingStatus }
        syncInfoLabel.isHidden = isLoadingStatus

        // Share skeletons
        if isLoadingShares {
            if sharesStack.arrangedSubviews.isEmpty {
                for sk in shareSkeletons {
                    sk.translatesAutoresizingMaskIntoConstraints = false
                    sharesStack.addArrangedSubview(sk)
                    sk.heightAnchor.constraint(equalToConstant: 72).isActive = true
                    sk.startAnimating()
                }
            }
        } else {
            shareSkeletons.forEach {
                $0.stopAnimating()
                $0.removeFromSuperview()
            }
        }
    }

    // MARK: - Actions

    @objc private func pushTapped() {
        Task {
            let result = await SyncService.shared.push()
            switch result {
            case .success(let summary):
                let msg = L10n.isRussian
                    ? "Загружено: \(summary.cards) заметок"
                    : "Pushed: \(summary.cards) cards"
                showBanner(msg, success: true)
            case .noChanges:
                showBanner(L10n.isRussian ? "Уже синхронизировано" : "Already up to date", success: true)
            case .noBackup:
                break
            case .failure(let error):
                showBanner(error.localizedDescription, success: false)
            }
        }
    }

    @objc private func pullTapped() {
        Task {
            let result = await SyncService.shared.pull()
            switch result {
            case .success(let summary):
                let msg = L10n.isRussian
                    ? "Восстановлено: \(summary.cards) заметок"
                    : "Pulled: \(summary.cards) cards"
                showBanner(msg, success: true)
            case .noBackup:
                showBanner(L10n.isRussian ? "Нет данных на сервере" : "Nothing to pull", success: false)
            case .noChanges:
                break  // pull() never returns this - only push() does
            case .failure(let error):
                showBanner(error.localizedDescription, success: false)
            }
        }
    }

    @objc private func restoreFromCacheTapped() {
        guard let date = SyncService.shared.cachedBackupDate else { return }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = L10n.activeLocale
        let dateStr = df.string(from: date)
        let title = L10n.isRussian ? "Восстановить из кэша?" : "Restore from cache?"
        let msg = L10n.isRussian
            ? "Кэш от \(dateStr). Текущие данные будут заменены."
            : "Cache from \(dateStr). Current data will be replaced."
        GlassAlert.confirm(
            in: self, title: title, message: msg,
            confirmTitle: L10n.isRussian ? "Восстановить" : "Restore",
            isDestructive: false
        ) { [weak self] in
            do {
                try SyncService.shared.restoreFromCache()
                self?.showBanner(L10n.isRussian ? "Данные восстановлены" : "Data restored", success: true)
            } catch {
                self?.showBanner(error.localizedDescription, success: false)
            }
        }
    }

    @objc private func signOutTapped() {
        GlassAlert.confirm(
            in: self,
            title: L10n.isRussian ? "Выйти?" : "Sign out?",
            confirmTitle: L10n.isRussian ? "Выйти" : "Sign Out",
            isDestructive: false,
            onConfirm: {
                AuthService.shared.signOut()
            }
        )
    }

    @objc private func deleteAccountTapped() {
        let alert = UIAlertController(
            title: L10n.isRussian ? "Удалить аккаунт?" : "Delete Account?",
            message: L10n.isRussian
                ? "Все данные на сервере и ссылки будут удалены. Локальные заметки останутся.\n\nВведите пароль для подтверждения."
                : "All server data and share links will be deleted. Local notes remain.\n\nEnter your password to confirm.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = L10n.isRussian ? "Пароль" : "Password"
            field.isSecureTextEntry = true
        }
        let deleteAction = UIAlertAction(
            title: L10n.isRussian ? "Удалить" : "Delete",
            style: .destructive
        ) { [weak self, weak alert] _ in
            let password = alert?.textFields?.first?.text ?? ""
            guard !password.isEmpty else { return }
            Task { [weak self] in
                do {
                    try await AuthService.shared.deleteAccount(password: password)
                } catch {
                    self?.showBanner(error.localizedDescription, success: false)
                }
            }
        }
        let cancelAction = UIAlertAction(
            title: L10n.isRussian ? "Отмена" : "Cancel",
            style: .cancel
        )
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    private func confirmDeleteShare(id: String) {
        GlassAlert.confirm(
            in: self,
            title: L10n.isRussian ? "Удалить ссылку?" : "Delete link?",
            confirmTitle: L10n.isRussian ? "Удалить" : "Delete",
            isDestructive: true,
            onConfirm: { [weak self] in
                Task {
                    do {
                        try await ShareService.shared.deleteShare(id: id)
                        self?.loadShares()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch {
                        self?.showBanner(error.localizedDescription, success: false)
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private func showCopiedToast() {
        showBanner(L10n.isRussian ? "Ссылка скопирована" : "Link copied", success: true)
    }

    private func showBanner(_ text: String, success: Bool) {
        let label = UILabel()
        label.text = text
        label.font = .inter(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = success ? DayPinDesign.accent : UIColor.systemRed
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            label.heightAnchor.constraint(equalToConstant: 40)
        ])
        label.layoutIfNeeded()
        let padding = NSMutableAttributedString(string: "  \(text)  ")
        label.attributedText = padding

        label.alpha = 0
        label.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            label.alpha = 1
            label.transform = .identity
        }
        UIView.animate(withDuration: 0.25, delay: 2.5) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }

    // MARK: - Theming

    private func refreshHeaderBorderColor() {
        let dark = traitCollection.userInterfaceStyle == .dark
        headerCard.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.10).cgColor
            : UIColor.black.withAlphaComponent(0.07).cgColor
    }

    private func refreshSyncBlurBorder() {
        let dark = traitCollection.userInterfaceStyle == .dark
        syncBlur.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.18).cgColor
            : UIColor.black.withAlphaComponent(0.12).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshHeaderBorderColor()
            refreshSyncBlurBorder()
        }
    }
}

