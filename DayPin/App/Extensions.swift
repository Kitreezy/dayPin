import UIKit

extension UIViewController {
    /// Adds a tap gesture to `view` that dismisses the first responder on tap.
    func addKeyboardDismissGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(_dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    @objc private func _dismissKeyboard() { view.endEditing(true) }
}

extension UIView {
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-8, 8, -6, 6, -4, 4, 0]
        layer.add(animation, forKey: "shake")
    }
}

extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 6 { s += "FF" }
        guard s.count == 8, let val = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((val >> 24) & 0xFF) / 255,
            green: CGFloat((val >> 16) & 0xFF) / 255,
            blue:  CGFloat((val >> 8)  & 0xFF) / 255,
            alpha: CGFloat( val        & 0xFF) / 255
        )
    }
    var hexString: String {
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}

extension NSAttributedString {
    /// Fills in missing font/color while preserving existing rich-text attributes.
    func applying(baseColor: UIColor, baseFont: UIFont) -> NSAttributedString {
        let mas = NSMutableAttributedString(attributedString: self)
        let full = NSRange(location: 0, length: length)
        mas.enumerateAttribute(.font, in: full) { val, range, _ in
            if val == nil { mas.addAttribute(.font, value: baseFont, range: range) }
        }
        mas.enumerateAttribute(.foregroundColor, in: full) { val, range, _ in
            if val == nil { mas.addAttribute(.foregroundColor, value: baseColor, range: range) }
        }
        return mas
    }
}

extension UIAlertAction {
    convenience init(title: String, image: UIImage?, handler: ((UIAlertAction) -> Void)? = nil) {
        self.init(title: title, style: .default, handler: handler)
        self.setValue(image, forKey: "image")
    }
}
