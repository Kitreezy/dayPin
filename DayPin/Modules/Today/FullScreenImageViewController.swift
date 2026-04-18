import UIKit

/// Full-screen image viewer with pinch-to-zoom and swipe-down-to-dismiss.
final class FullScreenImageViewController: UIViewController {

    private let image: UIImage
    private weak var sourceView: UIView?

    private let scrollView   = UIScrollView()
    private let imageView    = UIImageView()
    private let backgroundView = UIView()
    private let closeButton  = UIView()

    // Swipe-down tracking
    private var panStart: CGPoint = .zero
    private var isAnimatingDismiss = false

    init(image: UIImage, sourceView: UIView?) {
        self.image      = image
        self.sourceView = sourceView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupBackground()
        setupScrollView()
        setupCloseButton()
        setupGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Setup

    private func setupBackground() {
        backgroundView.backgroundColor = .black
        backgroundView.alpha = 0
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        imageView.image       = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])

        imageView.alpha = 0
    }

    private func setupCloseButton() {
        // Frosted glass pill with a small × symbol
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.layer.cornerRadius  = 14
        blur.layer.masksToBounds = true
        blur.isUserInteractionEnabled = false
        blur.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        icon.tintColor = UIColor.white.withAlphaComponent(0.9)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor)
        ])

        closeButton.addSubview(blur)
        closeButton.alpha = 0
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: closeButton.topAnchor),
            blur.leadingAnchor.constraint(equalTo: closeButton.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: closeButton.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss(_:)))
        closeButton.addGestureRecognizer(tap)
        closeButton.isUserInteractionEnabled = true

        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func setupGestures() {
        // Tap to dismiss (only when not zoomed)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(tap)

        // Double-tap to zoom
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)

        // Pan to dismiss (swipe down)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        scrollView.addGestureRecognizer(pan)
    }

    // MARK: - Animations

    private func animateIn() {
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
            self.backgroundView.alpha = 1
            self.imageView.alpha      = 1
            self.closeButton.alpha    = 1
        }
    }

    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
            self.backgroundView.alpha = 0
            self.imageView.alpha      = 0
            self.closeButton.alpha    = 0
        } completion: { _ in
            completion()
        }
    }

    // MARK: - Gestures

    @objc private func handleTap() {
        guard scrollView.zoomScale == 1 else { return }
        dismissViewer()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1 {
            scrollView.setZoomScale(1, animated: true)
        } else {
            let point = recognizer.location(in: imageView)
            let rect  = CGRect(origin: CGPoint(x: point.x - 40, y: point.y - 40),
                               size: CGSize(width: 80, height: 80))
            scrollView.zoom(to: rect, animated: true)
        }
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard scrollView.zoomScale == 1, !isAnimatingDismiss else { return }
        let translation = pan.translation(in: view)

        switch pan.state {
        case .began:
            panStart = translation
        case .changed:
            let dy = max(0, translation.y)
            let progress = min(dy / 260, 1)
            scrollView.transform = CGAffineTransform(translationX: 0, y: dy)
            backgroundView.alpha = 1 - progress * 0.7
            closeButton.alpha    = 1 - progress
        case .ended, .cancelled:
            let velocity = pan.velocity(in: view).y
            let dy = translation.y
            if dy > 100 || velocity > 600 {
                isAnimatingDismiss = true
                UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn) {
                    self.scrollView.transform  = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                    self.backgroundView.alpha  = 0
                    self.closeButton.alpha     = 0
                } completion: { _ in
                    self.dismiss(animated: false)
                }
            } else {
                UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
                    self.scrollView.transform = .identity
                    self.backgroundView.alpha = 1
                    self.closeButton.alpha    = 1
                }
            }
        default:
            break
        }
    }

    @objc private func dismiss(_ sender: Any) {
        dismissViewer()
    }

    private func dismissViewer() {
        animateOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }
}

// MARK: - UIScrollViewDelegate

extension FullScreenImageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width  - scrollView.contentSize.width)  / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        imageView.center = CGPoint(
            x: scrollView.contentSize.width  / 2 + offsetX,
            y: scrollView.contentSize.height / 2 + offsetY
        )
    }
}

// MARK: - UIGestureRecognizerDelegate

extension FullScreenImageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Allow pan-to-dismiss alongside scrollView pan only when at zoom scale 1
        return scrollView.zoomScale == 1
    }
}
