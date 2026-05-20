import UIKit

enum CardRenderer {

    static func render(_ card: NoteCard) -> UIImage {
        switch card.type {
        case .image:
            guard let imageCard = card as? ImageCard else { return renderPlaceholder(title: card.title, accent: .systemBlue) }
            return renderImage(imageCard)
        case .text:
            guard let textCard = card as? TextCard else { return renderPlaceholder(title: card.title, accent: .systemBlue) }
            return renderText(textCard)
        case .link:
            guard let linkCard = card as? LinkCard else { return renderPlaceholder(title: card.title, accent: .systemBlue) }
            return renderLink(linkCard)
        }
    }

    // MARK: - ImageCard (pins composited)

    static func renderImage(_ card: ImageCard) -> UIImage {
        guard let data = card.imageData, let base = UIImage(data: data) else {
            return renderPlaceholder(title: card.title, accent: .systemBlue)
        }
        guard !card.annotations.isEmpty else { return base }

        let size = base.size
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
            for ann in card.annotations {
                drawPin(at: CGPoint(x: ann.x * size.width, y: ann.y * size.height),
                        annotation: ann, imageSize: size)
            }
        }
    }

    private static func drawPin(at center: CGPoint,
                                annotation: ImageAnnotation,
                                imageSize: CGSize) {
        let color = UIColor(hex: annotation.colorHex) ?? .systemBlue
        let outer: CGFloat = 16
        let inner: CGFloat = 9
        let core:  CGFloat = 3.5

        color.withAlphaComponent(0.25).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - outer, y: center.y - outer,
                                    width: outer * 2, height: outer * 2)).fill()
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - inner, y: center.y - inner,
                                    width: inner * 2, height: inner * 2)).fill()
        UIColor { trait in UIColor.white }.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - core, y: center.y - core,
                                    width: core * 2, height: core * 2)).fill()

        let text = annotation.title.isEmpty ? annotation.text : annotation.title
        guard !text.isEmpty else { return }

        let badgePad: CGFloat = 7
        let fontSize = max(imageSize.width * 0.022, 12)
        let font = UIFont.inter(ofSize: fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor { trait in UIColor.white }]
        let ts = (text as NSString).size(withAttributes: attrs)
        let bw = ts.width + badgePad * 2
        let bh = ts.height + badgePad

        let bx = min(max(center.x - bw / 2, 4), imageSize.width  - bw - 4)
        let by = max(center.y - outer - bh - 6, 4)
        let badgeRect = CGRect(x: bx, y: by, width: bw, height: bh)

        color.withAlphaComponent(0.88).setFill()
        UIBezierPath(roundedRect: badgeRect, cornerRadius: bh / 2).fill()
        (text as NSString).draw(in: CGRect(x: bx + badgePad, y: by + badgePad / 2,
                                            width: ts.width, height: ts.height),
                                withAttributes: attrs)
    }

    // MARK: - TextCard

    static func renderText(_ card: TextCard) -> UIImage {
        let w: CGFloat = 640
        let pad: CGFloat = 36
        let maxW = w - pad * 2
        let titleFont = UIFont.inter(ofSize: 28, weight: .bold)
        let bodyFont = UIFont.inter(ofSize: 17)
        let brandFont = UIFont.inter(ofSize: 12, weight: .medium)
        let accent = UIColor { trait in UIColor(red: 0.56, green: 0.35, blue: 1.0, alpha: 1) }

        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor { trait in UIColor.white }]
        let bodyAttr:  [NSAttributedString.Key: Any] = [.font: bodyFont,  .foregroundColor: UIColor { trait in UIColor.white.withAlphaComponent(0.75) }]
        let brandAttr: [NSAttributedString.Key: Any] = [.font: brandFont, .foregroundColor: UIColor { trait in UIColor.white.withAlphaComponent(0.32) }]

        let titleSize = boundingSize(card.title,   attrs: titleAttr, maxWidth: maxW - 16)
        let body = card.comment
        let bodySize = body.isEmpty ? CGSize.zero
                                     : boundingSize(body, attrs: bodyAttr, maxWidth: maxW, maxHeight: 320)

        let h = pad + titleSize.height + (body.isEmpty ? 0 : 20 + bodySize.height) + 44 + pad
        let size = CGSize(width: w, height: h)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [UIColor { trait in UIColor(red: 0.10, green: 0.07, blue: 0.18, alpha: 1) }.cgColor,
                                         UIColor { trait in UIColor(red: 0.07, green: 0.05, blue: 0.12, alpha: 1) }.cgColor] as CFArray,
                                locations: nil)!
            ctx.cgContext.drawLinearGradient(bg, start: .zero,
                                             end: CGPoint(x: 0, y: size.height), options: [])
            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: pad, y: pad, width: 4, height: titleSize.height),
                         cornerRadius: 2).fill()
            (card.title as NSString).draw(
                in: CGRect(x: pad + 16, y: pad, width: maxW - 16, height: titleSize.height),
                withAttributes: titleAttr)
            if !body.isEmpty {
                (body as NSString).draw(
                    in: CGRect(x: pad, y: pad + titleSize.height + 20, width: maxW, height: bodySize.height),
                    withAttributes: bodyAttr)
            }
            ("DayPin" as NSString).draw(
                at: CGPoint(x: pad, y: size.height - pad - 16),
                withAttributes: brandAttr)
        }
    }

    // MARK: - LinkCard

    static func renderLink(_ card: LinkCard) -> UIImage {
        let w: CGFloat = 640
        let pad: CGFloat = 36
        let maxW = w - pad * 2
        let titleFont = UIFont.inter(ofSize: 24, weight: .bold)
        let urlFont = UIFont.inter(ofSize: 14)
        let descFont = UIFont.inter(ofSize: 15)
        let brandFont = UIFont.inter(ofSize: 12, weight: .medium)
        let accent = UIColor { trait in UIColor(red: 0.56, green: 0.35, blue: 1.0, alpha: 1) }

        let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor { trait in UIColor.white }]
        let urlAttr:   [NSAttributedString.Key: Any] = [.font: urlFont,   .foregroundColor: accent]
        let descAttr:  [NSAttributedString.Key: Any] = [.font: descFont,  .foregroundColor: UIColor { trait in UIColor.white.withAlphaComponent(0.65) }]
        let brandAttr: [NSAttributedString.Key: Any] = [.font: brandFont, .foregroundColor: UIColor { trait in UIColor.white.withAlphaComponent(0.32) }]

        let urlStr = card.url.host?.replacingOccurrences(of: "www.", with: "") ?? card.url.absoluteString
        let titleSize = boundingSize(card.title, attrs: titleAttr, maxWidth: maxW)
        let urlSize = (urlStr as NSString).size(withAttributes: urlAttr)
        let desc = card.previewDescription ?? ""
        let descSize = desc.isEmpty ? CGSize.zero
                                     : boundingSize(desc, attrs: descAttr, maxWidth: maxW, maxHeight: 160)

        let h = pad + titleSize.height + 10 + urlSize.height + (desc.isEmpty ? 0 : 14 + descSize.height) + 44 + pad
        let size = CGSize(width: w, height: h)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [UIColor { trait in UIColor(red: 0.06, green: 0.10, blue: 0.20, alpha: 1) }.cgColor,
                                         UIColor { trait in UIColor(red: 0.04, green: 0.07, blue: 0.13, alpha: 1) }.cgColor] as CFArray,
                                locations: nil)!
            ctx.cgContext.drawLinearGradient(bg, start: .zero,
                                             end: CGPoint(x: 0, y: size.height), options: [])
            (card.title as NSString).draw(in: CGRect(x: pad, y: pad, width: maxW, height: titleSize.height),
                                          withAttributes: titleAttr)
            let urlY = pad + titleSize.height + 10
            (urlStr as NSString).draw(at: CGPoint(x: pad, y: urlY), withAttributes: urlAttr)
            if !desc.isEmpty {
                (desc as NSString).draw(
                    in: CGRect(x: pad, y: urlY + urlSize.height + 14, width: maxW, height: descSize.height),
                    withAttributes: descAttr)
            }
            ("DayPin" as NSString).draw(
                at: CGPoint(x: pad, y: size.height - pad - 16),
                withAttributes: brandAttr)
        }
    }

    // MARK: - Helpers

    private static func boundingSize(_ text: String,
                                     attrs: [NSAttributedString.Key: Any],
                                     maxWidth: CGFloat,
                                     maxHeight: CGFloat = 2000) -> CGSize {
        (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: maxHeight),
            options: .usesLineFragmentOrigin,
            attributes: attrs,
            context: nil
        ).size
    }

    private static func renderPlaceholder(title: String, accent: UIColor) -> UIImage {
        let size = CGSize(width: 640, height: 320)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            accent.withAlphaComponent(0.2).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.inter(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor { trait in UIColor.white }
            ]
            (title as NSString).draw(at: CGPoint(x: 28, y: 28), withAttributes: attrs)
        }
    }
}
