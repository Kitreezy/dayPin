import UIKit
import XCTest
@testable import DayPin

/// EmptyCardCell hosts a Lottie view that never settles in time for a snapshot,
/// so its regression is guarded by measuring layout instead of pixels.
///
/// The original bug: the Today grid sized this cell with `.estimated(120)` while
/// its content needs far more, so UIKit resolved the conflict by breaking the
/// animation view's 90pt height constraint at runtime.
final class EmptyCardCellLayoutTests: XCTestCase {

    /// Must stay in sync with the empty-state branch of TodayViewController.makeLayout().
    private let layoutEstimatedHeight: CGFloat = 220
    private let gridWidth: CGFloat = 370

    func testContentFitsWithinLayoutEstimate() {
        let cell = EmptyCardCell(frame: CGRect(x: 0, y: 0, width: gridWidth, height: layoutEstimatedHeight))
        cell.layoutIfNeeded()

        let fitting = cell.contentView.systemLayoutSizeFitting(
            CGSize(width: gridWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        XCTAssertGreaterThan(fitting.height, 0, "Cell reported no intrinsic height - content is not laid out")
        XCTAssertLessThanOrEqual(
            fitting.height, layoutEstimatedHeight,
            """
            EmptyCardCell needs \(fitting.height)pt but the Today layout only estimates \
            \(layoutEstimatedHeight)pt. UIKit will break an inner constraint to compensate. \
            Raise the estimate in TodayViewController.makeLayout() to match.
            """
        )
    }

    /// A cell laid out at the estimated height must not need to overflow it.
    func testNoAmbiguousLayoutAtEstimatedHeight() {
        let cell = EmptyCardCell(frame: CGRect(x: 0, y: 0, width: gridWidth, height: layoutEstimatedHeight))
        cell.layoutIfNeeded()

        XCTAssertFalse(cell.contentView.hasAmbiguousLayout,
                       "EmptyCardCell content has an ambiguous layout at the estimated height")
    }
}
