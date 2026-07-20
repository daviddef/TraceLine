import XCTest
@testable import TraceLine

/// World 3's mechanic. A Fuse is a Cutter whose cut point keeps advancing: it does not end
/// the round on contact, it sets the line alight and then eats toward your fingertip until
/// you reach shelter. The first hazard in the game you can *beat* rather than only dodge.
final class FuseTests: XCTestCase {

    private var engine: DrawingEngine!
    override func setUp() { super.setUp(); engine = DrawingEngine() }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// A vertical blade at `x`, standing in for a fuse landing on the line there.
    private func contact(atX x: CGFloat) -> (CGPoint, CGPoint) -> Bool {
        { a, b in
            GeometryHelpers.segmentsIntersect(a, b, CGPoint(x: x, y: -500), CGPoint(x: x, y: 500))
        }
    }

    /// A straight line from (0,0) to (200,0), recorded every 10pt.
    private func drawStraightLine() {
        engine.begin(at: p(0, 0))
        for x in stride(from: CGFloat(10), through: 200, by: 10) {
            _ = engine.extend(to: p(x, 0), obstacles: [])
        }
    }

    // MARK: - Ignition

    func testIgnitionDoesNotEndTheRound() {
        drawStraightLine()
        XCTAssertTrue(engine.ignite(where: contact(atX: 100)))
        XCTAssertTrue(engine.isBurning)
        // The finger is still down and drawing continues.
        XCTAssertEqual(engine.extend(to: p(200, 40), obstacles: []), .ok)
    }

    func testIgnitionTakesEverythingBehindTheContact() {
        drawStraightLine()
        engine.ignite(where: contact(atX: 100))
        XCTAssertTrue(engine.points.allSatisfy { $0.x > 100 },
                      "the line behind the contact point has already burnt")
    }

    func testCannotIgniteTwice() {
        drawStraightLine()
        XCTAssertTrue(engine.ignite(where: contact(atX: 60)))
        XCTAssertFalse(engine.ignite(where: contact(atX: 120)),
                       "a second fuse must not restart a burn already running")
    }

    func testNoIgnitionWhenNothingIsTouched() {
        drawStraightLine()
        XCTAssertFalse(engine.ignite(where: contact(atX: 900)))
        XCTAssertFalse(engine.isBurning)
    }

    // MARK: - The burn

    func testTheFlameEatsTowardTheFingertip() {
        drawStraightLine()
        engine.ignite(where: contact(atX: 100))
        let frontBefore = engine.burnFront?.x ?? 0
        XCTAssertEqual(engine.advanceBurn(distance: 25), .burning)
        let frontAfter = engine.burnFront?.x ?? 0
        XCTAssertGreaterThan(frontAfter, frontBefore, "the flame should move toward the tip")
        XCTAssertEqual(frontAfter - frontBefore, 25, accuracy: 0.001)
    }

    func testTheTipItselfIsNeverEaten() {
        drawStraightLine()
        engine.ignite(where: contact(atX: 100))
        engine.advanceBurn(distance: 30)
        XCTAssertEqual(engine.currentTip, p(200, 0), "the fingertip is where the player is")
    }

    /// The whole point of the mechanic: progress visibly retreats while you run.
    func testBurningRetractsCoverage() {
        let rect = CGRect(x: 0, y: -50, width: 220, height: 100)
        drawStraightLine()
        engine.ignite(where: contact(atX: 20))
        let before = engine.coveragePercent(in: rect, gridSize: 10)
        engine.advanceBurn(distance: 120)
        let after = engine.coveragePercent(in: rect, gridSize: 10)
        XCTAssertLessThan(after, before, "the flame must give coverage back as it eats")
    }

    func testTheFlameCatchingTheTipEndsIt() {
        drawStraightLine()
        engine.ignite(where: contact(atX: 100))
        XCTAssertEqual(engine.advanceBurn(distance: 10_000), .reachedTheTip)
        XCTAssertFalse(engine.isBurning, "a finished burn stops burning")
    }

    func testAdvancingWithoutAFuseDoesNothing() {
        drawStraightLine()
        let count = engine.pointCount
        XCTAssertEqual(engine.advanceBurn(distance: 50), .notBurning)
        XCTAssertEqual(engine.pointCount, count)
    }

    // MARK: - Escape

    func testExtinguishingKeepsWhatIsLeft() {
        drawStraightLine()
        engine.ignite(where: contact(atX: 100))
        engine.advanceBurn(distance: 20)
        let survived = engine.pointCount
        engine.extinguish()

        XCTAssertFalse(engine.isBurning)
        XCTAssertEqual(engine.advanceBurn(distance: 500), .notBurning)
        XCTAssertEqual(engine.pointCount, survived, "reaching shelter must stop the loss dead")
    }

    /// Reaching a shelter is what saves you, so the check the scene will use has to work
    /// on the real tip.
    func testShelterContainsTheTipAfterRunningIntoIt() {
        let shelter = SafeZone(center: p(200, 0), radius: 30)
        drawStraightLine()
        engine.ignite(where: contact(atX: 100))
        guard let tip = engine.currentTip else { return XCTFail("no tip") }
        XCTAssertTrue(shelter.contains(tip), "the tip is inside the shelter, so the flame dies")
    }

    // MARK: - Interaction with the rest of the rules

    func testBeginningANewRoundClearsTheBurn() {
        drawStraightLine()
        engine.ignite(where: contact(atX: 100))
        engine.begin(at: p(0, 0))
        XCTAssertFalse(engine.isBurning, "a new round must not start alight")
    }

    /// Burning frees board space, and the freed space has to be drawable again — otherwise
    /// the flame would be pure loss with no way to recover.
    func testBurntSpaceCanBeRedrawn() {
        engine.begin(at: p(0, 0))
        _ = engine.extend(to: p(100, 0), obstacles: [])
        _ = engine.extend(to: p(100, 100), obstacles: [])
        _ = engine.extend(to: p(50, 100), obstacles: [])
        // Crossing the earlier run is illegal while it is there.
        XCTAssertEqual(engine.extend(to: p(50, -50), obstacles: []), .fail(.lineCrossed))

        engine.ignite(where: contact(atX: 75))
        XCTAssertEqual(engine.extend(to: p(50, -50), obstacles: []), .ok,
                       "the burnt span is gone, so that move is legal now")
    }
}
