import UIKit

protocol ImageAnnotationViewDelegate: AnyObject {
    func annotationView(_ view: ImageAnnotationView, didAddAnnotation annotation: ImageAnnotation)
    func annotationView(_ view: ImageAnnotationView, didUpdateAnnotation annotation: ImageAnnotation)
    func annotationView(_ view: ImageAnnotationView, didDeleteAnnotation annotation: ImageAnnotation)
}

final class ImageAnnotationView: UIView {

    weak var delegate: ImageAnnotationViewDelegate?
    var isEditingEnabled: Bool = true

    /// Set this to enable automatic zoom-to-pin on tap. The view weakly holds the reference.
    weak var zoomScrollView: UIScrollView?

    // MARK: Subviews

    private let imageView = UIImageView()
    private let ghostPin  = GhostPinView()

    private var pinViews:    [UUID: AnnotationPinView] = [:]
    private var annotations: [ImageAnnotation] = []

    private var draggingAnnotationID: UUID?
    private var dragOffset: CGPoint = .zero

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
        backgroundColor = UIColor { t in
            t.userInterfaceStyle == .dark ? .black : UIColor(white: 0.92, alpha: 1)
        }

        imageView.contentMode = .scaleAspectFit
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

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        lp.minimumPressDuration = 0.3
        addGestureRecognizer(lp)
    }

    // MARK: Public API

    func load(annotations: [ImageAnnotation]) {
        self.annotations = annotations
        pinViews.values.forEach { $0.removeFromSuperview() }
        pinViews.removeAll()
        annotations.forEach { addPinView(for: $0) }
    }

    /// Returns the annotation view's local coordinate for a given annotation.
    /// Used by parent VCs to zoom the scroll view to focus on a pin.
    func localPoint(for annotation: ImageAnnotation) -> CGPoint {
        pointFromNormalized(annotationPoint: CGPoint(x: annotation.x, y: annotation.y))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        repositionAllPins()
    }

    // MARK: Long-press for pin placement (tap/pan go to scroll view)

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard isEditingEnabled else { return }
        let point = gr.location(in: self)

        switch gr.state {
        case .began:
            guard imageContentFrame.contains(point) else { return }

            // Check if touching an existing pin — start drag instead of ghost
            if let (id, pin) = pinViews.first(where: { $0.value.frame.insetBy(dx: -14, dy: -14).contains(point) }) {
                draggingAnnotationID = id
                dragOffset = CGPoint(x: point.x - pin.center.x, y: point.y - pin.center.y)
                UIView.animate(withDuration: 0.15) { pin.transform = CGAffineTransform(scaleX: 1.35, y: 1.35) }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                return
            }

            showGhost(at: point)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .changed:
            if let id = draggingAnnotationID, let pin = pinViews[id] {
                let clamped = clampedToImageFrame(CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y))
                pin.center = clamped
                return
            }
            guard !ghostPin.isHidden else { return }
            ghostPin.center = clampedToImageFrame(point)

        case .ended:
            if let id = draggingAnnotationID, let pin = pinViews[id] {
                UIView.animate(withDuration: 0.15) { pin.transform = .identity }
                let clamped    = clampedToImageFrame(CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y))
                let normalized = normalizedPoint(from: clamped)
                if var annotation = annotations.first(where: { $0.id == id }) {
                    annotation.x = normalized.x
                    annotation.y = normalized.y
                    updateAnnotation(annotation)
                }
                draggingAnnotationID = nil
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                return
            }
            guard !ghostPin.isHidden else { return }
            let finalPoint = clampedToImageFrame(point)
            hideGhost()
            guard imageContentFrame.contains(finalPoint) else { return }
            let normalized  = normalizedPoint(from: finalPoint)
            let windowPoint = convert(finalPoint, to: window)
            presentAnnotationInput(at: normalized, windowPoint: windowPoint, existingAnnotation: nil)

        default:
            if let id = draggingAnnotationID, let pin = pinViews[id] {
                UIView.animate(withDuration: 0.15) { pin.transform = .identity }
                draggingAnnotationID = nil
            }
            hideGhost()
        }
    }

    // MARK: Ghost Pin

    private func showGhost(at point: CGPoint) {
        ghostPin.frame = CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)
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
        pin.annotationID = annotation.id
        pin.titleText = annotation.title
        pin.onTap = { [weak self, weak pin] in
            guard let id = pin?.annotationID else { return }
            self?.handlePinTap(annotationID: id)
        }
        addSubview(pin)
        bringSubviewToFront(ghostPin)
        pinViews[annotation.id] = pin
        positionPin(pin, for: annotation)
    }

    private func positionPin(_ pin: UIView, for annotation: ImageAnnotation) {
        let size: CGFloat = 18
        let point = pointFromNormalized(annotationPoint: CGPoint(x: annotation.x, y: annotation.y))
        let frame = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size, height: size
        )
        pin.frame = frame
        if let annotationPin = pin as? AnnotationPinView {
            let shouldFlipLeft = frame.maxX > imageContentFrame.maxX - 84
            annotationPin.titleOnLeft = shouldFlipLeft
            annotationPin.pinColor = annotation.color
        }
    }

    private func repositionAllPins() {
        for annotation in annotations {
            guard let pin = pinViews[annotation.id] else { continue }
            pin.titleText = annotation.title
            positionPin(pin, for: annotation)
        }
        bringSubviewToFront(ghostPin)
    }

    // MARK: Interaction

    private func handlePinTap(annotationID: UUID) {
        guard let annotation = annotations.first(where: { $0.id == annotationID }),
              let pinView = pinViews[annotationID] else { return }
        let pinCenter = pointFromNormalized(annotationPoint: CGPoint(x: annotation.x, y: annotation.y))

        let showCallout = { [weak self, weak pinView] in
            guard let self else { return }
            let windowPoint = self.convert(pinCenter, to: self.window)
            PinCalloutView.show(
                pinWindowPoint: windowPoint,
                title: annotation.title,
                text: annotation.text,
                colorHex: annotation.colorHex,
                sourcePinView: pinView,
                onEdit: { [weak self] newTitle, newText, newColorHex in
                    var updated = annotation
                    updated.title    = newTitle
                    updated.text     = newText
                    updated.colorHex = newColorHex
                    self?.updateAnnotation(updated)
                },
                onDelete: { [weak self] in self?.removeAnnotation(annotation) }
            )
        }

        // Zoom to 2.5× centred on pin if not already zoomed
        if let sv = zoomScrollView, sv.zoomScale < 1.5 {
            let targetZoom: CGFloat = 2.5
            let svSize = sv.bounds.size
            let zoomRect = CGRect(
                x: pinCenter.x - svSize.width  / (2 * targetZoom),
                y: pinCenter.y - svSize.height / (2 * targetZoom),
                width:  svSize.width  / targetZoom,
                height: svSize.height / targetZoom
            )
            sv.zoom(to: zoomRect, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: showCallout)
        } else {
            showCallout()
        }
    }

    private func presentAnnotationInput(at normalized: CGPoint, windowPoint: CGPoint, existingAnnotation: ImageAnnotation?) {
        let pinView = existingAnnotation.flatMap { pinViews[$0.id] }
        PinCalloutView.show(
            pinWindowPoint: windowPoint,
            title: existingAnnotation?.title ?? "",
            text:  existingAnnotation?.text  ?? "",
            colorHex: existingAnnotation?.colorHex ?? "#007AFF",
            startInEditMode: true,
            sourcePinView: pinView,
            onEdit: { [weak self] title, text, colorHex in
                if var existing = existingAnnotation {
                    existing.title    = title
                    existing.text     = text
                    existing.colorHex = colorHex
                    self?.updateAnnotation(existing)
                } else {
                    let annotation = ImageAnnotation(x: normalized.x, y: normalized.y, title: title, text: text, colorHex: colorHex)
                    self?.addAnnotation(annotation)
                }
            },
            onDelete: existingAnnotation == nil ? nil : { [weak self] in
                guard let existingAnnotation else { return }
                self?.removeAnnotation(existingAnnotation)
            }
        )
    }

    private func addAnnotation(_ annotation: ImageAnnotation) {
        annotations.append(annotation)
        addPinView(for: annotation)
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
        repositionAllPins()
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

    // MARK: - Coordinate space mapping

    private var imageContentFrame: CGRect {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return bounds }
        let viewSize  = bounds.size
        let imageSize = image.size
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let width  = imageSize.width  * scale
        let height = imageSize.height * scale
        let x = (viewSize.width  - width)  * 0.5
        let y = (viewSize.height - height) * 0.5
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func clampedToImageFrame(_ point: CGPoint) -> CGPoint {
        let r = imageContentFrame
        return CGPoint(
            x: min(max(point.x, r.minX), r.maxX),
            y: min(max(point.y, r.minY), r.maxY)
        )
    }

    private func normalizedPoint(from point: CGPoint) -> CGPoint {
        let r = imageContentFrame
        return CGPoint(
            x: max(0, min(1, (point.x - r.minX) / r.width)),
            y: max(0, min(1, (point.y - r.minY) / r.height))
        )
    }

    private func pointFromNormalized(annotationPoint: CGPoint) -> CGPoint {
        let r = imageContentFrame
        return CGPoint(
            x: r.minX + annotationPoint.x * r.width,
            y: r.minY + annotationPoint.y * r.height
        )
    }
}

// MARK: - GhostPinView

private final class GhostPinView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius  = 18
        layer.borderWidth   = 2
        layer.borderColor   = UIColor.white.cgColor
        backgroundColor     = UIColor.white.withAlphaComponent(0.25)
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius  = 10
        layer.shadowOffset  = .zero

        let dot = UIView()
        dot.backgroundColor  = .white
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
    var annotationID: UUID?
    var titleText: String = "" {
        didSet { updateTitle() }
    }
    var titleOnLeft: Bool = false {
        didSet { updateTitleSide() }
    }

    private let titleBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let titleLabel = UILabel()
    private var titleLeadingConstraint:  NSLayoutConstraint?
    private var titleTrailingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    // Exposed so callers can change color after creation
    var pinColor: UIColor = DayPinDesign.accent {
        didSet { applyColor() }
    }

    private weak var pinBlur: UIVisualEffectView?
    private weak var pinDot: UIView?
    private weak var pinBorder: UIView?

    private func setup() {
        layer.shadowOpacity = 0.5
        layer.shadowRadius  = 4
        layer.shadowOffset  = .zero

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.layer.cornerRadius = 9   // 18px pin → 9pt radius = circle
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        self.pinBlur = blur
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let dot = UIView()
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(dot)
        self.pinDot = dot
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6)
        ])

        applyColor()

        // Title badge
        titleBlur.layer.cornerRadius = 8
        titleBlur.clipsToBounds = true
        titleBlur.alpha = 0.85
        titleBlur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleBlur)

        titleLabel.font = .systemFont(ofSize: 10, weight: .bold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.numberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleBlur.contentView.addSubview(titleLabel)

        titleLeadingConstraint  = titleBlur.leadingAnchor.constraint(equalTo: trailingAnchor, constant: 4)
        titleTrailingConstraint = titleBlur.trailingAnchor.constraint(equalTo: leadingAnchor, constant: -4)
        titleTrailingConstraint?.isActive = false

        NSLayoutConstraint.activate([
            titleBlur.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleBlur.heightAnchor.constraint(equalToConstant: 16),
            titleBlur.widthAnchor.constraint(lessThanOrEqualToConstant: 90),

            titleLabel.topAnchor.constraint(equalTo: titleBlur.contentView.topAnchor, constant: 1),
            titleLabel.bottomAnchor.constraint(equalTo: titleBlur.contentView.bottomAnchor, constant: -1),
            titleLabel.leadingAnchor.constraint(equalTo: titleBlur.contentView.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: titleBlur.contentView.trailingAnchor, constant: -6)
        ])
        titleLeadingConstraint?.isActive = true
        updateTitle()
        updateTitleSide()

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    private func applyColor() {
        layer.shadowColor = pinColor.cgColor
        pinDot?.backgroundColor = pinColor
    }

    private func updateTitle() {
        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        titleLabel.text  = trimmed
        titleBlur.isHidden = trimmed.isEmpty
    }

    private func updateTitleSide() {
        titleLeadingConstraint?.isActive  = !titleOnLeft
        titleTrailingConstraint?.isActive =  titleOnLeft
    }

    @objc private func tapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) { self.transform = .identity }
        })
        onTap?()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -10, dy: -10).contains(point)
    }
}
