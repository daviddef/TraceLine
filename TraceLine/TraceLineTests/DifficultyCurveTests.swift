import XCTest
@testable import TraceLine

/// Measures what each level actually asks of the player, using the real coverage
/// algorithm rather than intuition about the numbers in levels.json.
///
/// The honest unit of difficulty here is **how many passes of the board you must draw**.
/// Coverage counts cells the line crosses, so a serpentine of R evenly spaced rows on an
/// N×N grid covers roughly R/N — meaning the rows you need is `targetCoverage × gridSize`,
/// and `gridSize` is as strong a difficulty lever as the target percentage itself.
final class DifficultyCurveTests: XCTestCase {

    /// iPhone 17 Pro play area: 402−48 wide, 874−100−74 tall.
    private let playRect = CGRect(x: -177, y: -350, width: 354, height: 700)

    /// Draws an R-row serpentine and returns the coverage it achieves.
    private func coverage(rows: Int, gridSize: Int) -> Float {
        let engine = DrawingEngine()
        let inset: CGFloat = 12
        let usable = playRect.height - inset * 2
        let spacing = rows > 1 ? usable / CGFloat(rows - 1) : 0
        let left = playRect.minX + inset, right = playRect.maxX - inset

        var y = playRect.maxY - inset
        var goingRight = true
        engine.begin(at: CGPoint(x: left, y: y))

        for _ in 0..<rows {
            let a = CGPoint(x: goingRight ? left : right, y: y)
            let b = CGPoint(x: goingRight ? right : left, y: y)
            step(engine, from: a, to: b)
            y -= spacing
            if y >= playRect.minY + inset {
                step(engine, from: b, to: CGPoint(x: b.x, y: y))
            }
            goingRight.toggle()
        }
        return engine.coveragePercent(in: playRect, gridSize: gridSize)
    }

    private func step(_ engine: DrawingEngine, from a: CGPoint, to b: CGPoint) {
        let d = GeometryHelpers.distance(a, b)
        let steps = max(1, Int(d / 5))
        for s in 1...steps {
            let t = CGFloat(s) / CGFloat(steps)
            _ = engine.extend(to: CGPoint(x: a.x + (b.x - a.x) * t,
                                          y: a.y + (b.y - a.y) * t), obstacles: [])
        }
    }

    /// Passes of the board needed to clear a level, and the drawing speed that implies.
    private func demand(for level: LevelConfig) -> (rows: Int, ptsPerSecond: Double) {
        for rows in 2...60 where coverage(rows: rows, gridSize: level.gridSize) >= level.targetCoverage {
            let travel = Double(rows) * Double(playRect.width - 24)
                       + Double(playRect.height)          // the vertical connectors
            return (rows, travel / level.timeLimit)
        }
        return (99, .infinity)
    }

    func testPrintTheCurve() {
        print("\n  lvl  name            world  target  grid  time   rows  pt/s   hazards")
        for level in LevelConfig.all {
            let d = demand(for: level)
            let speed = d.ptsPerSecond.isFinite ? String(format: "%5.0f", d.ptsPerSecond) : "  ---"
            print(String(format: "  %3d  %-14@  %3d   %5.2f   %3d  %4.0fs   %3d  %@   %@",
                         level.id, level.displayName as NSString, level.world,
                         level.targetCoverage, level.gridSize, level.timeLimit,
                         d.rows, speed, level.obstacleTypes.map(\.rawValue).joined(separator: ",")))
        }
    }

    /// Every level must demand more of the player than the one before it — across the
    /// whole game, not per world. A new world introduces a new idea; it does not hand back
    /// difficulty already earned.
    ///
    /// The measure is required drawing speed, which combines how much board you must fill
    /// with how long you get. Target coverage alone means nothing on its own, because
    /// `gridSize` is an equally strong lever: passes needed ≈ target × gridSize.
    func testDemandNeverStallsOrGoesBackwards() {
        var previous = 0.0
        var stalls: [String] = []
        for level in LevelConfig.all {
            let speed = demand(for: level).ptsPerSecond
            if speed <= previous {
                stalls.append(String(format: "level %d (%@) asks %.0f pt/s, the level before asked %.0f",
                                     level.id, level.displayName as NSString, speed, previous))
            }
            previous = speed
        }
        XCTAssertTrue(stalls.isEmpty, "difficulty stalls or resets:\n  " + stalls.joined(separator: "\n  "))
    }

    /// The board must genuinely fill up more as the game goes on, not just get rushed.
    func testTheBoardFillsMoreAsTheGameGoesOn() {
        let first = demand(for: LevelConfig.all.first!).rows
        let last = demand(for: LevelConfig.all.last!).rows
        XCTAssertGreaterThanOrEqual(last, first * 3,
                                    "the finale should ask for several times the drawing of level 1")
        var previous = 0
        for level in LevelConfig.all {
            let rows = demand(for: level).rows
            XCTAssertGreaterThanOrEqual(rows, previous,
                                        "level \(level.id) asks for less drawing than the one before")
            previous = rows
        }
    }

    /// Level 1 teaches two rules on an empty board and should stay forgiving.
    func testLevelOneStaysGentle() {
        guard let one = LevelConfig.level(id: 1) else { return XCTFail("level 1 missing") }
        XCTAssertLessThan(demand(for: one).ptsPerSecond, 60,
                          "level 1 is the tutorial and must not demand fast drawing")
    }
}
