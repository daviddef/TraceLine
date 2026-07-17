import XCTest
@testable import TraceLine

/// Worlds were decoration until now: the `world` field existed but only ever printed on
/// the win screen. These pin the structure so a third world is data, not surgery.
final class WorldTests: XCTestCase {

    func testWorldsJSONLoads() {
        XCTAssertFalse(WorldConfig.all.isEmpty, "worlds.json failed to load — is it in the bundle?")
    }

    func testWorldIDsAreSequentialAndUnique() {
        XCTAssertEqual(WorldConfig.all.map(\.id), Array(1...WorldConfig.all.count))
    }

    func testEveryLevelBelongsToADeclaredWorld() {
        let declared = Set(WorldConfig.all.map(\.id))
        for level in LevelConfig.all {
            XCTAssertTrue(declared.contains(level.world),
                          "level \(level.id) claims world \(level.world), which does not exist")
        }
    }

    func testEveryWorldHasLevels() {
        for world in WorldConfig.all {
            XCTAssertFalse(world.levels.isEmpty, "world \(world.id) has no levels")
        }
    }

    /// The trail is one wave down one screen. Twenty nodes on it would be a list again.
    func testNoWorldIsTooBigForOneTrail() {
        for world in WorldConfig.all {
            XCTAssertLessThanOrEqual(world.levels.count, 12,
                                     "world \(world.id) has too many levels to fit one trail")
        }
    }

    func testWorldLevelsAreContiguousAndInOrder() {
        for world in WorldConfig.all {
            let ids = world.levels.map(\.id)
            XCTAssertEqual(ids, ids.sorted(), "world \(world.id) levels are out of order")
            XCTAssertEqual(ids.last! - ids.first! + 1, ids.count,
                           "world \(world.id) has gaps in its level ids")
        }
    }

    func testEveryWorldIsNamed() {
        for world in WorldConfig.all {
            XCTAssertFalse(world.name.isEmpty, "world \(world.id) is unnamed")
            XCTAssertFalse(world.subtitle.isEmpty, "world \(world.id) has no subtitle")
        }
    }

    /// Each world should introduce something, or it is just the last one with bigger
    /// numbers — which the research is explicit is not enough to hold anyone.
    func testEachWorldIntroducesSomethingNew() {
        var seen: Set<ObstacleType> = []
        for world in WorldConfig.all {
            let here = Set(world.levels.flatMap(\.obstacleTypes))
            if world.id > 1 {
                XCTAssertFalse(here.subtracting(seen).isEmpty,
                               "world \(world.id) introduces no hazard World \(world.id - 1) "
                               + "did not already have — it is the last world with bigger numbers")
            }
            seen.formUnion(here)
        }
    }
}

/// World 2's idea. Magnetic shipped in v1 as a lie: it pulsed and had no effect on the
/// engine at all.
final class MagneticPullTests: XCTestCase {

    private var engine: DrawingEngine!
    override func setUp() { super.setUp(); engine = DrawingEngine() }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private func magnet(_ id: Int, _ x: CGFloat, _ y: CGFloat,
                        pull: CGFloat = 3.2, radius: CGFloat = 78) -> ObstacleDescriptor {
        ObstacleDescriptor(id: id, shape: .circle(center: p(x, y), radius: 12),
                           pull: pull, pullRadius: radius)
    }

    func testAPointInsideTheFieldIsBentTowardTheMagnet() {
        let m = magnet(1, 0, 0)
        let bent = engine.pulled(p(40, 0), obstacles: [m])
        XCTAssertLessThan(bent.x, 40, "the point should be dragged toward the magnet")
        XCTAssertEqual(bent.y, 0, accuracy: 0.001, "no sideways drift on axis")
    }

    func testPullIsStrongerCloserIn() {
        let m = magnet(1, 0, 0)
        let near = 20 - engine.pulled(p(20, 0), obstacles: [m]).x
        let far = 70 - engine.pulled(p(70, 0), obstacles: [m]).x
        XCTAssertGreaterThan(near, far, "the field should bite harder up close")
    }

    /// The ring drawn on the board is the promise. A pull reaching past it would be the
    /// game cheating.
    func testNothingOutsideTheFieldIsTouched() {
        let m = magnet(1, 0, 0, radius: 78)
        let untouched = engine.pulled(p(200, 0), obstacles: [m])
        XCTAssertEqual(untouched, p(200, 0))
    }

    func testPullNeverOvershootsTheCentre() {
        // A huge pull from very close must not fling the point out the far side.
        let m = magnet(1, 0, 0, pull: 500)
        let bent = engine.pulled(p(2, 0), obstacles: [m])
        XCTAssertGreaterThanOrEqual(bent.x, 0, "the point flew past the magnet")
        XCTAssertLessThanOrEqual(bent.x, 2)
    }

    func testNonMagneticObstaclesDoNotPull() {
        let blocker = ObstacleDescriptor(id: 2, shape: .circle(center: p(0, 0), radius: 14))
        XCTAssertEqual(engine.pulled(p(30, 0), obstacles: [blocker]), p(30, 0))
    }

    /// The line really goes where it was bent, not where the finger asked.
    func testTheDrawnLineIsTheBentOne() {
        engine.begin(at: p(60, 60))
        XCTAssertEqual(engine.extend(to: p(60, 10), obstacles: [magnet(1, 0, 0)]), .ok)
        guard let tip = engine.currentTip else { return XCTFail("no tip") }
        XCTAssertLessThan(tip.x, 60, "the recorded point should be the deflected one")
    }

    func testAMagnetCanDragTheLineIntoItselfAndEndTheRound() {
        // Skimming the magnet's edge with a strong field pulls the line into the core.
        engine.begin(at: p(0, 40))
        let m = magnet(1, 0, 0, pull: 40, radius: 78)
        XCTAssertEqual(engine.extend(to: p(0, 18), obstacles: [m]), .fail(.obstacleHit))
    }
}
