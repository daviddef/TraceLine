import XCTest
@testable import TraceLine

/// Shelters are terrain: hazards rebound off them and a line tucked inside is out of
/// reach. Hiding costs the clock, not the line.
final class SafeZoneTests: XCTestCase {

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    private let zone = SafeZone(center: CGPoint(x: 0, y: 0), radius: 50)

    func testContains() {
        XCTAssertTrue(zone.contains(p(0, 0)))
        XCTAssertTrue(zone.contains(p(49, 0)))
        XCTAssertFalse(zone.contains(p(51, 0)))
    }

    func testShelterNeedsTheWholeSegmentInside() {
        XCTAssertTrue(zone.shelters(from: p(-10, 0), to: p(10, 0)))
        // Straddling the edge is not sheltered: the part sticking out is exposed, and
        // pretending otherwise would let a player park half a line in cover.
        XCTAssertFalse(zone.shelters(from: p(-10, 0), to: p(80, 0)))
        XCTAssertFalse(zone.shelters(from: p(100, 0), to: p(200, 0)))
    }

    // MARK: - Lane shadows

    func testLaneThroughTheMiddleIsBlockedAcrossTheFullDiameter() {
        let block = zone.laneBlock(atY: 0, halfHeight: 0)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.lowerBound ?? 0, -50, accuracy: 0.001)
        XCTAssertEqual(block?.upperBound ?? 0, 50, accuracy: 0.001)
    }

    func testLaneClippingTheEdgeIsBlockedOverAShorterSpan() {
        guard let block = zone.laneBlock(atY: 40, halfHeight: 0) else {
            return XCTFail("a lane at y=40 clips a radius-50 zone")
        }
        // Half-span = sqrt(50^2 - 40^2) = 30
        XCTAssertEqual(block.lowerBound, -30, accuracy: 0.001)
        XCTAssertEqual(block.upperBound, 30, accuracy: 0.001)
    }

    func testLanePassingClearIsNotBlocked() {
        XCTAssertNil(zone.laneBlock(atY: 200, halfHeight: 0))
    }

    /// The cutter's body has height, so a lane that would just miss the zone still
    /// collides with it.
    func testCutterHeightWidensTheBlock() {
        XCTAssertNil(zone.laneBlock(atY: 55, halfHeight: 0))
        XCTAssertNotNil(zone.laneBlock(atY: 55, halfHeight: 10))
    }

    // MARK: - Config

    func testConfigResolvesToTheSameSpotOnAnyScreen() {
        let config = SafeZoneConfig(x: 0.5, y: 0.5, radius: 0.1)
        let small = config.resolved(in: CGRect(x: 0, y: 0, width: 300, height: 600))
        let large = config.resolved(in: CGRect(x: -200, y: -400, width: 400, height: 800))

        XCTAssertEqual(small.center, CGPoint(x: 150, y: 300))
        XCTAssertEqual(small.radius, 30, accuracy: 0.001)
        XCTAssertEqual(large.center, CGPoint(x: 0, y: 0))
        XCTAssertEqual(large.radius, 40, accuracy: 0.001)
    }

    /// Zones are refuges, not farms. Coverage counts inside them, so a zone big enough to
    /// draw a winning score in would end the game.
    func testZonesStaySmallEnoughNotToBeAFarm() {
        for level in LevelConfig.all {
            for zone in level.zones {
                XCTAssertLessThanOrEqual(zone.radius, 0.18,
                                         "level \(level.id) has a zone big enough to hide and farm in")
                XCTAssertGreaterThan(zone.radius, 0.05, "level \(level.id): too small to shelter in")
            }
        }
    }

    func testZonesSitInsideTheBoard() {
        for level in LevelConfig.all {
            for zone in level.zones {
                XCTAssertTrue((0...1).contains(zone.x), "level \(level.id)")
                XCTAssertTrue((0...1).contains(zone.y), "level \(level.id)")
            }
        }
    }

    /// Level 1 teaches the two rules and nothing else.
    func testLevelOneHasNoZones() {
        XCTAssertTrue(LevelConfig.level(id: 1)?.zones.isEmpty ?? false)
    }

    // MARK: - Sheltered line

    /// A cut skips sheltered segments, so the last exposed crossing is where it lands.
    func testShelteredSegmentsAreNotCut() {
        let engine = DrawingEngine()
        let shelter = SafeZone(center: CGPoint(x: 50, y: 0), radius: 30)
        engine.begin(at: p(0, 0))
        for x in stride(from: CGFloat(10), through: 100, by: 5) {
            _ = engine.extend(to: p(x, 0), obstacles: [])
        }

        // A blade straight down the middle of the shelter takes nothing.
        let blocked = engine.cut(where: { a, b in
            GeometryHelpers.segmentsIntersect(a, b, CGPoint(x: 50, y: -100), CGPoint(x: 50, y: 100))
                && !shelter.shelters(from: a, to: b)
        })
        XCTAssertFalse(blocked, "line inside a shelter must be out of reach")
        XCTAssertEqual(engine.currentTip, p(100, 0))
    }
}
