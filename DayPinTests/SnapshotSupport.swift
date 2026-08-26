import UIKit
import SnapshotTesting
import XCTest
@testable import DayPin

// MARK: - Determinism
//
// Snapshot tests must render byte-identically on every run. Three things in
// DayPin are ambient and would otherwise drift between runs:
//
//   1. NoteCard.createdAt defaults to Date() and cells print it as "HH:mm"
//   2. those "HH:mm" labels are rendered in the machine's local time zone
//   3. L10n picks Russian/English from the system locale
//   4. DayPinDesign colours read the accent scheme from ThemeManager
//
// `SnapshotCase` pins all three in setUp so a diff can only ever come from an
// actual UI change.

class SnapshotCase: XCTestCase {

    /// 2026-01-15 09:41:00 UTC - fixed so "HH:mm" labels never drift.
    static let fixedDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 15
        c.hour = 9; c.minute = 41; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date(timeIntervalSince1970: 1_768_470_060)
    }()

    private var savedLanguage: String?
    private var savedScheme: ColorSchemeID?
    private var savedTimeZone: TimeZone?

    override func setUp() {
        super.setUp()
        savedLanguage = L10n.languageOverride
        savedScheme = ThemeManager.shared.colorScheme.id
        savedTimeZone = NSTimeZone.default

        L10n.languageOverride = "en"
        ThemeManager.shared.colorScheme = .violet
        // Cells format createdAt with a plain DateFormatter, which uses the
        // default zone - without this the same card renders "09:41" here and
        // "12:41" on a machine three hours east.
        NSTimeZone.default = TimeZone(identifier: "UTC") ?? .current
    }

    override func tearDown() {
        L10n.languageOverride = savedLanguage
        if let scheme = savedScheme {
            ThemeManager.shared.colorScheme = scheme.scheme
        }
        if let tz = savedTimeZone { NSTimeZone.default = tz }
        super.tearDown()
    }

    // MARK: - Fixtures

    func makeTextCard(title: String = "Morning standup",
                      comment: String = "Discussed the sync layer and agreed on the rollout order.") -> TextCard {
        let card = TextCard(title: title, comment: comment, dayDate: Self.fixedDate)
        card.createdAt = Self.fixedDate
        return card
    }

    func makeLinkCard(title: String = "Point-Free",
                      urlString: String = "https://www.pointfree.co") -> LinkCard {
        let url = URL(string: urlString) ?? URL(fileURLWithPath: "/")
        let card = LinkCard(title: title, comment: "Worth watching later", dayDate: Self.fixedDate, url: url)
        card.createdAt = Self.fixedDate
        card.previewTitle = "Point-Free: Functional programming in Swift"
        return card
    }

    func makeImageCard(title: String = "Whiteboard") -> ImageCard {
        let card = ImageCard(title: title,
                             comment: "Sketch of the sync flow",
                             dayDate: Self.fixedDate,
                             imageData: Self.solidImageData())
        card.createdAt = Self.fixedDate
        return card
    }

    /// Deterministic stand-in for a user photo - a flat colour beats bundling a fixture asset.
    static func solidImageData(size: CGSize = CGSize(width: 240, height: 160)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(red: 0.42, green: 0.36, blue: 0.72, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 1, alpha: 0.35).setFill()
            ctx.fill(CGRect(x: 0, y: size.height * 0.6, width: size.width, height: size.height * 0.4))
        }
        return image.pngData() ?? Data()
    }

    // MARK: - Rendering

    /// Card cells live in a 2-column grid at a fixed 160pt height (see the
    /// compositional layout in TodayViewController).
    static let cardCellSize = CGSize(width: 180, height: 160)

    /// Lays a view out at an exact size and asserts it in both light and dark,
    /// producing two named snapshots per call.
    func assertLightAndDark(
        _ makeView: () -> UIView,
        size: CGSize,
        named name: String,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let view = makeView()
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()

            let suffix = style == .light ? "light" : "dark"
            assertSnapshot(
                of: view,
                as: .image(traits: UITraitCollection(userInterfaceStyle: style)),
                named: "\(name)-\(suffix)",
                file: file, testName: testName, line: line
            )
        }
    }
}
