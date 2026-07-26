import XCTest
import SpriteKit
@testable import TraceLine

/// World 5's mechanic. A Hunter does not fall — it steers toward the drawing tip every
/// frame. These pin the movement so it cannot quietly stop hunting the way Magnetic once
/// shipped inert.
final class HunterTests: XCTestCase {

    private let playRect = CGRect(x: -177, y: -350, width: 354, height: 700)

    private func hunter() -> ObstacleNode { ObstacleNode(type: .hunter, theme: Theme.active) }

    func testAHunterMovesTowardItsTarget() {
        let h = hunter()
        h.position = CGPoint(x: 0, y: 200)
        h.huntTarget = CGPoint(x: 0, y: -200)
        let before = h.position.y
        h.update(dt: 0.5, playRect: playRect)
        XCTAssertLessThan(h.position.y, before, "the hunter should close on a target below it")
    }

    func testAHunterClosesInFromAnyDirection() {
        let target = CGPoint(x: 120, y: -80)
        for start in [CGPoint(x: -150, y: 150), CGPoint(x: 150, y: 150), CGPoint(x: 0, y: -300)] {
            let h = hunter()
            h.position = start
            h.huntTarget = target
            let d0 = GeometryHelpers.distance(h.position, target)
            h.update(dt: 0.3, playRect: playRect)
            let d1 = GeometryHelpers.distance(h.position, target)
            XCTAssertLessThan(d1, d0, "distance to prey should shrink from \(start)")
        }
    }

    func testAHunterMovesAtRoughlyItsRatedSpeed() {
        let h = hunter()
        h.position = CGPoint(x: 0, y: 200)
        h.huntTarget = CGPoint(x: 0, y: -200)
        h.update(dt: 1.0, playRect: playRect)
        let travelled = 200 - h.position.y
        XCTAssertEqual(travelled, ObstacleNode.hunterSpeed, accuracy: 1.0,
                       "one second of hunting should cover about one second of speed")
    }

    func testAHunterWithoutATargetHoldsStill() {
        let h = hunter()
        h.position = CGPoint(x: 10, y: 20)
        h.huntTarget = nil
        h.update(dt: 0.5, playRect: playRect)
        XCTAssertEqual(h.position, CGPoint(x: 10, y: 20), "no prey, no movement")
    }

    func testAHunterNeverOvershootsIntoJitter() {
        // A large dt from very close must land on the target, not fly past and oscillate.
        let h = hunter()
        h.position = CGPoint(x: 0, y: 1)
        let target = CGPoint(x: 0, y: 0)
        h.huntTarget = target
        h.update(dt: 5.0, playRect: playRect)
        XCTAssertLessThanOrEqual(GeometryHelpers.distance(h.position, target), 1.0,
                                 "the hunter should settle on the tip, not overshoot it")
    }

    /// The hunter is a lethal circle, like a blocker — it ends the round on contact rather
    /// than severing or igniting.
    func testAHunterIsLethalOnContact() {
        XCTAssertTrue(ObstacleType.hunter.isLethal)
        XCTAssertFalse(ObstacleType.hunter.severs)
        XCTAssertFalse(ObstacleType.hunter.ignites)
    }
}
