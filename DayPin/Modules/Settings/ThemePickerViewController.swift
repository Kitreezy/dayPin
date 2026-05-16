import UIKit

// MARK: - ThemePickerViewController
// Bottom-sheet screen for picking brightness mode + color scheme.
// 2-column grid — each cell shows 3 vertical color swatches + scheme name.

final class ThemePickerViewController: UIViewController {

    // MARK: - UI

    private let titleLabel = UILabel()
    private let brightnessSegment = UISegmentedControl(items: AppTheme.allCases.map(\.displayName))
    private let schemeLabel = UILabel()
    private lazy var collectionView: UICollectionView = makeCollectionView()

    private var selectedSchemeID: ColorSchemeID = ThemeManager.shared.colorScheme.id

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.cardSurface
        title = "Оформление"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        titleLabel.text = "Яркость"
        titleLabel.font = .inter(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        brightnessSegment.selectedSegmentIndex = ThemeManager.shared.current.rawValue
        brightnessSegment.addTarget(self, action: #selector(brightnessChanged), for: .valueChanged)
        brightnessSegment.translatesAutoresizingMaskIntoConstraints = false

        schemeLabel.text = "Цветовая схема"
        schemeLabel.font = .inter(ofSize: 13, weight: .medium)
        schemeLabel.textColor = .secondaryLabel
        schemeLabel.translatesAutoresizingMaskIntoConstraints = false

        collectionView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(brightnessSegment)
        view.addSubview(schemeLabel)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            brightnessSegment.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            brightnessSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            brightnessSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            schemeLabel.topAnchor.constraint(equalTo: brightnessSegment.bottomAnchor, constant: 24),
            schemeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            collectionView.topAnchor.constraint(equalTo: schemeLabel.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        collectionView.dataSource = self
        collectionView.delegate   = self
    }

    private func makeCollectionView() -> UICollectionView {
        let spacing: CGFloat = 12
        let columns: CGFloat = 2
        let totalPadding = spacing * (columns + 1)
        let itemWidth = (UIScreen.main.bounds.width - totalPadding) / columns
        let itemHeight = itemWidth * 0.72

        let item  = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(itemWidth),
                                               heightDimension: .absolute(itemHeight))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .absolute(itemHeight)),
            subitem: item,
            count: 2
        )
        group.interItemSpacing = .fixed(spacing)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: spacing, bottom: spacing, trailing: spacing
        )

        let cv = UICollectionView(frame: .zero,
                                  collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.register(SchemeCell.self, forCellWithReuseIdentifier: SchemeCell.reuseID)
        return cv
    }

    // MARK: - Actions

    @objc private func brightnessChanged() {
        let theme = AppTheme(rawValue: brightnessSegment.selectedSegmentIndex) ?? .system
        ThemeManager.shared.current = theme
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension ThemePickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        AppColorScheme.all.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SchemeCell.reuseID, for: indexPath) as! SchemeCell
        let scheme = AppColorScheme.all[indexPath.item]
        cell.configure(scheme: scheme, isSelected: scheme.id == selectedSchemeID)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let scheme = AppColorScheme.all[indexPath.item]
        guard scheme.id != selectedSchemeID else { return }
        selectedSchemeID = scheme.id
        ThemeManager.shared.colorScheme = scheme
        collectionView.reloadData()
    }
}

// MARK: - SchemeCell

private final class SchemeCell: UICollectionViewCell {

    static let reuseID = "SchemeCell"

    private let swatchStack  = UIStackView()
    private let nameLabel    = UILabel()
    private let emojiLabel   = UILabel()
    private let checkmark    = UIImageView()
    private let borderLayer  = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = false
        contentView.backgroundColor = DayPinDesign.cardSurface

        // Subtle border
        borderLayer.cornerRadius  = 16
        borderLayer.borderWidth   = 2
        borderLayer.borderColor   = UIColor.clear.cgColor
        contentView.layer.addSublayer(borderLayer)

        // Shadow
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowRadius  = 8
        layer.shadowOffset  = CGSize(width: 0, height: 2)

        // Swatches: 3 vertical color bars
        swatchStack.axis         = .horizontal
        swatchStack.distribution = .fillEqually
        swatchStack.spacing      = 0
        swatchStack.layer.cornerRadius  = 10
        swatchStack.layer.masksToBounds = true
        swatchStack.translatesAutoresizingMaskIntoConstraints = false

        for _ in 0..<3 {
            let bar = UIView()
            bar.heightAnchor.constraint(equalToConstant: 56).isActive = true
            swatchStack.addArrangedSubview(bar)
        }

        // Emoji + name row
        emojiLabel.font = .inter(ofSize: 18)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .inter(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        checkmark.image = UIImage(systemName: "checkmark.circle.fill")
        checkmark.tintColor = .white
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = true

        let nameRow = UIStackView(arrangedSubviews: [emojiLabel, nameLabel, UIView(), checkmark])
        nameRow.axis      = .horizontal
        nameRow.spacing   = 6
        nameRow.alignment = .center
        nameRow.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(swatchStack)
        contentView.addSubview(nameRow)

        NSLayoutConstraint.activate([
            swatchStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            swatchStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            swatchStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            swatchStack.heightAnchor.constraint(equalToConstant: 56),

            nameRow.topAnchor.constraint(equalTo: swatchStack.bottomAnchor, constant: 10),
            nameRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            nameRow.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),

            checkmark.widthAnchor.constraint(equalToConstant: 18),
            checkmark.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        borderLayer.frame = contentView.bounds
        layer.shadowPath  = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
    }

    func configure(scheme: AppColorScheme, isSelected: Bool) {
        let swatchColors: [UIColor] = [scheme.textTint, scheme.imageTint, scheme.linkTint]
        for (i, bar) in swatchStack.arrangedSubviews.enumerated() {
            bar.backgroundColor = swatchColors[i]
        }

        emojiLabel.text = scheme.id.emoji
        nameLabel.text  = scheme.name

        checkmark.tintColor = scheme.accent
        checkmark.isHidden  = !isSelected

        borderLayer.borderColor = isSelected
            ? scheme.accent.withAlphaComponent(0.7).cgColor
            : UIColor.clear.cgColor

        contentView.layer.shadowColor   = isSelected ? scheme.accent.cgColor : UIColor.black.cgColor
        contentView.layer.shadowOpacity = isSelected ? 0.20 : 0.06
    }
}
