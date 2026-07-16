import XCTest
@testable import TraceLine

/// The two rules that define the game live in DrawingEngine, so they get tested directly.
final class DrawingEngineTests: XCTestCase {

    private var engine: DrawingEngine!

    override func setUp() {
        super.setUp()
        engine = DrawingEngine()
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// Walks the engine along a path, asserting every step is legal.
    @discardableResult
    private func draw(_ points: [CGPoint], obstacles: [ObstacleDescriptor] = []) -> DrawResult {
        var last: DrawResult = .ok
        for point in points {
            last = engine.extend(to: point, obstacles: obstacles)
            if last != .ok { return last }
        }
        return last
    }

    // MARK: - Rule 2: lines can never cross

    func testStraightLineDoesNotCross() {
        engine.begin(at: p(0, 0))
        XCTAssertEqual(draw([p(50, 0), p(100, 0), p(150, 0)]), .ok)
        XCTAssertEqual(engine.pointCount, 4)
    }

    func testOpenSpiralDoesNotCross() {
        // A path that doubles back close to itself but never actually touches.
        engine.begin(at: p(0, 0))
        XCTAssertEqual(draw([p(100, 0), p(100, 100), p(10, 100), p(10, 10), p(90, 10)]), .ok)
    }

    func testSelfCrossingIsRejected() {
        // Draws three sides of a square then cuts back through the first side.
        engine.begin(at: p(0, 0))
        XCTAssertEqual(draw([p(100, 0), p(100, 100), p(50, 100)]), .ok)
        XCTAssertEqual(engine.extend(to: p(50, -50), obstacles: []), .fail(.lineCrossed))
    }

    func testRejectedPointIsNotRecorded() {
        engine.begin(at: p(0, 0))
        draw([p(100, 0), p(100, 100), p(50, 100)])
        let countBefore = engine.pointCount
        let distanceBefore = engine.totalDistance

        _ = engine.extend(to: p(50, -50), obstacles: [])

        XCTAssertEqual(engine.pointCount, countBefore, "a crossing point must not be appended")
        XCTAssertEqual(engine.totalDistance, distanceBefore, "a crossing must not add distance")
    }

    func testAdjacentSegmentIsNotTreatedAsACrossing() {
        // Consecutive segments share an endpoint; that shared point must not
        // register as a self-intersection or drawing would be impossible.
        engine.begin(at: p(0, 0))
        for i in 1...50 {
            let point = p(CGFloat(i) * 5, CGFloat(i % 2) * 5)
            XCTAssertEqual(engine.extend(to: point, obstacles: []), .ok,
                           "sharp zigzag at step \(i) was wrongly rejected")
        }
    }

    func testDoublingBackAlongTheSameLineCrosses() {
        // Reversing directly back over the path is an overlap, not a legal move.
        engine.begin(at: p(0, 0))
        XCTAssertEqual(draw([p(50, 0), p(100, 0)]), .ok)
        XCTAssertEqual(engine.extend(to: p(20, 0), obstacles: []), .fail(.lineCrossed))
    }

    // MARK: - Point spacing

    func testPointsCloserThanMinimumSpacingAreIgnored() {
        engine.begin(at: p(0, 0))
        XCTAssertEqual(engine.extend(to: p(1, 0), obstacles: []), .ok)
        XCTAssertEqual(engine.pointCount, 1, "sub-spacing movement should not record a point")
        XCTAssertEqual(engine.totalDistance, 0)
    }

    func testDistanceAccumulates() {
        engine.begin(at: p(0, 0))
        draw([p(30, 0), p(30, 40)])
        XCTAssertEqual(engine.totalDistance, 70, accuracy: 0.001)
    }

    // MARK: - Obstacles

    private func circle(_ id: Int, _ x: CGFloat, _ y: CGFloat, r: CGFloat = 14) -> ObstacleDescriptor {
        ObstacleDescriptor(id: id, shape: .circle(center: p(x, y), radius: r))
    }

    func testDrawingIntoAnObstacleFails() {
        engine.begin(at: p(0, 0))
        XCTAssertEqual(engine.extend(to: p(100, 0), obstacles: [circle(1, 100, 0)]),
                       .fail(.obstacleHit))
    }

    func testDrawingClearOfAnObstacleSucceeds() {
        engine.begin(at: p(0, 0))
        XCTAssertEqual(engine.extend(to: p(100, 0), obstacles: [circle(1, 100, 200)]), .ok)
    }

    /// A fast flick can jump far enough to land clear on the other side of an
    /// obstacle. The whole segment must be tested, not just its endpoint.
    func testFastFlickCannotTunnelThroughAnObstacle() {
        engine.begin(at: p(0, 0))
        let result = engine.extend(to: p(200, 0), obstacles: [circle(1, 100, 0)])
        XCTAssertEqual(result, .fail(.obstacleHit), "the line jumped straight over an obstacle")
    }

    func testObstacleFallingOntoAStationaryTipFails() {
        engine.begin(at: p(0, 0))
        XCTAssertEqual(engine.checkTipCollision(obstacles: [circle(1, 500, 500)]), .ok)
        // The obstacle now occupies the tip's position.
        XCTAssertEqual(engine.checkTipCollision(obstacles: [circle(1, 0, 0)]), .fail(.obstacleHit))
    }

    func testRectObstacleIsHit() {
        let rect = ObstacleDescriptor(id: 1, shape: .rect(CGRect(x: 75, y: -6, width: 50, height: 12)))
        engine.begin(at: p(0, 0))
        XCTAssertEqual(engine.extend(to: p(200, 0), obstacles: [rect]), .fail(.obstacleHit))
    }

    // MARK: - Near misses

    func testPassingCloseCountsOneNearMissPerObstacle() {
        // Skims past a single obstacle, recording many points inside its near-miss ring.
        engine.begin(at: p(0, 30))
        let obstacle = circle(1, 50, 0)
        for x in stride(from: CGFloat(5), through: 100, by: 5) {
            _ = engine.extend(to: p(x, 30), obstacles: [obstacle])
        }
        XCTAssertEqual(engine.nearMissCount, 1,
                       "one pass by one obstacle should count once, not once per point")
    }

    func testStayingWellClearRecordsNoNearMiss() {
        engine.begin(at: p(0, 300))
        for x in stride(from: CGFloat(5), through: 100, by: 5) {
            _ = engine.extend(to: p(x, 300), obstacles: [circle(1, 50, 0)])
        }
        XCTAssertEqual(engine.nearMissCount, 0)
    }

    func testLeavingAndReenteringCountsTwice() {
        // Approaches the obstacle, retreats out of range, then comes back down beside
        // it — taking care never to re-touch the earlier path, which would be a crossing.
        let obstacle = circle(1, 50, 0)
        engine.begin(at: p(0, 30))
        XCTAssertEqual(engine.extend(to: p(50, 30), obstacles: [obstacle]), .ok)   // near
        XCTAssertEqual(engine.nearMissCount, 1)

        XCTAssertEqual(engine.extend(to: p(50, 100), obstacles: [obstacle]), .ok)  // clear
        XCTAssertEqual(engine.extend(to: p(60, 100), obstacles: [obstacle]), .ok)
        XCTAssertEqual(engine.extend(to: p(60, 25), obstacles: [obstacle]), .ok)   // near again

        XCTAssertEqual(engine.nearMissCount, 2)
    }

    // MARK: - Coverage

    func testCoverageIsZeroBeforeDrawing() {
        engine.begin(at: p(10, 10))
        XCTAssertEqual(engine.coveragePercent(in: CGRect(x: 0, y: 0, width: 100, height: 100),
                                              gridSize: 10), 0)
    }

    func testFullSweepApproachesCompleteCoverage() {
        // Serpentine fill of every row — should cover nearly the whole grid.
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        engine.begin(at: p(1, 1))
        var goingRight = true
        for row in 0..<10 {
            let y = CGFloat(row) * 10 + 5
            let xs: [CGFloat] = goingRight ? [5, 95] : [95, 5]
            _ = engine.extend(to: p(xs[0], y), obstacles: [])
            _ = engine.extend(to: p(xs[1], y), obstacles: [])
            goingRight.toggle()
        }
        let coverage = engine.coveragePercent(in: rect, gridSize: 10)
        XCTAssertGreaterThan(coverage, 0.9, "a full serpentine sweep should cover almost every cell")
    }

    /// Points are only recorded every 4pt or further apart, so coverage has to be
    /// measured along each segment — sampling only the vertices would under-count
    /// a long, fast stroke.
    func testCoverageCountsCellsCrossedBetweenDistantPoints() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        engine.begin(at: p(5, 5))
        _ = engine.extend(to: p(95, 5), obstacles: [])   // one segment straight across a row
        let coverage = engine.coveragePercent(in: rect, gridSize: 10)
        // Ten cells in that row = 10 of 100 cells.
        XCTAssertEqual(coverage, 0.10, accuracy: 0.011,
                       "every cell the segment passes through should count")
    }

    func testCoverageIgnoresPointsOutsideThePlayRect() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        engine.begin(at: p(5, 5))
        _ = engine.extend(to: p(500, 500), obstacles: [])
        let coverage = engine.coveragePercent(in: rect, gridSize: 10)
        XCTAssertLessThanOrEqual(coverage, 1.0)
        XCTAssertGreaterThan(coverage, 0)
    }

    // MARK: - Reset

    func testBeginResetsAllState() {
        engine.begin(at: p(0, 0))
        draw([p(50, 0), p(50, 50)])
        engine.begin(at: p(10, 10))
        XCTAssertEqual(engine.pointCount, 1)
        XCTAssertEqual(engine.totalDistance, 0)
        XCTAssertEqual(engine.nearMissCount, 0)
        XCTAssertEqual(engine.currentTip, p(10, 10))
    }
}
