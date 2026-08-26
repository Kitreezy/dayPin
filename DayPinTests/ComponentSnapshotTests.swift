import UIKit
import SnapshotTesting
import XCTest
@testable import DayPin

final class ComponentSnapshotTests: SnapshotCase {

    /// The shimmer animation is stripped by pinning the layer to its initial
    /// state - only the resting colours are asserted.
    func testSkeletonView() {
        let size = CGSize(width: 220, height: 16)
        assertLightAndDark({
            let view = SkeletonView(frame: CGRect(origin: .zero, size: size))
            return view
        }, size: size, named: "skeleton")
    }

    func testSkeletonRowGroup() {
        let size = CGSize(width: 320, height: 72)
        assertLightAndDark({
            let container = UIView(frame: CGRect(origin: .zero, size: size))
            container.backgroundColor = .clear
            let a = SkeletonView(frame: CGRect(x: 0, y: 8, width: 140, height: 14))
            let b = SkeletonView(frame: CGRect(x: 0, y: 34, width: 90, height: 14))
            container.addSubview(a)
            container.addSubview(b)
            return container
        }, size: size, named: "skeleton-rows")
    }
}
