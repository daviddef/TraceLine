import XCTest
@testable import TraceLine

final class GeometryHelpersTests: XCTestCase {

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    func testCrossingSegmentsIntersect() {
        XCTAssertTrue(GeometryHelpers.segmentsIntersect(p(0, 0), p(10, 10), p(0, 10), p(10, 0)))
    }

    func testParallelSegmentsDoNotIntersect() {
        XCTAssertFalse(GeometryHelpers.segmentsIntersect(p(0, 0), p(10, 0), p(0, 5), p(10, 5)))
    }

    func testSeparatedCollinearSegmentsDoNotIntersect() {
        XCTAssertFalse(GeometryHelpers.segmentsIntersect(p(0, 0), p(10, 0), p(20, 0), p(30, 0)))
    }

    func testOverlappingCollinearSegmentsIntersect() {
        XCTAssertTrue(GeometryHelpers.segmentsIntersect(p(0, 0), p(10, 0), p(5, 0), p(15, 0)))
    }

    func testTouchingEndpointCountsAsIntersection() {
        XCTAssertTrue(GeometryHelpers.segmentsIntersect(p(0, 0), p(10, 0), p(10, 0), p(10, 10)))
    }

    func testDistance() {
        XCTAssertEqual(GeometryHelpers.distance(p(0, 0), p(3, 4)), 5, accuracy: 0.0001)
    }

    func testDistanceToSegmentUsesPerpendicularDistance() {
        XCTAssertEqual(GeometryHelpers.distanceToSegment(p(5, 10), p(0, 0), p(10, 0)),
                       10, accuracy: 0.0001)
    }

    func testDistanceToSegmentClampsBeyondTheEnds() {
        // Nearest point is the endpoint, not the infinite line's projection.
        XCTAssertEqual(GeometryHelpers.distanceToSegment(p(20, 0), p(0, 0), p(10, 0)),
                       10, accuracy: 0.0001)
    }

    func testDistanceToDegenerateSegment() {
        XCTAssertEqual(GeometryHelpers.distanceToSegment(p(3, 4), p(0, 0), p(0, 0)),
                       5, accuracy: 0.0001)
    }
}

final class RoundScoreTests: XCTestCase {

    func testTotalSumsEveryComponent() {
        let score = RoundScore(baseDistance: 1000, coveragePct: 0.9,
                               timeRemaining: 20, nearMissCount: 0, starsEarned: 3)
        // 2000 distance + 900 coverage + 400 speed + 500 clean
        XCTAssertEqual(score.total, 3800)
    }

    func testSpeedBonusOnlyAppliesAboveTenSeconds() {
        let slow = RoundScore(baseDistance: 0, coveragePct: 0,
                              timeRemaining: 10, nearMissCount: 1, starsEarned: 1)
        XCTAssertEqual(slow.speed, 0)

        let fast = RoundScore(baseDistance: 0, coveragePct: 0,
                             timeRemaining: 11, nearMissCount: 1, starsEarned: 1)
        XCTAssertEqual(fast.speed, 220)
    }

    func testCleanBonusRequiresNoNearMisses() {
        let clean = RoundScore(baseDistance: 0, coveragePct: 0,
                               timeRemaining: 0, nearMissCount: 0, starsEarned: 1)
        XCTAssertEqual(clean.clean, 500)

        let scrappy = RoundScore(baseDistance: 0, coveragePct: 0,
                                 timeRemaining: 0, nearMissCount: 1, starsEarned: 1)
        XCTAssertEqual(scrappy.clean, 0)
    }
}

final class LevelConfigTests: XCTestCase {

    func testLevelsJSONLoadsFromTheBundle() {
        XCTAssertFalse(LevelConfig.all.isEmpty, "levels.json failed to load — is it in the bundle?")
    }

    func testLevelIDsAreSequentialAndUnique() {
        let ids = LevelConfig.all.map(\.id)
        XCTAssertEqual(ids, Array(1...ids.count))
    }

    /// Level 1 alone teaches the two rules with an empty board. Playtesting (and the
    /// obstacle schedule in HANDOVER, which contradicts its own level table) says
    /// obstacles have to arrive almost immediately — with none of them, the optimal
    /// strategy is a serpentine sweep, which is a drill rather than a game.
    func testOnlyLevelOneIsObstacleFree() {
        guard let one = LevelConfig.level(id: 1) else { return XCTFail("level 1 missing") }
        XCTAssertTrue(one.obstacleTypes.isEmpty, "level 1 should teach on an empty board")

        for level in LevelConfig.all.dropFirst() {
            XCTAssertFalse(level.obstacleTypes.isEmpty,
                           "level \(level.id) has nothing in the way")
            XCTAssertGreaterThan(level.maxObstacles, 0, "level \(level.id)")
        }
    }

    func testObstaclesArriveByLevelTwo() {
        guard let two = LevelConfig.level(id: 2) else { return XCTFail("level 2 missing") }
        XCTAssertEqual(two.obstacleTypes, [.blocker], "the first hazard should be the simplest")
    }

    func testMovingObstaclesArriveEarly() {
        let firstMover = LevelConfig.all.first { $0.obstacleTypes.contains(.mover) }
        XCTAssertNotNil(firstMover)
        XCTAssertLessThanOrEqual(firstMover?.id ?? 99, 4,
                                 "movers are the most popular hazard — they cannot wait until level 8")
    }

    /// Shrinker shipped in v1 fully built, themed and rotating, and never appeared once
    /// because no level listed it. Nothing else should be dead on arrival.
    func testEveryObstacleTypeIsActuallyUsed() {
        for type in ObstacleType.allCases {
            XCTAssertTrue(LevelConfig.all.contains { $0.obstacleTypes.contains(type) },
                          "\(type.rawValue) is implemented but no level spawns it")
        }
    }

    func testDifficultyRampsMonotonically() {
        let targets = LevelConfig.all.map(\.targetCoverage)
        XCTAssertEqual(targets, targets.sorted(), "coverage targets should never go backwards")
        let times = LevelConfig.all.map(\.timeLimit)
        XCTAssertEqual(times, times.sorted(by: >), "time limits should never grow")
    }

    func testEveryLevelIsInternallySensible() {
        for level in LevelConfig.all {
            XCTAssertGreaterThan(level.timeLimit, 0, "level \(level.id)")
            XCTAssertGreaterThan(level.gridSize, 0, "level \(level.id)")
            XCTAssertTrue((0...1).contains(level.targetCoverage), "level \(level.id)")
            // A level with obstacle types but no room to spawn them would never show any.
            if !level.obstacleTypes.isEmpty {
                XCTAssertGreaterThan(level.maxObstacles, 0, "level \(level.id)")
            }
        }
    }

    func testEveryObstacleTypeHasAColourInEveryTheme() {
        for key in ThemeKey.allCases {
            let theme = Theme.theme(for: key)
            for type in ObstacleType.allCases {
                XCTAssertLessThan(type.themeIndex, theme.obstacleColors.count,
                                  "\(key.rawValue) has no colour for \(type.rawValue)")
            }
        }
    }
}
