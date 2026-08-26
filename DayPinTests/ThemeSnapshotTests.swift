import UIKit
import SnapshotTesting
import XCTest
@testable import DayPin

/// The accent palette caused two real regressions: colours baked in at init and
/// never refreshed, and accent-on-accent chips going unreadable on pale schemes.
/// Rendering a card across the extremes of the palette pins both.
final class ThemeSnapshotTests: SnapshotCase {

    /// Spring is the palest accent and Vintage the darkest - if a contrast rule
    /// breaks anywhere, it breaks at one of these two ends first.
    private let extremes: [(name: String, scheme: AppColorScheme)] = [
        ("violet", .violet),
        ("spring", .spring),
        ("vintage", .vintage)
    ]

    func testTextCardAcrossAccentSchemes() {
        for (name, scheme) in extremes {
            ThemeManager.shared.colorScheme = scheme
            assertLightAndDark({
                let cell = TextCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
                cell.configure(with: self.makeTextCard())
                return cell
            }, size: Self.cardCellSize, named: "text-card-\(name)")
        }
    }

    func testLinkCardAcrossAccentSchemes() {
        for (name, scheme) in extremes {
            ThemeManager.shared.colorScheme = scheme
            assertLightAndDark({
                let cell = LinkCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
                cell.configure(with: self.makeLinkCard())
                return cell
            }, size: Self.cardCellSize, named: "link-card-\(name)")
        }
    }

    /// accentContrast must resolve to a *different* shade than the raw accent in
    /// at least one mode, otherwise the contrast fix has silently regressed to
    /// plain `accent`.
    func testAccentContrastDiffersFromAccentOnPaleScheme() {
        ThemeManager.shared.colorScheme = .spring

        let light = UITraitCollection(userInterfaceStyle: .light)
        let contrastLight = DayPinDesign.accentContrast.resolvedColor(with: light)
        let accentLight = DayPinDesign.accent.resolvedColor(with: light)

        XCTAssertNotEqual(contrastLight, accentLight,
            "In light mode accentContrast should fall back to the deeper accent so text stays readable on a pale chip")

        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let contrastDark = DayPinDesign.accentContrast.resolvedColor(with: dark)
        XCTAssertNotEqual(contrastDark, contrastLight,
            "accentContrast must resolve differently per interface style")
    }
}
