import UIKit
import SnapshotTesting
import XCTest
@testable import DayPin

/// Card cells are the most-repeated UI in the app and the surface most likely
/// to regress silently when the design system changes, so they are pinned in
/// both colour schemes.
final class CardCellSnapshotTests: SnapshotCase {

    func testTextCardCell() {
        assertLightAndDark({
            let cell = TextCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
            cell.configure(with: self.makeTextCard())
            return cell
        }, size: Self.cardCellSize, named: "text-card")
    }

    func testTextCardCellWithoutComment() {
        assertLightAndDark({
            let cell = TextCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
            cell.configure(with: self.makeTextCard(title: "Buy milk", comment: ""))
            return cell
        }, size: Self.cardCellSize, named: "text-card-no-comment")
    }

    /// Long unbroken text is the classic truncation regression.
    func testTextCardCellLongTitle() {
        assertLightAndDark({
            let cell = TextCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
            cell.configure(with: self.makeTextCard(
                title: "Quarterly planning session with the whole platform team",
                comment: "Agenda, owners, deadlines and the follow-up items we agreed to revisit next week."
            ))
            return cell
        }, size: Self.cardCellSize, named: "text-card-long")
    }

    func testImageCardCell() {
        assertLightAndDark({
            let cell = ImageCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
            cell.configure(with: self.makeImageCard())
            return cell
        }, size: Self.cardCellSize, named: "image-card")
    }

    func testLinkCardCell() {
        assertLightAndDark({
            let cell = LinkCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
            cell.configure(with: self.makeLinkCard())
            return cell
        }, size: Self.cardCellSize, named: "link-card")
    }

    // NOTE: EmptyCardCell is deliberately NOT snapshotted. It hosts a Lottie
    // animation that has not rendered its first frame by the time the snapshot
    // is taken, so the reference captures a half-drawn shape - a baseline that
    // proves nothing about the cell and would flake on any timing change.
    // Its layout is covered by the constraint assertions in
    // EmptyCardCellLayoutTests instead.

    // MARK: - Multi-select overlay

    func testTextCardCellSelected() {
        assertLightAndDark({
            let cell = TextCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
            cell.configure(with: self.makeTextCard())
            cell.applySelectionOverlay(isSelecting: true, isSelected: true)
            return cell
        }, size: Self.cardCellSize, named: "text-card-selected")
    }

    func testTextCardCellUnselectedInSelectMode() {
        assertLightAndDark({
            let cell = TextCardCell(frame: CGRect(origin: .zero, size: Self.cardCellSize))
            cell.configure(with: self.makeTextCard())
            cell.applySelectionOverlay(isSelecting: true, isSelected: false)
            return cell
        }, size: Self.cardCellSize, named: "text-card-unselected")
    }
}
