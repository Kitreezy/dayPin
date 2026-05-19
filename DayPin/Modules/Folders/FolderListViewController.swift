import UIKit

// MARK: - FolderListViewController

final class FolderListViewController: UIViewController {

    private var folders: [Folder] = []
    private var itemCount: Int { folders.count + 1 }

    // MARK: - Header

    private let headerContainer = UIView()
    private let titleLabel      = UILabel()

    // MARK: - Collection

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(FolderCardCell.self,    forCellWithReuseIdentifier: FolderCardCell.reuseID)
        cv.register(AddFolderCardCell.self, forCellWithReuseIdentifier: AddFolderCardCell.reuseID)
        return cv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background

        addStandardBackground()
        buildHeader()

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        collectionView.dataSource = self
        collectionView.delegate   = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSchemeChanged),
            name: .dayPinColorSchemeChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Header builder

    private func buildHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        titleLabel.text      = L10n.tabFolders
        titleLabel.font      = DayPinDesign.fontScreenTitle
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8)
        ])
    }

    @objc private func onSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        collectionView.reloadData()
    }

    @objc private func onLanguageChanged() {
        titleLabel.text = L10n.tabFolders
        collectionView.reloadData()
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                                   heightDimension: .absolute(162))
            let item      = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                   heightDimension: .absolute(162))
            let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                               subitem: item, count: 2)
            let section   = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
            return section
        }
    }

    // MARK: - Data

    private func reload() {
        folders = FolderStore.shared.all()
        collectionView.reloadData()
    }

    // MARK: - Actions

    @objc private func addFolderTapped() {
        presentFolderEditor(existing: nil)
    }

    func presentFolderEditor(existing: Folder?) {
        let vc = FolderEditorViewController(folder: existing)
        vc.onSave = { [weak self] folder in
            FolderStore.shared.save(folder)
            self?.reload()
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func deleteFolder(_ folder: Folder) {
        let alert = UIAlertController(title: L10n.deleteFolderTitle,
                                      message: L10n.deleteFolderMessage,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.delete, style: .destructive) { [weak self] _ in
            FolderStore.shared.delete(folder)
            self?.reload()
        })
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension FolderListViewController: UICollectionViewDataSource {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        itemCount
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == folders.count {
            return cv.dequeueReusableCell(withReuseIdentifier: AddFolderCardCell.reuseID, for: indexPath)
        }
        guard let cell = cv.dequeueReusableCell(withReuseIdentifier: FolderCardCell.reuseID, for: indexPath) as? FolderCardCell else {
            return UICollectionViewCell()
        }
        let folder = folders[indexPath.item]
        cell.configure(folder: folder, cards: CardStore.shared.cards(inFolder: folder.id))
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension FolderListViewController: UICollectionViewDelegate {

    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == folders.count {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            addFolderTapped()
            return
        }
        let vc = FolderDetailViewController(folder: folders[indexPath.item])
        navigationController?.pushViewController(vc, animated: true)
    }

    func collectionView(_ cv: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.item < folders.count else { return nil }
        let folder = folders[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { _ in
            let edit = UIAction(title: L10n.edit, image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentFolderEditor(existing: folder)
            }
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"),
                                  attributes: .destructive) { [weak self] _ in
                self?.deleteFolder(folder)
            }
            return UIMenu(children: [edit, delete])
        })
    }
}

// MARK: - GradientHeaderView
// Самостоятельно обновляет frame градиента в layoutSubviews — решает проблему с нулевым frame при первой загрузке

private final class GradientHeaderView: UIView {

    private let gradLayer = CAGradientLayer()

    init() {
        super.init(frame: .zero)
        gradLayer.startPoint = CGPoint(x: 0, y: 0)
        gradLayer.endPoint   = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradLayer, at: 0)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradLayer.frame = bounds           // вызывается при каждом изменении bounds
    }

    func setColors(base: UIColor) {
        gradLayer.colors = [
            darken(base, by: 0.08).cgColor,
            lighten(base, by: 0.12).cgColor
        ]
    }

    private func lighten(_ c: UIColor, by a: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha)
        return UIColor(hue: h, saturation: max(0, s - a * 0.3),
                       brightness: min(1, b + a), alpha: alpha)
    }

    private func darken(_ c: UIColor, by a: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha)
        return UIColor(hue: h, saturation: min(1, s + a * 0.1),
                       brightness: max(0, b - a), alpha: alpha)
    }
}

// MARK: - FolderCardCell

final class FolderCardCell: UICollectionViewCell {

    static let reuseID = "FolderCardCell"

    private let cardView    = GlassCardView(style: .card)
    private let header      = GradientHeaderView()

    // Иконка: изображение / эмодзи / системная SF иконка
    private let photoView   = UIImageView()
    private let emojiLabel  = UILabel()
    private let folderIcon  = UIImageView()

    private let nameLabel     = UILabel()
    private let typeBadgesRow = UIStackView()   // [📝 2] [🖼 1] [🔗 3]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 18

        // Card
        cardView.cornerRadius = 18
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let cv = cardView.glass.contentView

        // Gradient header
        header.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: cv.topAnchor),
            header.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            header.heightAnchor.constraint(equalTo: cv.heightAnchor, multiplier: 0.55)
        ])

        // Photo view (custom image)
        photoView.contentMode   = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(photoView)
        NSLayoutConstraint.activate([
            photoView.topAnchor.constraint(equalTo: header.topAnchor),
            photoView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            photoView.bottomAnchor.constraint(equalTo: header.bottomAnchor)
        ])

        // Emoji label
        emojiLabel.font          = .inter(ofSize: 40)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(emojiLabel)
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])

        // Default folder icon
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        folderIcon.image        = UIImage(systemName: "folder.fill", withConfiguration: cfg)
        folderIcon.tintColor    = .white
        folderIcon.contentMode  = .scaleAspectFit
        folderIcon.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(folderIcon)
        NSLayoutConstraint.activate([
            folderIcon.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            folderIcon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            folderIcon.widthAnchor.constraint(equalToConstant: 36),
            folderIcon.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Name label
        nameLabel.font          = .inter(ofSize: 14, weight: .semibold)
        nameLabel.textColor     = .label
        nameLabel.numberOfLines = 1
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(nameLabel)

        // Type badges row: [📝 2] [🖼 1] [🔗 3]
        typeBadgesRow.axis      = .horizontal
        typeBadgesRow.spacing   = 5
        typeBadgesRow.alignment = .center
        typeBadgesRow.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(typeBadgesRow)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -10),

            typeBadgesRow.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            typeBadgesRow.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 10),
            typeBadgesRow.bottomAnchor.constraint(lessThanOrEqualTo: cv.bottomAnchor, constant: -8)
        ])
    }

    func configure(folder: Folder, cards: [NoteCard]) {
        let base = UIColor(hex: folder.colorHex) ?? DayPinDesign.accent

        header.setColors(base: base)

        // Тень — заметно тише
        layer.shadowColor   = base.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius  = 8
        layer.shadowOffset  = CGSize(width: 0, height: 3)

        // Icon: фото → эмодзи → дефолт
        if let data = folder.iconImageData, let img = UIImage(data: data) {
            photoView.image     = img
            photoView.isHidden  = false
            emojiLabel.isHidden = true
            folderIcon.isHidden = true
        } else if let emoji = folder.emojiIcon, !emoji.isEmpty {
            emojiLabel.text     = emoji
            photoView.isHidden  = true
            emojiLabel.isHidden = false
            folderIcon.isHidden = true
        } else {
            photoView.isHidden  = true
            emojiLabel.isHidden = true
            folderIcon.isHidden = false
        }

        nameLabel.text = folder.name

        // Строим бейджи по типам
        typeBadgesRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let types: [(CardType, String)] = [(.text, "text.alignleft"), (.image, "photo"), (.link, "link")]
        for (type, symbol) in types {
            let count = cards.filter { $0.type == type }.count
            guard count > 0 else { continue }
            typeBadgesRow.addArrangedSubview(makeTypeBadge(symbol: symbol, count: count, color: base))
        }
        // Если совсем нет заметок — показать «0 заметок»
        if cards.isEmpty {
            let empty = UILabel()
            empty.text      = L10n.noNotesLabel
            empty.font      = .inter(ofSize: 10, weight: .regular)
            empty.textColor = .tertiaryLabel
            typeBadgesRow.addArrangedSubview(empty)
        }
    }

    private func makeTypeBadge(symbol: String, count: Int, color: UIColor) -> UIView {
        let bg = UIView()
        bg.backgroundColor      = color.withAlphaComponent(0.15)
        bg.layer.cornerRadius   = 7
        bg.layer.masksToBounds  = true

        let cfg  = UIImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: cfg))
        icon.tintColor    = color
        icon.contentMode  = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text      = "\(count)"
        lbl.font      = .inter(ofSize: 10, weight: .semibold)
        lbl.textColor = color
        lbl.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [icon, lbl])
        row.axis      = .horizontal
        row.spacing   = 3
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        bg.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: bg.topAnchor, constant: 3),
            row.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 5),
            row.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -5),
            row.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -3),
            icon.widthAnchor.constraint(equalToConstant: 11),
            icon.heightAnchor.constraint(equalToConstant: 11)
        ])
        return bg
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

// MARK: - AddFolderCardCell

final class AddFolderCardCell: UICollectionViewCell {

    static let reuseID = "AddFolderCardCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear

        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? DayPinDesign.accent.withAlphaComponent(0.08)
                : DayPinDesign.accent.withAlphaComponent(0.05)
        }
        bg.layer.cornerRadius = 18
        bg.layer.borderWidth  = 1.5
        bg.layer.borderColor  = DayPinDesign.accent.withAlphaComponent(0.35).cgColor
        contentView.addSubview(bg)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let cfg  = UIImage.SymbolConfiguration(pointSize: 26, weight: .light)
        let icon = UIImageView(image: UIImage(systemName: "folder.badge.plus", withConfiguration: cfg))
        icon.tintColor   = DayPinDesign.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text      = L10n.newFolder
        label.font      = .inter(ofSize: 14, weight: .medium)
        label.textColor = DayPinDesign.accent
        label.translatesAutoresizingMaskIntoConstraints = false

        bg.addSubview(icon)
        bg.addSubview(label)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: bg.centerYAnchor, constant: -12),
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: bg.centerXAnchor)
        ])
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }
}
