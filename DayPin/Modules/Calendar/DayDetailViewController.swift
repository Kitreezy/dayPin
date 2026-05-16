import UIKit
import PhotosUI

final class DayDetailViewController: UIViewController {

    private let date: Date

    init(date: Date) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let df = DateFormatter()
        df.dateFormat = "d MMMM"
        df.locale = L10n.activeLocale
        title = df.string(from: date)
        view.backgroundColor = DayPinDesign.background

        let vc = DayCardsViewController(date: date)
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vc.view)
        vc.didMove(toParent: self)

        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: view.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - DayCardsViewController

final class DayCardsViewController: UIViewController {

    let date: Date

    // MARK: - Data

    private var allCards: [NoteCard] = []

    private struct TypeSection {
        let type: CardType
        var cards: [NoteCard]
        var header: String {
            switch type {
            case .text:  return L10n.sectionText
            case .image: return L10n.sectionImage
            case .link:  return L10n.sectionLink
            }
        }
        var accentColor: UIColor {
            switch type {
            case .text:  return DayPinDesign.accent
            case .image: return DayPinDesign.accentLight
            case .link:  return DayPinDesign.accentDeep
            }
        }
    }

    private var activeSections: [TypeSection] = []
    private var activeFilter: FilterChipsView.Filter = .all

    // MARK: - UI

    private let filterChips = FilterChipsView()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(TextCardCell.self,  forCellWithReuseIdentifier: TextCardCell.reuseID)
        cv.register(ImageCardCell.self, forCellWithReuseIdentifier: ImageCardCell.reuseID)
        cv.register(LinkCardCell.self,  forCellWithReuseIdentifier: LinkCardCell.reuseID)
        cv.register(EmptyCardCell.self, forCellWithReuseIdentifier: EmptyCardCell.reuseID)
        cv.register(CardTypeSectionHeader.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: CardTypeSectionHeader.reuseID)
        return cv
    }()

    private lazy var addButton: GradientButton = {
        let btn = GradientButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.tintColor = .white
        btn.layer.cornerRadius = 22
        btn.layer.shadowColor   = DayPinDesign.accent.cgColor
        btn.layer.shadowOpacity = 0.40
        btn.layer.shadowRadius  = 12
        btn.layer.shadowOffset  = CGSize(width: 0, height: 4)
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        btn.setImage(UIImage(systemName: "plus", withConfiguration: cfg), for: .normal)
        btn.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Init

    init(date: Date) {
        self.date = date
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background

        filterChips.translatesAutoresizingMaskIntoConstraints = false
        filterChips.onFilterChange = { [weak self] filter in
            self?.activeFilter = filter
            self?.applyFilter()
        }

        collectionView.keyboardDismissMode = .onDrag
        view.addSubview(filterChips)
        view.addSubview(collectionView)
        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            filterChips.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            filterChips.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterChips.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterChips.heightAnchor.constraint(equalToConstant: 38),

            collectionView.topAnchor.constraint(equalTo: filterChips.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 44),
            addButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        collectionView.dataSource = self
        collectionView.delegate   = self
        loadCards()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadCards()
    }

    // MARK: - Data

    func loadCards() {
        allCards = CardStore.shared.cards(for: date)
        applyFilter()
    }

    private func applyFilter() {
        var text  = allCards.filter { $0.type == .text }
        var image = allCards.filter { $0.type == .image }
        var link  = allCards.filter { $0.type == .link }

        switch activeFilter {
        case .text:  image = []; link  = []
        case .image: text  = []; link  = []
        case .link:  text  = []; image = []
        case .all:   break
        }

        activeSections = [
            TypeSection(type: .text,  cards: text),
            TypeSection(type: .image, cards: image),
            TypeSection(type: .link,  cards: link)
        ].filter { !$0.cards.isEmpty }

        collectionView.reloadData()
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, _ in
            guard let self else { return nil }

            if self.activeSections.isEmpty {
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
                let item  = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let sec   = NSCollectionLayoutSection(group: group)
                sec.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
                return sec
            }

            let itemSize  = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(160))
            let item      = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(160))
            let group     = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)

            let sec = NSCollectionLayoutSection(group: group)
            sec.contentInsets   = NSDirectionalEdgeInsets(top: 6, leading: 11, bottom: 16, trailing: 11)
            sec.interGroupSpacing = 10

            let hdrSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36))
            let hdr = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: hdrSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            sec.boundarySupplementaryItems = [hdr]
            return sec
        }
    }

    // MARK: - Add

    @objc private func addTapped() {
        let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)
        var actions: [GlassAction] = [
            GlassAction(L10n.cardText,  icon: "text.alignleft")       { [weak self] in self?.presentTextEditor() },
            GlassAction(L10n.cardPhoto, icon: "photo.on.rectangle")    { [weak self] in self?.presentImagePicker() }
        ]
        if hasCamera {
            actions.append(GlassAction(L10n.cardCamera, icon: "camera") { [weak self] in self?.presentCamera() })
        }
        actions.append(GlassAction(L10n.cardLink, icon: "link") { [weak self] in self?.presentLinkEditor() })
        actions.append(GlassAction(L10n.cancel, style: .cancel))
        GlassActionSheet.show(actions: actions, from: self, sourceView: addButton)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func presentTextEditor() {
        let vc = TextCardEditorViewController(card: nil, dayDate: date)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        presentEditorSheet(vc)
    }

    private func presentLinkEditor() {
        let vc = LinkCardEditorViewController(card: nil, dayDate: date)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        presentEditorSheet(vc)
    }

    private func presentImagePicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentImageCardEditor(imageData: Data?) {
        let vc = ImageCardEditorViewController(imageData: imageData, dayDate: date, existingCard: nil)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func presentImageEditor(card: ImageCard) {
        let vc = ImageCardEditorViewController(imageData: card.imageData, dayDate: date, existingCard: card)
        vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func deleteCard(_ card: NoteCard, at indexPath: IndexPath) {
        guard indexPath.section < activeSections.count,
              indexPath.item < activeSections[indexPath.section].cards.count else {
            CardStore.shared.delete(card: card); loadCards(); return
        }

        CardStore.shared.delete(card: card)
        allCards = CardStore.shared.cards(for: date)

        activeSections[indexPath.section].cards.remove(at: indexPath.item)
        let sectionEmpty = activeSections[indexPath.section].cards.isEmpty
        if sectionEmpty { activeSections.remove(at: indexPath.section) }
        let allEmpty = activeSections.isEmpty

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        collectionView.performBatchUpdates {
            self.collectionView.deleteItems(at: [indexPath])
            if sectionEmpty && !allEmpty {
                self.collectionView.deleteSections(IndexSet(integer: indexPath.section))
            }
        } completion: { _ in
            if allEmpty {
                UIView.transition(with: self.collectionView, duration: 0.2, options: .transitionCrossDissolve) {
                    self.collectionView.reloadData()
                }
            }
        }
    }
}

// MARK: - DataSource

extension DayCardsViewController: UICollectionViewDataSource {
    func numberOfSections(in cv: UICollectionView) -> Int {
        activeSections.isEmpty ? 1 : activeSections.count
    }
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        activeSections.isEmpty ? 1 : activeSections[section].cards.count
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if activeSections.isEmpty {
            return cv.dequeueReusableCell(withReuseIdentifier: EmptyCardCell.reuseID, for: indexPath) as! EmptyCardCell
        }
        let card = activeSections[indexPath.section].cards[indexPath.item]
        switch card.type {
        case .text:
            let cell = cv.dequeueReusableCell(withReuseIdentifier: TextCardCell.reuseID, for: indexPath) as! TextCardCell
            cell.configure(with: card as! TextCard); return cell
        case .image:
            let cell = cv.dequeueReusableCell(withReuseIdentifier: ImageCardCell.reuseID, for: indexPath) as! ImageCardCell
            cell.configure(with: card as! ImageCard); return cell
        case .link:
            let cell = cv.dequeueReusableCell(withReuseIdentifier: LinkCardCell.reuseID, for: indexPath) as! LinkCardCell
            cell.configure(with: card as! LinkCard); return cell
        }
    }
    func collectionView(_ cv: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = cv.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: CardTypeSectionHeader.reuseID, for: indexPath
        ) as! CardTypeSectionHeader
        if !activeSections.isEmpty {
            header.configure(title: activeSections[indexPath.section].header,
                             color: activeSections[indexPath.section].accentColor)
        }
        return header
    }
}

// MARK: - Delegate

extension DayCardsViewController: UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !activeSections.isEmpty else { return }
        let card = activeSections[indexPath.section].cards[indexPath.item]
        switch card.type {
        case .text:
            navigationController?.pushViewController(CardDetailViewController(card: card as! TextCard), animated: true)
        case .image:
            navigationController?.pushViewController(ImageCardDetailViewController(card: card as! ImageCard), animated: true)
        case .link:
            navigationController?.pushViewController(LinkCardDetailViewController(card: card as! LinkCard), animated: true)
        }
    }

    func collectionView(_ cv: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !activeSections.isEmpty else { return nil }
        let card = activeSections[indexPath.section].cards[indexPath.item]
        return UIContextMenuConfiguration(actionProvider: { _ in
            let share = UIAction(title: L10n.share, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                guard let self else { return }
                var items: [Any] = [card.title]
                if let img = card as? ImageCard, let data = img.imageData, let image = UIImage(data: data) { items.append(image) }
                if let link = card as? LinkCard { items.append(link.url) }
                self.present(UIActivityViewController(activityItems: items, applicationActivities: nil), animated: true)
            }
            let copyToDay = UIAction(title: "Скопировать в день", image: UIImage(systemName: "calendar.badge.plus")) { [weak self] _ in
                guard let self else { return }
                let vc = CopyToDayViewController()
                vc.onCopy = { date in
                    CardStore.shared.save(card: card.duplicated(to: date))
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                self.present(UINavigationController(rootViewController: vc), animated: true)
            }
            let edit = UIAction(title: L10n.edit, image: UIImage(systemName: "pencil")) { [weak self] _ in
                guard let self else { return }
                switch card.type {
                case .text:
                    let vc = TextCardEditorViewController(card: card as? TextCard, dayDate: date)
                    vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
                    presentEditorSheet(vc)
                case .image:
                    if let c = card as? ImageCard { presentImageEditor(card: c) }
                case .link:
                    let vc = LinkCardEditorViewController(card: card as? LinkCard, dayDate: date)
                    vc.onSave = { [weak self] saved in CardStore.shared.save(card: saved); self?.loadCards() }
                    presentEditorSheet(vc)
                }
            }
            let delete = UIAction(title: L10n.delete, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteCard(card, at: indexPath)
            }
            return UIMenu(children: [share, copyToDay, edit, delete])
        })
    }
}

// MARK: - PHPickerDelegate + UIImagePickerDelegate

extension DayCardsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let image = obj as? UIImage, let self else { return }
            DispatchQueue.main.async { self.presentImageCardEditor(imageData: image.jpegData(compressionQuality: 0.85)) }
        }
    }
}

extension DayCardsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        presentImageCardEditor(imageData: image?.jpegData(compressionQuality: 0.85))
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
}
