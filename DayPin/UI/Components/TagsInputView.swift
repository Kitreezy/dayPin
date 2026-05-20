import UIKit

// MARK: - TagsInputView

/// A compact horizontal-scrollable row of tag chips with a "+ tag" button.
/// Height: ~36pt.  Embed in any form layout.
final class TagsInputView: UIView {

    // MARK: - Public API

    /// Currently selected tag IDs.
    var tagIDs: [UUID] = [] {
        didSet { rebuild() }
    }

    /// Called whenever the user adds or removes a tag.
    var onTagsChanged: (([UUID]) -> Void)?

    // Convenience accessor used by editors.
    var selectedTagIDs: [UUID] { tagIDs }

    // MARK: - Private UI

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let addButton = UIButton(type: .system)

    // We keep the popover VC reference so we can update it when tags change.
    private var pickerVC: TagPickerViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        NotificationCenter.default.addObserver(
            self, selector: #selector(onTagsStoreChanged),
            name: .dayPinTagsChanged, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        // "+" add button
        let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        addButton.setImage(UIImage(systemName: "plus", withConfiguration: cfg), for: .normal)
        addButton.setTitle(" \(L10n.addTag)", for: .normal)
        addButton.titleLabel?.font = .inter(ofSize: 13, weight: .regular)
        addButton.tintColor = DayPinDesign.accent
        addButton.setTitleColor(DayPinDesign.accent, for: .normal)
        addButton.layer.cornerRadius = 9
        addButton.layer.borderWidth = 1
        addButton.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.4).cgColor
        addButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        rebuild()
    }

    // MARK: - Rebuild chips

    private func rebuild() {
        // Remove existing chips (everything except the addButton)
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Add chips for each current tag ID
        for id in tagIDs {
            guard let tag = TagStore.shared.tag(for: id) else { continue }
            stack.addArrangedSubview(makeChip(for: tag))
        }

        // Always show the + button last
        stack.addArrangedSubview(addButton)

        // Refresh border color (accent may change with theme)
        addButton.layer.borderColor = DayPinDesign.accent.withAlphaComponent(0.4).cgColor
        addButton.tintColor = DayPinDesign.accent
        addButton.setTitleColor(DayPinDesign.accent, for: .normal)
    }

    private func makeChip(for tag: Tag) -> UIView {
        let chip = UIButton(type: .system)
        let color = tag.color

        // Pill background tinted with tag color
        chip.backgroundColor = color.withAlphaComponent(0.15)
        chip.layer.cornerRadius = 9
        chip.clipsToBounds = true
        chip.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 6)

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.inter(ofSize: 13, weight: .medium),
            .foregroundColor: color
        ]
        let xCfg = UIImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        let xImage = UIImage(systemName: "xmark", withConfiguration: xCfg)?.withTintColor(
            color.withAlphaComponent(0.7), renderingMode: .alwaysOriginal
        )

        let str = NSMutableAttributedString(string: tag.name + "  ", attributes: titleAttrs)
        chip.setAttributedTitle(str, for: .normal)
        chip.setImage(xImage, for: .normal)
        chip.semanticContentAttribute = .forceRightToLeft
        chip.imageEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)

        // Store tag ID in accessibility identifier for tap handling
        chip.accessibilityIdentifier = tag.id.uuidString
        chip.addTarget(self, action: #selector(chipRemoveTapped(_:)), for: .touchUpInside)

        return chip
    }

    // MARK: - Actions

    @objc private func chipRemoveTapped(_ sender: UIButton) {
        guard let idString = sender.accessibilityIdentifier,
              let id = UUID(uuidString: idString) else { return }
        tagIDs.removeAll { $0 == id }
        rebuild()
        onTagsChanged?(tagIDs)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func addTapped() {
        guard let vc = findViewController() else { return }
        let picker = TagPickerViewController(selectedIDs: tagIDs)
        picker.onSelectionChanged = { [weak self] ids in
            guard let self else { return }
            self.tagIDs = ids
            self.onTagsChanged?(ids)
        }
        pickerVC = picker

        if UIDevice.current.userInterfaceIdiom == .pad {
            picker.modalPresentationStyle = .popover
            picker.popoverPresentationController?.sourceView = addButton
            picker.popoverPresentationController?.sourceRect = addButton.bounds
        } else {
            picker.modalPresentationStyle = .pageSheet
            if let sheet = picker.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        }
        vc.present(picker, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func onTagsStoreChanged() {
        rebuild()
    }

    // MARK: - Helpers

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

// MARK: - TagPickerViewController

/// Modal sheet: search field + list of all tags + "create new" row.
final class TagPickerViewController: UIViewController {

    var onSelectionChanged: (([UUID]) -> Void)?

    private var selectedIDs: [UUID]
    private var allTags: [Tag] = []
    private var filteredTags: [Tag] = []

    private let searchField = UITextField()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var createRowVisible = false

    init(selectedIDs: [UUID]) {
        self.selectedIDs = selectedIDs
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tags
        view.backgroundColor = DayPinDesign.background

        setupNav()
        setupSearch()
        setupTable()
        reload()
    }

    private func setupNav() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.done, style: .done, target: self, action: #selector(doneTapped)
        )
    }

    private func setupSearch() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        searchField.placeholder = L10n.newTag
        searchField.font = .inter(ofSize: 15)
        searchField.borderStyle = .roundedRect
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .done
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        container.addSubview(searchField)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: 56),

            searchField.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            searchField.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: container.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "tag")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "create")
    }

    private func reload() {
        allTags = TagStore.shared.all()
        let query = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        filteredTags = query.isEmpty ? allTags : allTags.filter { $0.name.localizedCaseInsensitiveContains(query) }
        createRowVisible = !query.isEmpty && !allTags.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame })
        tableView.reloadData()
    }

    @objc private func searchChanged() { reload() }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    private func toggleTag(_ tag: Tag) {
        if let idx = selectedIDs.firstIndex(of: tag.id) {
            selectedIDs.remove(at: idx)
        } else {
            selectedIDs.append(tag.id)
        }
        onSelectionChanged?(selectedIDs)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        tableView.reloadData()
    }

    private func createAndSelectTag(name: String) {
        let color = TagStore.shared.nextPaletteColor()
        let tag = Tag(name: name, colorHex: color)
        TagStore.shared.save(tag)
        selectedIDs.append(tag.id)
        onSelectionChanged?(selectedIDs)
        searchField.text = nil
        reload()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension TagPickerViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { createRowVisible ? 2 : 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if createRowVisible && section == 0 { return 1 }
        return filteredTags.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if createRowVisible && indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "create", for: indexPath)
            let query = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var config = cell.defaultContentConfiguration()
            config.text = "\(L10n.newTag): \"\(query)\""
            config.image = UIImage(systemName: "plus.circle.fill")
            config.imageProperties.tintColor = DayPinDesign.accent
            cell.contentConfiguration = config
            cell.backgroundColor = .clear
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "tag", for: indexPath)
        let tag = filteredTags[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = tag.name
        config.image = UIImage(systemName: "circle.fill")
        config.imageProperties.tintColor = tag.color

        let isSelected = selectedIDs.contains(tag.id)
        cell.accessoryType = isSelected ? .checkmark : .none
        cell.tintColor = DayPinDesign.accent
        cell.backgroundColor = .clear
        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if createRowVisible && indexPath.section == 0 {
            let query = searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !query.isEmpty else { return }
            createAndSelectTag(name: query)
        } else {
            toggleTag(filteredTags[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if createRowVisible { return section == 0 ? nil : L10n.tags }
        return filteredTags.isEmpty ? nil : L10n.tags
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Only existing tags section is deletable
        if createRowVisible && indexPath.section == 0 { return false }
        return true
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        if createRowVisible && indexPath.section == 0 { return }
        let tag = filteredTags[indexPath.row]
        selectedIDs.removeAll { $0 == tag.id }
        TagStore.shared.delete(tag)
        onSelectionChanged?(selectedIDs)
        reload()
    }
}

// MARK: - UITextFieldDelegate

extension TagPickerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let query = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !query.isEmpty && createRowVisible {
            createAndSelectTag(name: query)
        }
        textField.resignFirstResponder()
        return false
    }
}
