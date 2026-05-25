import UIKit

// MARK: - FolderPickerBottomSheet
//
// Bottom-sheet folder picker with explicit confirmation.
// Tap a folder to select it (highlighted with checkmark).
// A floating "Apply" button slides up — tap to confirm and close.
// onPick(nil) = remove from any folder.

final class FolderPickerBottomSheet: UIViewController {

    // MARK: - Public API

    /// Called on confirmation. `nil` = "No folder" (detach from folder).
    var onPick: ((Folder?) -> Void)?

    // MARK: - Selection state
    //
    // hasSelection = false  → nothing tapped yet (shows currentFolderID as highlighted)
    // hasSelection = true,  selectedFolderID = nil  → "No folder" tile selected
    // hasSelection = true,  selectedFolderID = uuid → that folder selected

    private var hasSelection = false
    private var selectedFolderID: UUID? = nil   // nil inside hasSelection = "no folder"

    // MARK: - Data

    private var folders: [Folder] = []
    private let currentFolderID: UUID?

    // MARK: - UI

    private lazy var collectionView: UICollectionView = makeCollectionView()

    // Apply button (NotePickerViewController pattern)
    private let applyOuter = UIView()
    private let applyBlur  = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let applyBtn   = UIButton(type: .system)
    private var applyBottomConstraint: NSLayoutConstraint!

    // MARK: - Init

    init(currentFolderID: UUID? = nil) {
        self.currentFolderID = currentFolderID
        super.init(nibName: nil, bundle: nil)
        title = L10n.chooseFolderTitle
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        setupNav()
        setupCollectionView()
        setupApplyButton()
        observeNotifications()
        loadFolders()
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        title = L10n.chooseFolderTitle
        navigationItem.leftBarButtonItem?.title = L10n.cancel
        refreshApplyTitle()
        collectionView.reloadData()
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        applyBtn.tintColor = DayPinDesign.accent
        refreshApplyBorder()
        collectionView.reloadData()
    }

    // MARK: - Setup

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.cancel, style: .plain,
            target: self, action: #selector(cancelTapped)
        )
    }

    private func setupCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    private func setupApplyButton() {
        // Outer shadow wrapper
        applyOuter.layer.cornerRadius = 16
        applyOuter.layer.shadowColor   = UIColor.black.cgColor
        applyOuter.layer.shadowOpacity = 0.14
        applyOuter.layer.shadowRadius  = 14
        applyOuter.layer.shadowOffset  = CGSize(width: 0, height: 4)
        applyOuter.translatesAutoresizingMaskIntoConstraints = false

        // Blur container
        applyBlur.layer.cornerRadius = 16
        applyBlur.clipsToBounds = true
        applyBlur.layer.borderWidth = 0.5
        applyBlur.translatesAutoresizingMaskIntoConstraints = false
        applyOuter.addSubview(applyBlur)

        // Tint overlay
        let tint = UIView()
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.10)
                : UIColor(white: 1, alpha: 0.65)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        applyBlur.contentView.addSubview(tint)

        // Button
        applyBtn.setTitle(L10n.apply, for: .normal)
        applyBtn.titleLabel?.font = .inter(ofSize: 15, weight: .semibold)
        applyBtn.tintColor = DayPinDesign.accent
        applyBtn.translatesAutoresizingMaskIntoConstraints = false
        applyBtn.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        applyBlur.contentView.addSubview(applyBtn)

        view.addSubview(applyOuter)

        // Start hidden below the safe area
        applyBottomConstraint = applyOuter.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 80)

        NSLayoutConstraint.activate([
            applyBlur.topAnchor.constraint(equalTo: applyOuter.topAnchor),
            applyBlur.leadingAnchor.constraint(equalTo: applyOuter.leadingAnchor),
            applyBlur.trailingAnchor.constraint(equalTo: applyOuter.trailingAnchor),
            applyBlur.bottomAnchor.constraint(equalTo: applyOuter.bottomAnchor),

            tint.topAnchor.constraint(equalTo: applyBlur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: applyBlur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: applyBlur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: applyBlur.contentView.bottomAnchor),

            applyBtn.topAnchor.constraint(equalTo: applyBlur.contentView.topAnchor),
            applyBtn.leadingAnchor.constraint(equalTo: applyBlur.contentView.leadingAnchor),
            applyBtn.trailingAnchor.constraint(equalTo: applyBlur.contentView.trailingAnchor),
            applyBtn.bottomAnchor.constraint(equalTo: applyBlur.contentView.bottomAnchor),
            applyBtn.heightAnchor.constraint(equalToConstant: 52),

            applyOuter.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyOuter.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyBottomConstraint
        ])

        refreshApplyBorder()
    }

    private func refreshApplyBorder() {
        let dark = traitCollection.userInterfaceStyle == .dark
        applyBlur.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.18).cgColor
            : UIColor.black.withAlphaComponent(0.12).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshApplyBorder()
        }
    }

    // MARK: - Data

    private func loadFolders() {
        folders = FolderStore.shared.all()
        collectionView.reloadData()
    }

    // MARK: - Selection helpers

    /// Whether `folder` (nil = "no folder") is the currently-highlighted tile.
    private func isHighlighted(folderID: UUID?) -> Bool {
        if hasSelection {
            return selectedFolderID == folderID
        } else {
            return currentFolderID == folderID
        }
    }

    private func select(folderID: UUID?) {
        let prev = hasSelection ? selectedFolderID : currentFolderID
        hasSelection = true
        selectedFolderID = folderID
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Reload only changed cells for smooth animation
        var toReload: [IndexPath] = []
        if prev != folderID {
            // Deselect previous
            if let prevID = prev, let idx = folders.firstIndex(where: { $0.id == prevID }) {
                toReload.append(IndexPath(item: idx + 1, section: 0))
            } else if prev == nil {
                toReload.append(IndexPath(item: 0, section: 0))
            }
            // Select new
            if let newID = folderID, let idx = folders.firstIndex(where: { $0.id == newID }) {
                toReload.append(IndexPath(item: idx + 1, section: 0))
            } else if folderID == nil {
                toReload.append(IndexPath(item: 0, section: 0))
            }
        }
        collectionView.reloadItems(at: toReload)
        showApplyButton(true)
        refreshApplyTitle()
    }

    private func refreshApplyTitle() {
        guard hasSelection else { return }
        if let id = selectedFolderID,
           let folder = folders.first(where: { $0.id == id }) {
            let title = L10n.isRussian
                ? "В папку «\(folder.name)»"
                : "Move to \"\(folder.name)\""
            applyBtn.setTitle(title, for: .normal)
        } else {
            applyBtn.setTitle(L10n.noFolder, for: .normal)
        }
    }

    private func showApplyButton(_ show: Bool) {
        let target: CGFloat = show ? -16 : 80
        guard applyBottomConstraint.constant != target else { return }
        applyBottomConstraint.constant = target
        UIView.animate(withDuration: 0.38, delay: 0,
                       usingSpringWithDamping: 0.78, initialSpringVelocity: 0.3) {
            self.view.layoutIfNeeded()
        }
        UIView.animate(withDuration: 0.25) {
            self.collectionView.contentInset.bottom = show ? 76 : 8
        }
    }

    // MARK: - Factory

    private func makeCollectionView() -> UICollectionView {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(148))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1), heightDimension: .absolute(148))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 11, bottom: 24, trailing: 11)
        section.interGroupSpacing = 10

        let layout = UICollectionViewCompositionalLayout(section: section)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        cv.register(FolderPickerCell.self, forCellWithReuseIdentifier: FolderPickerCell.reuseID)
        cv.register(NoFolderCell.self,     forCellWithReuseIdentifier: NoFolderCell.reuseID)
        return cv
    }

    // MARK: - Actions

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func applyTapped() {
        guard hasSelection else { return }
        let folder = selectedFolderID.flatMap { id in folders.first(where: { $0.id == id }) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onPick?(folder)
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension FolderPickerBottomSheet: UICollectionViewDataSource {

    // Total items = "No Folder" cell + all folders
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1 + folders.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Index 0 = "No folder" tile
        if indexPath.item == 0 {
            guard let cell = cv.dequeueReusableCell(
                withReuseIdentifier: NoFolderCell.reuseID, for: indexPath) as? NoFolderCell
            else { return UICollectionViewCell() }
            cell.configure(isActive: isHighlighted(folderID: nil))
            return cell
        }
        let folder = folders[indexPath.item - 1]
        guard let cell = cv.dequeueReusableCell(
            withReuseIdentifier: FolderPickerCell.reuseID, for: indexPath) as? FolderPickerCell
        else { return UICollectionViewCell() }
        let cards = CardStore.shared.cards(inFolder: folder.id)
        cell.configure(folder: folder, cardCount: cards.count,
                       isActive: isHighlighted(folderID: folder.id))
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension FolderPickerBottomSheet: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            select(folderID: nil)
        } else {
            select(folderID: folders[indexPath.item - 1].id)
        }
    }
}

// MARK: - FolderPickerCell

private final class FolderPickerCell: UICollectionViewCell {

    static let reuseID = "FolderPickerCell"

    // Outer shadow wrapper
    private let outer = UIView()
    // Glass blur card
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let tint = UIView()
    // Header gradient
    private let headerGrad = CAGradientLayer()
    // Folder icon / emoji / photo
    private let photoView  = UIImageView()
    private let emojiLabel = UILabel()
    private let iconView   = UIImageView()
    // Island (bottom pill)
    private let islandBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let islandTint = UIView()
    private let nameLabel  = UILabel()
    private let countLabel = UILabel()
    // Active checkmark ring
    private let checkRing  = UIView()
    private let checkIcon  = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // ── Outer shadow ──
        outer.layer.cornerRadius = 18
        outer.layer.shadowColor   = UIColor.black.cgColor
        outer.layer.shadowOpacity = 0.12
        outer.layer.shadowRadius  = 10
        outer.layer.shadowOffset  = CGSize(width: 0, height: 4)
        outer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: contentView.topAnchor),
            outer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            outer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // ── Glass blur ──
        blur.layer.cornerRadius = 18
        blur.clipsToBounds = true
        blur.layer.borderWidth  = 0.5
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: outer.topAnchor),
            blur.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: outer.bottomAnchor)
        ])

        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.04)
                : UIColor(white: 1, alpha: 0.50)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        // ── Header gradient (full card, masked by corner radius) ──
        headerGrad.startPoint = CGPoint(x: 0, y: 0)
        headerGrad.endPoint   = CGPoint(x: 1, y: 1)
        blur.contentView.layer.insertSublayer(headerGrad, at: 0)

        // ── Photo / emoji / icon ──
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(photoView)
        NSLayoutConstraint.activate([
            photoView.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            photoView.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            photoView.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        emojiLabel.font = .inter(ofSize: 36)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(emojiLabel)
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor, constant: -20)
        ])

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.image = UIImage(systemName: "folder.fill", withConfiguration: iconCfg)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor, constant: -20),
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34)
        ])

        // ── Island bottom pill ──
        islandBlur.layer.cornerRadius = 18
        islandBlur.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        islandBlur.clipsToBounds = true
        islandBlur.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(islandBlur)
        NSLayoutConstraint.activate([
            islandBlur.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            islandBlur.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            islandBlur.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            islandBlur.heightAnchor.constraint(equalToConstant: 52)
        ])

        islandTint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0, alpha: 0.38)
                : UIColor(white: 0, alpha: 0.20)
        }
        islandTint.translatesAutoresizingMaskIntoConstraints = false
        islandBlur.contentView.addSubview(islandTint)
        NSLayoutConstraint.activate([
            islandTint.topAnchor.constraint(equalTo: islandBlur.contentView.topAnchor),
            islandTint.leadingAnchor.constraint(equalTo: islandBlur.contentView.leadingAnchor),
            islandTint.trailingAnchor.constraint(equalTo: islandBlur.contentView.trailingAnchor),
            islandTint.bottomAnchor.constraint(equalTo: islandBlur.contentView.bottomAnchor)
        ])

        nameLabel.font = .inter(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        islandBlur.contentView.addSubview(nameLabel)

        countLabel.font = .inter(ofSize: 11, weight: .regular)
        countLabel.textColor = UIColor.white.withAlphaComponent(0.60)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        islandBlur.contentView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: islandBlur.contentView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: islandBlur.contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: islandBlur.contentView.trailingAnchor, constant: -36),

            countLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            countLabel.leadingAnchor.constraint(equalTo: islandBlur.contentView.leadingAnchor, constant: 12),
            countLabel.trailingAnchor.constraint(equalTo: islandBlur.contentView.trailingAnchor, constant: -12)
        ])

        // ── Active checkmark ring (top-right corner) ──
        checkRing.layer.cornerRadius = 12
        checkRing.layer.borderWidth  = 2
        checkRing.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(checkRing)
        NSLayoutConstraint.activate([
            checkRing.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 10),
            checkRing.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -10),
            checkRing.widthAnchor.constraint(equalToConstant: 24),
            checkRing.heightAnchor.constraint(equalToConstant: 24)
        ])

        let chkCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        checkIcon.image = UIImage(systemName: "checkmark", withConfiguration: chkCfg)
        checkIcon.tintColor = .white
        checkIcon.contentMode = .scaleAspectFit
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkRing.addSubview(checkIcon)
        NSLayoutConstraint.activate([
            checkIcon.centerXAnchor.constraint(equalTo: checkRing.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkRing.centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        headerGrad.frame = blur.contentView.bounds
    }

    func configure(folder: Folder, cardCount: Int, isActive: Bool) {
        let base = UIColor(hex: folder.colorHex) ?? DayPinDesign.accent
        let dark = base.darkened(by: 0.20)

        headerGrad.colors = [base.cgColor, dark.cgColor]
        outer.layer.shadowColor = base.cgColor

        if let data = folder.iconImageData, let img = UIImage(data: data) {
            photoView.image = img
            photoView.isHidden = false
            emojiLabel.isHidden = true
            iconView.isHidden = true
        } else if let emoji = folder.emojiIcon, !emoji.isEmpty {
            emojiLabel.text = emoji
            photoView.isHidden = true
            emojiLabel.isHidden = false
            iconView.isHidden = true
        } else {
            photoView.isHidden = true
            emojiLabel.isHidden = true
            iconView.isHidden = false
            iconView.tintColor = .white.withAlphaComponent(0.90)
        }

        nameLabel.text = folder.name
        let n = cardCount
        countLabel.text = L10n.isRussian
            ? "\(n) \(pluralRu(n))"
            : "\(n) note\(n == 1 ? "" : "s")"

        applyActive(isActive, accent: base)
    }

    private func applyActive(_ active: Bool, accent: UIColor) {
        if active {
            checkRing.backgroundColor = accent
            checkRing.layer.borderColor = UIColor.white.withAlphaComponent(0.40).cgColor
            checkIcon.isHidden = false
            outer.layer.shadowOpacity = 0.30
            outer.layer.shadowRadius  = 16
        } else {
            checkRing.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            checkRing.layer.borderColor = UIColor.white.withAlphaComponent(0.30).cgColor
            checkIcon.isHidden = true
            outer.layer.shadowOpacity = 0.12
            outer.layer.shadowRadius  = 10
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }

    private func pluralRu(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "заметка" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "заметки" }
        return "заметок"
    }
}

// MARK: - NoFolderCell

private final class NoFolderCell: UICollectionViewCell {

    static let reuseID = "NoFolderCell"

    private let outer = UIView()
    private let blur  = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let tint  = UIView()
    private let icon  = UIImageView()
    private let label = UILabel()
    private let sub   = UILabel()
    private let checkRing = UIView()
    private let checkIcon = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        outer.layer.cornerRadius  = 18
        outer.layer.shadowColor   = UIColor.black.cgColor
        outer.layer.shadowOpacity = 0.08
        outer.layer.shadowRadius  = 8
        outer.layer.shadowOffset  = CGSize(width: 0, height: 3)
        outer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: contentView.topAnchor),
            outer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            outer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        blur.layer.cornerRadius = 18
        blur.clipsToBounds = true
        blur.layer.borderWidth  = 0.5
        blur.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor
        blur.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: outer.topAnchor),
            blur.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: outer.bottomAnchor)
        ])

        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.05)
                : UIColor(white: 0.92, alpha: 0.70)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor)
        ])

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 26, weight: .light)
        icon.image = UIImage(systemName: "folder.badge.minus", withConfiguration: iconCfg)
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(icon)

        label.text = L10n.noFolder
        label.font = .inter(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(label)

        sub.text = L10n.noFolderHint
        sub.font = .inter(ofSize: 11, weight: .regular)
        sub.textColor = .secondaryLabel
        sub.textAlignment = .center
        sub.numberOfLines = 2
        sub.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(sub)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor, constant: -28),
            icon.widthAnchor.constraint(equalToConstant: 34),
            icon.heightAnchor.constraint(equalToConstant: 34),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -8),

            sub.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            sub.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 8),
            sub.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -8)
        ])

        // Active ring
        checkRing.layer.cornerRadius = 12
        checkRing.layer.borderWidth  = 2
        checkRing.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(checkRing)
        NSLayoutConstraint.activate([
            checkRing.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 10),
            checkRing.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -10),
            checkRing.widthAnchor.constraint(equalToConstant: 24),
            checkRing.heightAnchor.constraint(equalToConstant: 24)
        ])
        let chkCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        checkIcon.image = UIImage(systemName: "checkmark", withConfiguration: chkCfg)
        checkIcon.tintColor = .white
        checkIcon.contentMode = .scaleAspectFit
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkRing.addSubview(checkIcon)
        NSLayoutConstraint.activate([
            checkIcon.centerXAnchor.constraint(equalTo: checkRing.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkRing.centerYAnchor)
        ])
    }

    func configure(isActive: Bool) {
        label.text = L10n.noFolder
        sub.text = L10n.noFolderHint
        if isActive {
            checkRing.backgroundColor = DayPinDesign.accent
            checkRing.layer.borderColor = UIColor.white.withAlphaComponent(0.40).cgColor
            checkIcon.isHidden = false
        } else {
            checkRing.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.15)
            checkRing.layer.borderColor = UIColor.secondaryLabel.withAlphaComponent(0.30).cgColor
            checkIcon.isHidden = true
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            }
        }
    }
}

// MARK: - UIColor darkened helper (if not already in Extensions)

private extension UIColor {
    func darkened(by fraction: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, br * (1 - fraction)), alpha: a)
    }
}
