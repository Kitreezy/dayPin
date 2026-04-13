import UIKit

protocol ImageAnnotationViewDelegate: AnyObject {
    func annotationView(_ view: ImageAnnotationView, didAddAnnotation annotation: ImageAnnotation)
    func annotationView(_ view: ImageAnnotationView, didUpdateAnnotation annotation: ImageAnnotation)
    func annotationView(_ view: ImageAnnotationView, didDeleteAnnotation annotation: ImageAnnotation)
}

final class ImageAnnotationView: UIView {

    weak var delegate: ImageAnnotationViewDelegate?
    var isEditingEnabled: Bool = true

    // MARK: Subviews

    private let imageView = UIImageView()
    private let ghostPin = GhostPinView()

    private var pinViews: [UUID: AnnotationPinView] = [:]
    private var annotations: [ImageAnnotation] = []

    var image: UIImage? {
        didSet { imageView.image = image }
    }

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Setup

    private func setup() {
        clipsToBounds = true
        layer.cornerRadius = 16

        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addSubview(ghostPin)
        ghostPin.isHidden = true
    }

    // MARK: Public API

    func load(annotations: [ImageAnnotation]) {
        self.annotations = annotations
        pinViews.values.forEach { $0.removeFromSuperview() }
        pinViews.removeAll()
        annotations.forEach { addPinView(for: $0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        repositionAllPins()
    }

    // MARK: Touch Handling (ghost cursor)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEditingEnabled, let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }
        let point = touch.location(in: self)

        // If touching an existing pin — let it handle, don't show ghost
        if pinViews.values.contains(where: { $0.frame.insetBy(dx: -8, dy: -8).contains(point) }) {
            super.touchesBegan(touches, with: event)
            return
        }

        showGhost(at: point)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEditingEnabled, let touch = touches.first, !ghostPin.isHidden else {
            super.touchesMoved(touches, with: event)
            return
        }
        let point = touch.location(in: self)
        ghostPin.center = point
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEditingEnabled, let touch = touches.first, !ghostPin.isHidden else {
            super.touchesEnded(touches, with: event)
            return
        }
        let point = touch.location(in: self)
        hideGhost()

        let normalized = CGPoint(
            x: max(0, min(1, point.x / bounds.width)),
            y: max(0, min(1, point.y / bounds.height))
        )
        let windowPoint = convert(point, to: window)
        presentAnnotationInput(at: normalized, windowPoint: windowPoint, existingAnnotation: nil)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        hideGhost()
        super.touchesCancelled(touches, with: event)
    }

    // MARK: Ghost Pin

    private func showGhost(at point: CGPoint) {
        ghostPin.frame = CGRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44)
        ghostPin.isHidden = false
        ghostPin.alpha = 0
        ghostPin.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.ghostPin.alpha = 1
            self.ghostPin.transform = .identity
        }
    }

    private func hideGhost() {
        UIView.animate(withDuration: 0.12, delay: 0, options: .curveEaseIn) {
            self.ghostPin.alpha = 0
            self.ghostPin.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        } completion: { _ in
            self.ghostPin.isHidden = true
            self.ghostPin.transform = .identity
        }
    }

    // MARK: Pin Views

    private func addPinView(for annotation: ImageAnnotation) {
        let pin = AnnotationPinView()
        pin.onTap = { [weak self] in self?.handlePinTap(annotation: annotation) }
        addSubview(pin)
        bringSubviewToFront(ghostPin)
        pinViews[annotation.id] = pin
        positionPin(pin, for: annotation)
    }

    private func positionPin(_ pin: UIView, for annotation: ImageAnnotation) {
        let size: CGFloat = 32
        pin.frame = CGRect(
            x: CGFloat(annotation.x) * bounds.width - size / 2,
            y: CGFloat(annotation.y) * bounds.height - size / 2,
            width: size, height: size
        )
    }

    private func repositionAllPins() {
        for annotation in annotations {
            guard let pin = pinViews[annotation.id] else { continue }
            positionPin(pin, for: annotation)
        }
        bringSubviewToFront(ghostPin)
    }

    // MARK: Interaction

    private func handlePinTap(annotation: ImageAnnotation) {
        let pinCenter = CGPoint(
            x: CGFloat(annotation.x) * bounds.width,
            y: CGFloat(annotation.y) * bounds.height
        )
        let windowPoint = convert(pinCenter, to: window)

        PinCalloutView.show(
            pinWindowPoint: windowPoint,
            text: annotation.text,
            onEdit: { [weak self] newText in
                var updated = annotation
                updated.text = newText
                self?.updateAnnotation(updated)
            },
            onDelete: { [weak self] in
                self?.removeAnnotation(annotation)
            }
        )
    }

    private func presentAnnotationInput(at normalized: CGPoint, windowPoint: CGPoint, existingAnnotation: ImageAnnotation?) {
        AnnotationInputPopover.show(
            pinWindowPoint: windowPoint,
            existingText: existingAnnotation?.text,
            onSave: { [weak self] text in
                if var existing = existingAnnotation {
                    existing.text = text
                    self?.updateAnnotation(existing)
                } else {
                    let annotation = ImageAnnotation(x: normalized.x, y: normalized.y, text: text)
                    self?.addAnnotation(annotation)
                }
            }
        )
    }

    private func addAnnotation(_ annotation: ImageAnnotation) {
        annotations.append(annotation)
        addPinView(for: annotation)
        // Animate pin in
        let pin = pinViews[annotation.id]
        pin?.alpha = 0
        pin?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5) {
            pin?.alpha = 1
            pin?.transform = .identity
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        delegate?.annotationView(self, didAddAnnotation: annotation)
    }

    private func updateAnnotation(_ annotation: ImageAnnotation) {
        if let i = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[i] = annotation
        }
        delegate?.annotationView(self, didUpdateAnnotation: annotation)
    }

    private func removeAnnotation(_ annotation: ImageAnnotation) {
        let pin = pinViews[annotation.id]
        UIView.animate(withDuration: 0.2) {
            pin?.alpha = 0
            pin?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        } completion: { _ in
            pin?.removeFromSuperview()
        }
        pinViews.removeValue(forKey: annotation.id)
        annotations.removeAll { $0.id == annotation.id }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        delegate?.annotationView(self, didDeleteAnnotation: annotation)
    }
}

// MARK: - GhostPinView

private final class GhostPinView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 22
        layer.borderWidth = 2.5
        layer.borderColor = UIColor.white.cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.25)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 10
        layer.shadowOffset = .zero

        let dot = UIView()
        dot.backgroundColor = .white
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - AnnotationPinView

final class AnnotationPinView: UIView {

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.shadowColor = UIColor.systemBlue.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 8
        layer.shadowOffset = .zero

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.layer.cornerRadius = 16
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let dot = UIView()
        dot.backgroundColor = .systemBlue
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(dot)
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10)
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) { self.transform = .identity }
        })
        onTap?()
    }
}

// MARK: - UIView helper

private extension UIView {
    var parentViewController: UIViewController? {
        var r: UIResponder? = self
        while let next = r?.next { if let vc = next as? UIViewController { return vc }; r = next }
        return nil
    }
}
