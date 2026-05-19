import UIKit
import PhotosUI

// MARK: - FolderEditorViewController

final class FolderEditorViewController: UIViewController {

    var onSave: ((Folder) -> Void)?

    private var folder: Folder
    private let isNew: Bool

    // State
    private var selectedHex: String
    private var selectedEmoji: String?
    private var selectedImageData: Data?

    // UI
    private let previewContainer = UIView()
    private let previewGradient  = GradientPreviewView()
    private let previewPhoto     = UIImageView()
    private let previewEmoji     = UILabel()
    private let previewFolderIcon = UIImageView()

    private let nameField = UITextField()
    private var colorDots: [UIButton] = []

    // MARK: - Palette
    private static var palette: [(name: String, hex: String)] {[
        (L10n.colorBlue,   "#007AFF"),
        (L10n.colorRed,    "#FF3B30"),
        (L10n.colorGreen,  "#34C759"),
        (L10n.colorOrange, "#FF9500"),
        (L10n.colorPurple, "#AF52DE"),
        (L10n.colorYellow, "#FFCC00"),
        (L10n.colorTeal,   "#32ADE6"),
        (L10n.colorPink,   "#FF2D55")
    ]}

    // MARK: - Init

    init(folder: Folder?) {
        if let f = folder {
            self.folder            = f
            self.isNew             = false
            self.selectedHex       = f.colorHex
            self.selectedEmoji     = f.emojiIcon
            self.selectedImageData = f.iconImageData
        } else {
            self.folder            = Folder(name: "")
            self.isNew             = true
            self.selectedHex       = Self.palette[0].hex
            self.selectedEmoji     = nil
            self.selectedImageData = nil
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isNew ? L10n.newFolder : L10n.editFolder
        view.backgroundColor = DayPinDesign.background
        setupNav()
        buildUI()
        updatePreview()
        updateColorDots()
        observeNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameField.becomeFirstResponder()
    }

    // MARK: - Notifications

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(onLanguageChanged),
            name: .dayPinLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onColorSchemeChanged),
            name: .dayPinColorSchemeChanged, object: nil)
    }

    @objc private func onLanguageChanged() {
        title = isNew ? L10n.newFolder : L10n.editFolder
        navigationItem.leftBarButtonItem?.title  = L10n.cancel
        navigationItem.rightBarButtonItem?.title = L10n.save
        nameField.placeholder = L10n.folderNamePlaceholder
    }

    @objc private func onColorSchemeChanged() {
        view.backgroundColor = DayPinDesign.background
        navigationItem.rightBarButtonItem?.tintColor = DayPinDesign.accent
    }

    // MARK: - Nav

    private func setupNav() {
        navigationItem.leftBarButtonItem  = UIBarButtonItem(title: L10n.cancel, style: .plain,
                                                            target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.save, style: .done,
                                                            target: self, action: #selector(save))
        navigationItem.rightBarButtonItem?.tintColor = DayPinDesign.accent
    }

    // MARK: - Build UI

    private func buildUI() {

        // ── Превью иконки ──────────────────────────────────────────────────
        previewGradient.translatesAutoresizingMaskIntoConstraints = false
        previewGradient.layer.cornerRadius  = 24
        previewGradient.layer.masksToBounds = true

        // Фото поверх градиента
        previewPhoto.contentMode   = .scaleAspectFill
        previewPhoto.clipsToBounds = true
        previewPhoto.translatesAutoresizingMaskIntoConstraints = false
        previewGradient.addSubview(previewPhoto)
        NSLayoutConstraint.activate([
            previewPhoto.topAnchor.constraint(equalTo: previewGradient.topAnchor),
            previewPhoto.leadingAnchor.constraint(equalTo: previewGradient.leadingAnchor),
            previewPhoto.trailingAnchor.constraint(equalTo: previewGradient.trailingAnchor),
            previewPhoto.bottomAnchor.constraint(equalTo: previewGradient.bottomAnchor)
        ])

        // Эмодзи
        previewEmoji.font          = .inter(ofSize: 52)
        previewEmoji.textAlignment = .center
        previewEmoji.translatesAutoresizingMaskIntoConstraints = false
        previewGradient.addSubview(previewEmoji)
        NSLayoutConstraint.activate([
            previewEmoji.centerXAnchor.constraint(equalTo: previewGradient.centerXAnchor),
            previewEmoji.centerYAnchor.constraint(equalTo: previewGradient.centerYAnchor)
        ])

        // Дефолтная иконка папки
        let cfg = UIImage.SymbolConfiguration(pointSize: 38, weight: .medium)
        previewFolderIcon.image        = UIImage(systemName: "folder.fill", withConfiguration: cfg)
        previewFolderIcon.tintColor    = UIColor { trait in trait.userInterfaceStyle == .dark ? .white : .white }
        previewFolderIcon.contentMode  = .scaleAspectFit
        previewFolderIcon.translatesAutoresizingMaskIntoConstraints = false
        previewGradient.addSubview(previewFolderIcon)
        NSLayoutConstraint.activate([
            previewFolderIcon.centerXAnchor.constraint(equalTo: previewGradient.centerXAnchor),
            previewFolderIcon.centerYAnchor.constraint(equalTo: previewGradient.centerYAnchor),
            previewFolderIcon.widthAnchor.constraint(equalToConstant: 48),
            previewFolderIcon.heightAnchor.constraint(equalToConstant: 48)
        ])

        view.addSubview(previewGradient)
        NSLayoutConstraint.activate([
            previewGradient.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            previewGradient.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewGradient.widthAnchor.constraint(equalToConstant: 110),
            previewGradient.heightAnchor.constraint(equalToConstant: 110)
        ])

        // ── Кнопки выбора иконки ───────────────────────────────────────────
        let iconButtonsRow = UIStackView(arrangedSubviews: [
            makeIconButton(title: L10n.emoji,       icon: "face.smiling",           action: #selector(pickEmoji)),
            makeIconButton(title: L10n.filterImage, icon: "photo.on.rectangle",     action: #selector(pickPhoto)),
            makeIconButton(title: L10n.defaultIcon, icon: "arrow.counterclockwise", action: #selector(resetIcon))
        ])
        iconButtonsRow.axis         = .horizontal
        iconButtonsRow.spacing      = 10
        iconButtonsRow.distribution = .fillEqually
        iconButtonsRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconButtonsRow)

        NSLayoutConstraint.activate([
            iconButtonsRow.topAnchor.constraint(equalTo: previewGradient.bottomAnchor, constant: 14),
            iconButtonsRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            iconButtonsRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            iconButtonsRow.heightAnchor.constraint(equalToConstant: 36)
        ])

        // ── Поле имени ─────────────────────────────────────────────────────
        let formCard = GlassCardView(style: .card)
        formCard.translatesAutoresizingMaskIntoConstraints = false

        nameField.placeholder   = L10n.folderNamePlaceholder
        nameField.font          = .inter(ofSize: 16, weight: .semibold)
        nameField.borderStyle   = .none
        nameField.returnKeyType = .done
        nameField.delegate      = self
        nameField.text          = isNew ? "" : folder.name
        nameField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        formCard.stackView.addArrangedSubview(nameField)

        view.addSubview(formCard)
        NSLayoutConstraint.activate([
            formCard.topAnchor.constraint(equalTo: iconButtonsRow.bottomAnchor, constant: 20),
            formCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        // ── Цвет папки ─────────────────────────────────────────────────────
        let colorLabel = UILabel()
        colorLabel.text      = L10n.folderColorLabel
        colorLabel.font      = .inter(ofSize: 11, weight: .semibold)
        colorLabel.textColor = .secondaryLabel
        colorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(colorLabel)

        let colorStack = UIStackView()
        colorStack.axis         = .horizontal
        colorStack.spacing      = 12
        colorStack.alignment    = .center
        colorStack.translatesAutoresizingMaskIntoConstraints = false

        for (_, hex) in Self.palette {
            let btn = UIButton(type: .custom)
            btn.backgroundColor   = UIColor(hex: hex) ?? .systemBlue
            btn.layer.cornerRadius = 12
            btn.widthAnchor.constraint(equalToConstant: 24).isActive  = true
            btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
            let h = hex
            btn.addAction(UIAction { [weak self] _ in
                self?.selectedHex = h
                self?.updateColorDots()
                self?.updatePreview()
            }, for: .touchUpInside)
            colorStack.addArrangedSubview(btn)
            colorDots.append(btn)
        }

        view.addSubview(colorStack)
        NSLayoutConstraint.activate([
            colorLabel.topAnchor.constraint(equalTo: formCard.bottomAnchor, constant: 22),
            colorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            colorStack.topAnchor.constraint(equalTo: colorLabel.bottomAnchor, constant: 10),
            colorStack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func makeIconButton(title: String, icon: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle("  \(title)", for: .normal)
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        btn.titleLabel?.font    = .inter(ofSize: 13, weight: .medium)
        btn.tintColor           = DayPinDesign.accent
        btn.backgroundColor     = UIColor { t in
            t.userInterfaceStyle == .dark
                ? DayPinDesign.accent.withAlphaComponent(0.12)
                : DayPinDesign.accent.withAlphaComponent(0.08)
        }
        btn.layer.cornerRadius  = 10
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Preview Update

    private func updatePreview() {
        let base = UIColor(hex: selectedHex) ?? DayPinDesign.accent
        previewGradient.setColors(base: base)
        DayPinDesign.applyCardShadow(to: previewGradient.layer)
        previewGradient.layer.shadowColor   = base.cgColor
        previewGradient.layer.shadowOpacity = 0.35

        if let data = selectedImageData, let img = UIImage(data: data) {
            previewPhoto.image        = img
            previewPhoto.isHidden     = false
            previewEmoji.isHidden     = true
            previewFolderIcon.isHidden = true
        } else if let emoji = selectedEmoji, !emoji.isEmpty {
            previewEmoji.text          = emoji
            previewPhoto.isHidden      = true
            previewEmoji.isHidden      = false
            previewFolderIcon.isHidden = true
        } else {
            previewPhoto.isHidden      = true
            previewEmoji.isHidden      = true
            previewFolderIcon.isHidden = false
        }
    }

    private func updateColorDots() {
        for (i, (_, hex)) in Self.palette.enumerated() {
            guard i < colorDots.count else { break }
            let selected = hex.uppercased() == selectedHex.uppercased()
            colorDots[i].layer.borderColor = selected
                ? UIColor.white.cgColor
                : UIColor.clear.cgColor
            colorDots[i].layer.borderWidth = selected ? 2.5 : 0
            // Маленькое кольцо-обёртка вместо transform
            colorDots[i].layer.shadowColor   = selected
                ? (UIColor(hex: hex) ?? .clear).cgColor : UIColor.clear.cgColor
            colorDots[i].layer.shadowOpacity = selected ? 0.5 : 0
            colorDots[i].layer.shadowRadius  = selected ? 4 : 0
            colorDots[i].layer.shadowOffset  = .zero
        }
    }

    // MARK: - Icon Actions

    @objc private func pickEmoji() {
        let alert = UIAlertController(title: L10n.chooseEmoji, message: L10n.emojiHint, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder  = "😊"
            tf.font         = .inter(ofSize: 30)
            tf.textAlignment = .center
            if #available(iOS 16.0, *) {
                tf.keyboardType = .default
            }
        }
        alert.addAction(UIAlertAction(title: L10n.selectNote, style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text,
                  let first = text.unicodeScalars.first,
                  first.properties.isEmoji else { return }
            // Берём первый «полный» эмодзи (может быть многобайтным: 👨‍💻)
            let emoji = String(text.prefix(2)).trimmingCharacters(in: .whitespaces)
            self?.selectedEmoji     = String(text.unicodeScalars.prefix(2))
            self?.selectedImageData = nil
            self?.updatePreview()
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    @objc private func pickPhoto() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func resetIcon() {
        selectedEmoji     = nil
        selectedImageData = nil
        updatePreview()
    }

    // MARK: - Save / Cancel

    @objc private func cancel() { dismiss(animated: true) }

    @objc private func save() {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { nameField.shake(); return }
        folder.name          = name
        folder.colorHex      = selectedHex
        folder.emojiIcon     = selectedEmoji
        folder.iconImageData = selectedImageData
        onSave?(folder)
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension FolderEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { save(); return false }
}

// MARK: - PHPickerViewControllerDelegate

extension FolderEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let image = obj as? UIImage else { return }
            let data = image.jpegData(compressionQuality: 0.7)
            DispatchQueue.main.async {
                self?.selectedImageData = data
                self?.selectedEmoji     = nil
                self?.updatePreview()
            }
        }
    }
}

// MARK: - GradientPreviewView (self-managed gradient layer)

private final class GradientPreviewView: UIView {

    private let gradLayer = CAGradientLayer()

    init() {
        super.init(frame: .zero)
        gradLayer.startPoint = CGPoint(x: 0, y: 0)
        gradLayer.endPoint   = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradLayer.frame = bounds
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
