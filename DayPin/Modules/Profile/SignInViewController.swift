import UIKit

// MARK: - Mode

private enum Mode { case signIn, register }

// MARK: - SignInViewController

final class SignInViewController: UIViewController {

    // MARK: - State

    private var mode: Mode = .signIn
    var canSkip = false

    // MARK: - Views

    private let scrollView = UIScrollView()
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))

    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    private let segmentControl = UISegmentedControl(items: ["", ""])

    private let emailField = PaddedTextField()
    private let passwordField = PaddedTextField()
    private let confirmField = PaddedTextField()
    private let confirmFieldWrapper = UIView()  // hidden in sign-in mode

    private let primaryBtn = UIButton(type: .system)
    private let errorLabel = UILabel()

    private let dividerLabel = UILabel()
    private let appleBtn = UIButton(type: .system)

    private let serverField = PaddedTextField()
    private let serverLabel = UILabel()

    private var isLoading = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DayPinDesign.background
        addStandardBackground()
        if canSkip { setupSkipButton() }
        setupUI()
        observeKeyboard()
        setupTapToDismissKeyboard()
        NotificationCenter.default.addObserver(
            self, selector: #selector(onAuthChanged),
            name: .dayPinAuthStateChanged, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func onAuthChanged() {
        if AuthService.shared.isLoggedIn { dismiss(animated: true) }
    }

    private func setupSkipButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: L10n.isRussian ? "Позже" : "Later",
            style: .plain,
            target: self,
            action: #selector(skipTapped)
        )
    }

    @objc private func skipTapped() {
        dismiss(animated: true)
    }

    // MARK: - Setup

    private func setupUI() {
        // Scroll container so form works on small screens
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Glass card
        let shadow = UIView()
        shadow.layer.cornerRadius = 24
        shadow.layer.shadowColor = UIColor.black.cgColor
        shadow.layer.shadowOpacity = 0.14
        shadow.layer.shadowRadius = 24
        shadow.layer.shadowOffset = CGSize(width: 0, height: 6)
        shadow.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(shadow)

        blur.layer.cornerRadius = 24
        blur.clipsToBounds = true
        blur.layer.borderWidth = 0.5
        blur.translatesAutoresizingMaskIntoConstraints = false
        shadow.addSubview(blur)

        let tint = UIView()
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 1, alpha: 0.60)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)

        // Icon
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        iconView.image = UIImage(systemName: "cloud.fill", withConfiguration: cfg)
        iconView.tintColor = DayPinDesign.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(iconView)

        // Title
        titleLabel.text = "DayPin Cloud"
        titleLabel.font = .inter(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(titleLabel)

        // Segment: Sign In / Register
        segmentControl.setTitle(L10n.isRussian ? "Войти" : "Sign In", forSegmentAt: 0)
        segmentControl.setTitle(L10n.isRussian ? "Регистрация" : "Register", forSegmentAt: 1)
        segmentControl.selectedSegmentIndex = 0
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        segmentControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        blur.contentView.addSubview(segmentControl)

        // Email
        emailField.configure(
            placeholder: "Email",
            keyboard: .emailAddress,
            content: .emailAddress
        )
        emailField.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(emailField)

        // Password
        passwordField.configure(
            placeholder: L10n.isRussian ? "Пароль" : "Password",
            keyboard: .default,
            content: .password,
            secure: true
        )
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(passwordField)

        // Confirm password (register only)
        confirmField.configure(
            placeholder: L10n.isRussian ? "Повторите пароль" : "Confirm Password",
            keyboard: .default,
            content: .newPassword,
            secure: true
        )
        confirmFieldWrapper.translatesAutoresizingMaskIntoConstraints = false
        confirmFieldWrapper.isHidden = true
        confirmField.translatesAutoresizingMaskIntoConstraints = false
        confirmFieldWrapper.addSubview(confirmField)
        NSLayoutConstraint.activate([
            confirmField.topAnchor.constraint(equalTo: confirmFieldWrapper.topAnchor),
            confirmField.leadingAnchor.constraint(equalTo: confirmFieldWrapper.leadingAnchor),
            confirmField.trailingAnchor.constraint(equalTo: confirmFieldWrapper.trailingAnchor),
            confirmField.bottomAnchor.constraint(equalTo: confirmFieldWrapper.bottomAnchor)
        ])
        blur.contentView.addSubview(confirmFieldWrapper)

        // Error label
        errorLabel.font = .inter(ofSize: 12, weight: .regular)
        errorLabel.textColor = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 2
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(errorLabel)

        // Primary action button
        primaryBtn.titleLabel?.font = .inter(ofSize: 15, weight: .semibold)
        primaryBtn.tintColor = .white
        primaryBtn.backgroundColor = DayPinDesign.accent
        primaryBtn.layer.cornerRadius = 14
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        primaryBtn.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        blur.contentView.addSubview(primaryBtn)

        // Divider
        dividerLabel.text = L10n.isRussian ? "- или -" : "- or -"
        dividerLabel.font = .inter(ofSize: 12, weight: .regular)
        dividerLabel.textColor = .tertiaryLabel
        dividerLabel.textAlignment = .center
        dividerLabel.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(dividerLabel)

        // Apple button - disabled, grayed out (paid account required)
        let appleCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        appleBtn.setImage(UIImage(systemName: "apple.logo", withConfiguration: appleCfg), for: .normal)
        appleBtn.setTitle(
            "  " + (L10n.isRussian ? "Войти через Apple (скоро)" : "Sign in with Apple (coming soon)"),
            for: .normal
        )
        appleBtn.titleLabel?.font = .inter(ofSize: 14, weight: .medium)
        appleBtn.tintColor = UIColor.tertiaryLabel
        appleBtn.backgroundColor = UIColor.tertiarySystemFill
        appleBtn.layer.cornerRadius = 14
        appleBtn.isEnabled = false
        appleBtn.alpha = 0.5
        appleBtn.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(appleBtn)

        // Server URL
        serverLabel.text = L10n.isRussian ? "Адрес сервера" : "Server URL"
        serverLabel.font = .inter(ofSize: 11, weight: .regular)
        serverLabel.textColor = .tertiaryLabel
        serverLabel.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(serverLabel)

        serverField.configure(
            placeholder: "http://localhost:8082",
            keyboard: .URL
        )
        serverField.text = APIClient.baseURL
        serverField.font = .inter(ofSize: 12, weight: .regular)
        serverField.translatesAutoresizingMaskIntoConstraints = false
        serverField.addTarget(self, action: #selector(serverURLChanged), for: .editingChanged)
        blur.contentView.addSubview(serverField)

        // Layout
        NSLayoutConstraint.activate([
            shadow.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 40),
            shadow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shadow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            shadow.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),

            blur.topAnchor.constraint(equalTo: shadow.topAnchor),
            blur.leadingAnchor.constraint(equalTo: shadow.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: shadow.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: shadow.bottomAnchor),

            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),

            iconView.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 28),
            iconView.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 52),
            iconView.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -20),

            segmentControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            segmentControl.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 20),
            segmentControl.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -20),

            emailField.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 16),
            emailField.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 20),
            emailField.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -20),
            emailField.heightAnchor.constraint(equalToConstant: 46),

            passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 10),
            passwordField.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: 46),

            confirmFieldWrapper.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 10),
            confirmFieldWrapper.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            confirmFieldWrapper.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            confirmFieldWrapper.heightAnchor.constraint(equalToConstant: 46),

            errorLabel.topAnchor.constraint(equalTo: confirmFieldWrapper.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),

            primaryBtn.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 14),
            primaryBtn.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            primaryBtn.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            primaryBtn.heightAnchor.constraint(equalToConstant: 50),

            dividerLabel.topAnchor.constraint(equalTo: primaryBtn.bottomAnchor, constant: 16),
            dividerLabel.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),

            appleBtn.topAnchor.constraint(equalTo: dividerLabel.bottomAnchor, constant: 12),
            appleBtn.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            appleBtn.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            appleBtn.heightAnchor.constraint(equalToConstant: 50),

            serverLabel.topAnchor.constraint(equalTo: appleBtn.bottomAnchor, constant: 20),
            serverLabel.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),

            serverField.topAnchor.constraint(equalTo: serverLabel.bottomAnchor, constant: 4),
            serverField.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            serverField.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            serverField.heightAnchor.constraint(equalToConstant: 38),
            serverField.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -24)
        ])

        updateModeUI(animated: false)
        refreshBorderColor()
    }

    // MARK: - Mode switch

    @objc private func segmentChanged() {
        mode = segmentControl.selectedSegmentIndex == 0 ? .signIn : .register
        hideError()
        updateModeUI(animated: true)
    }

    private func updateModeUI(animated: Bool) {
        let isRegister = mode == .register
        let btnTitle = isRegister
            ? (L10n.isRussian ? "Создать аккаунт" : "Create Account")
            : (L10n.isRussian ? "Войти" : "Sign In")
        primaryBtn.setTitle(btnTitle, for: .normal)

        // .newPassword triggers iOS's "suggest strong password" + iCloud Keychain save prompt;
        // .password is for autofilling an already-saved credential on sign in.
        passwordField.textContentType = isRegister ? .newPassword : .password
        confirmField.textContentType = .newPassword

        let change = {
            self.confirmFieldWrapper.isHidden = !isRegister
            self.confirmFieldWrapper.alpha = isRegister ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: change)
        } else {
            change()
        }
    }

    // MARK: - Primary action

    @objc private func primaryTapped() {
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            showError(L10n.isRussian ? "Заполните все поля" : "Fill in all fields")
            return
        }
        guard email.contains("@") else {
            showError(L10n.isRussian ? "Некорректный email" : "Invalid email")
            return
        }
        if mode == .register {
            let confirm = confirmField.text ?? ""
            guard password == confirm else {
                showError(L10n.isRussian ? "Пароли не совпадают" : "Passwords don't match")
                return
            }
            guard password.count >= 8 else {
                showError(L10n.isRussian ? "Пароль не менее 8 символов" : "Password must be 8+ characters")
                return
            }
        }

        setLoading(true)
        Task {
            do {
                if mode == .register {
                    try await AuthService.shared.register(email: email, password: password)
                } else {
                    try await AuthService.shared.signIn(email: email, password: password)
                }
                // ProfileViewController observes .dayPinAuthStateChanged — nothing more needed.
            } catch {
                showError(error.localizedDescription)
            }
            setLoading(false)
        }
    }

    @objc private func serverURLChanged() {
        let text = (serverField.text ?? "").trimmingCharacters(in: .whitespaces)
        if !text.isEmpty { APIClient.baseURL = text }
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        isLoading = loading
        primaryBtn.isEnabled = !loading
        primaryBtn.alpha = loading ? 0.6 : 1
        emailField.isEnabled = !loading
        passwordField.isEnabled = !loading
        confirmField.isEnabled = !loading
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func hideError() {
        errorLabel.isHidden = true
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        scrollView.contentInset.bottom = frame.height + 20
    }

    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = 0
    }

    private func setupTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Theming

    private func refreshBorderColor() {
        let dark = traitCollection.userInterfaceStyle == .dark
        blur.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.18).cgColor
            : UIColor.black.withAlphaComponent(0.12).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshBorderColor()
        }
    }
}

// MARK: - PaddedTextField

private final class PaddedTextField: UITextField {

    private let padding = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    private var isPasswordField = false

    func configure(
        placeholder: String,
        keyboard: UIKeyboardType = .default,
        content: UITextContentType? = nil,
        secure: Bool = false
    ) {
        self.placeholder = placeholder
        keyboardType = keyboard
        if let c = content { textContentType = c }
        isSecureTextEntry = secure
        isPasswordField = secure
        autocapitalizationType = .none
        autocorrectionType = .no
        spellCheckingType = .no
        backgroundColor = UIColor.secondarySystemFill
        layer.cornerRadius = 12
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.withAlphaComponent(0.5).cgColor
        font = .inter(ofSize: 15, weight: .regular)

        if secure {
            setupVisibilityToggle()
        }
    }

    private func setupVisibilityToggle() {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        btn.setImage(UIImage(systemName: "eye", withConfiguration: cfg), for: .normal)
        btn.tintColor = .tertiaryLabel
        btn.frame = CGRect(x: 0, y: 0, width: 36, height: 30)
        btn.addTarget(self, action: #selector(toggleVisibility), for: .touchUpInside)
        rightView = btn
        rightViewMode = .always
    }

    @objc private func toggleVisibility() {
        isSecureTextEntry.toggle()
        // Re-set text to work around a UITextField caret bug when toggling secure entry.
        if let existing = text {
            text = nil
            text = existing
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let name = isSecureTextEntry ? "eye" : "eye.slash"
        (rightView as? UIButton)?.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        isPasswordField ? bounds.inset(by: UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 40)) : bounds.inset(by: padding)
    }
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        isPasswordField ? bounds.inset(by: UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 40)) : bounds.inset(by: padding)
    }
    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: bounds.width - 40, y: (bounds.height - 30) / 2, width: 36, height: 30)
    }
}
