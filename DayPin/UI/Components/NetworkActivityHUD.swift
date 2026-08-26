import UIKit

// MARK: - NetworkActivityHUD
// Small glass pill at the top of the screen shown whenever at least one API
// request is in flight, so the app never looks frozen during a network call.

@MainActor
final class NetworkActivityHUD {

    static let shared = NetworkActivityHUD()

    private init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(onActivityChanged),
            name: .dayPinNetworkActivityChanged, object: nil
        )
    }

    private weak var hudView: UIView?
    private var showWorkItem: DispatchWorkItem?
    private var hideWorkItem: DispatchWorkItem?

    // MARK: - Activity

    @objc private func onActivityChanged() {
        showWorkItem?.cancel()
        hideWorkItem?.cancel()

        if NetworkActivityTracker.shared.isActive {
            // Small delay before showing - avoids a flicker for near-instant calls.
            let work = DispatchWorkItem { [weak self] in self?.show() }
            showWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        } else {
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            hideWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }

    // MARK: - Show / Hide

    private func show() {
        guard hudView == nil,
              let window = UIApplication.shared.connectedScenes
                  .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                  .first
        else { return }

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.layer.cornerRadius = 16
        blur.layer.borderWidth = 0.5
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false

        let dark = window.traitCollection.userInterfaceStyle == .dark
        blur.layer.borderColor = dark
            ? UIColor.white.withAlphaComponent(0.18).cgColor
            : UIColor.black.withAlphaComponent(0.12).cgColor

        let tint = UIView()
        tint.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 1, alpha: 0.55)
        }
        tint.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(tint)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = DayPinDesign.accent
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(spinner)

        let label = UILabel()
        label.text = L10n.isRussian ? "Синхронизация..." : "Syncing..."
        label.font = .inter(ofSize: 13, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(label)

        window.addSubview(blur)

        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
            tint.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
            tint.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),

            blur.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8),
            blur.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            blur.heightAnchor.constraint(equalToConstant: 34),

            spinner.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 12),
            spinner.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
        ])

        hudView = blur
        blur.alpha = 0
        blur.transform = CGAffineTransform(translationX: 0, y: -8)
        UIView.animate(withDuration: 0.2) {
            blur.alpha = 1
            blur.transform = .identity
        }
    }

    private func hide() {
        guard let hud = hudView else { return }
        hudView = nil
        UIView.animate(withDuration: 0.2, animations: {
            hud.alpha = 0
            hud.transform = CGAffineTransform(translationX: 0, y: -8)
        }, completion: { _ in
            hud.removeFromSuperview()
        })
    }
}
