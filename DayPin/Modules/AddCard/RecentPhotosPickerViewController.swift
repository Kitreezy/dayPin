import UIKit
import Photos
import PhotosUI

final class RecentPhotosPickerViewController: UIViewController {

    var onSelect:  ((Data) -> Void)?
    var onShowAll: (() -> Void)?

    private var assets: [PHAsset] = []
    private let imageManager = PHCachingImageManager()
    private var collectionView: UICollectionView!
    private let thumbSize = CGSize(width: 240, height: 240)
    private let headerLabel = UILabel()
    private weak var showAllButton: UIButton?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSheet()
        setupHeader()
        setupCollection()
        setupAllPhotosButton()
        loadAssets()
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
        headerLabel.text = L10n.recentPhotos
        showAllButton?.setTitle(L10n.showAllPhotos, for: .normal)
    }

    @objc private func onColorSchemeChanged() {
        showAllButton?.tintColor = DayPinDesign.accent
        showAllButton?.setTitleColor(DayPinDesign.accent, for: .normal)
    }

    private func setupSheet() {
        view.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#111111") ?? .black
                : UIColor(hex: "#F7F7F7") ?? .systemBackground
        }
        view.layer.cornerRadius = 24
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true

        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
    }

    private func setupHeader() {
        headerLabel.text = L10n.recentPhotos
        headerLabel.font = .inter(ofSize: 17, weight: .semibold)
        headerLabel.textColor = .label
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ])
    }

    private func setupCollection() {
        let spacing: CGFloat = 3
        let cols: CGFloat = 3
        let side = (UIScreen.main.bounds.width - spacing * (cols + 1)) / cols

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: side, height: side)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(RecentPhotoCell.self, forCellWithReuseIdentifier: RecentPhotoCell.reuseID)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 64),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)
        ])
    }

    private func setupAllPhotosButton() {
        let container = UIView()
        container.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#1C1C1E") ?? .secondarySystemBackground
                : .systemBackground
        }
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        btn.setImage(UIImage(systemName: "photo.stack", withConfiguration: cfg), for: .normal)
        btn.setTitle(L10n.showAllPhotos, for: .normal)
        btn.titleLabel?.font = .inter(ofSize: 16, weight: .semibold)
        btn.tintColor = DayPinDesign.accent
        btn.setTitleColor(DayPinDesign.accent, for: .normal)
        btn.addTarget(self, action: #selector(showAllTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(btn)
        showAllButton = btn

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 90),

            btn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            btn.topAnchor.constraint(equalTo: container.topAnchor, constant: 14)
        ])

        let sep = UIView()
        sep.backgroundColor = UIColor.separator.withAlphaComponent(0.4)
        sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: container.topAnchor),
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: - Photos

    private func loadAssets() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            fetchAssets()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted == .authorized || granted == .limited {
                        self?.fetchAssets()
                    }
                }
            }
        default:
            break
        }
    }

    private func fetchAssets() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            opts.fetchLimit = 30
            let result = PHAsset.fetchAssets(with: .image, options: opts)
            var list: [PHAsset] = []
            result.enumerateObjects { a, _, _ in list.append(a) }
            DispatchQueue.main.async {
                self.assets = list
                self.collectionView.reloadData()
            }
        }
    }

    // MARK: - Actions

    @objc private func showAllTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onShowAll?()
        }
    }

    private func pickAsset(_ asset: PHAsset) {
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.isSynchronous = false
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 1080, height: 1080),
            contentMode: .aspectFit,
            options: opts
        ) { [weak self] image, _ in
            guard let self, let image else { return }
            let data = image.jpegData(compressionQuality: 0.85) ?? Data()
            DispatchQueue.main.async {
                self.dismiss(animated: true) {
                    self.onSelect?(data)
                }
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension RecentPhotosPickerViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int { assets.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        guard let cell = cv.dequeueReusableCell(withReuseIdentifier: RecentPhotoCell.reuseID, for: ip) as? RecentPhotoCell else {
            return UICollectionViewCell()
        }
        let asset = assets[ip.item]
        cell.representedID = asset.localIdentifier
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = false
        imageManager.requestImage(for: asset, targetSize: thumbSize, contentMode: .aspectFill, options: opts) { img, _ in
            guard cell.representedID == asset.localIdentifier else { return }
            cell.imageView.image = img
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension RecentPhotosPickerViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pickAsset(assets[ip.item])
    }
}

// MARK: - RecentPhotoCell

private final class RecentPhotoCell: UICollectionViewCell {
    static let reuseID = "RecentPhotoCell"
    let imageView = UIImageView()
    var representedID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 0.18, alpha: 1)
                : UIColor(white: 0.88, alpha: 1)
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.65 : 1
            }
        }
    }
}
