import XCTest
@testable import TraceLine

/// Endless mode. The design problem it solves is that filling the board is a dead end —
/// coverage counts cells the line crosses, so a full board has nowhere legal left to draw.
/// Reaching the target is therefore a doorway, not a win: the board clears, difficulty
/// steps up, and the finger never lifts.
final class EndlessTests: XCTestCase {

    /// iPhone 17 Pro play area.
    private let playRect = CGRect(x: -177, y: -350, width: 354, height: 700)

    // MARK: - Escalation

    func testDemandRisesWaveOnWave() {
        var previousRows = 0
        for wave in 1...Endless.plateauWave {
            let c = Endless.config(forWave: wave)
            let rows = Int((c.targetCoverage * Float(c.gridSize)).rounded())
            XCTAssertGreaterThanOrEqual(rows, previousRows,
                                        "wave \(wave) asks for less drawing than wave \(wave - 1)")
            previousRows = rows
        }
        XCTAssertGreaterThan(previousRows, 20, "the last wave should be a serious board")
    }

    func testTheClockTightens() {
        var previous = Double.infinity
        for wave in 1...Endless.plateauWave {
            let t = Endless.config(forWave: wave).timeLimit
            XCTAssertLessThanOrEqual(t, previous, "wave \(wave) is more generous than the one before")
            previous = t
        }
    }

    func testWaveOneIsAnOnRamp() {
        let c = Endless.config(forWave: 1)
        XCTAssertTrue(c.obstacleTypes.isEmpty, "the first wave teaches the wave loop, nothing else")
        XCTAssertLessThan(c.targetCoverage, 0.5)
    }

    func testHazardsArriveOneAtATimeAndNeverLeave() {
        var seen: Set<ObstacleType> = []
        for wave in 1...Endless.plateauWave {
            let here = Set(Endless.config(forWave: wave).obstacleTypes)
            XCTAssertTrue(seen.isSubset(of: here), "wave \(wave) took a hazard away again")
            seen = here
        }
        // Endless should eventually throw everything at you. When a new hazard type is
        // added this fails until it has been given a wave, which is the point — the Fuse
        // exists in the engine today but is not yet an ObstacleType, and when it becomes
        // one it should turn up here too.
        XCTAssertEqual(seen, Set(ObstacleType.allCases),
                       "endless never uses: \(Set(ObstacleType.allCases).subtracting(seen))")
    }

    /// Past the plateau the board stops getting harder; the run becomes endurance. Config
    /// must stay stable rather than drifting into nonsense at high wave numbers.
    func testConfigIsStableBeyondThePlateau() {
        let atPlateau = Endless.config(forWave: Endless.plateauWave)
        for wave in [Endless.plateauWave + 1, 200, 10_000] {
            let c = Endless.config(forWave: wave)
            XCTAssertEqual(c.targetCoverage, atPlateau.targetCoverage)
            XCTAssertEqual(c.gridSize, atPlateau.gridSize)
            XCTAssertEqual(c.timeLimit, atPlateau.timeLimit)
            XCTAssertTrue((0...1).contains(c.targetCoverage))
        }
    }

    // MARK: - Fairness

    /// A leaderboard only means something if everyone's wave 7 is the same wave 7.
    func testWavesAreDeterministic() {
        for wave in [1, 5, 12, 25] {
            let a = Endless.config(forWave: wave), b = Endless.config(forWave: wave)
            XCTAssertEqual(a.targetCoverage, b.targetCoverage)
            XCTAssertEqual(a.gridSize, b.gridSize)
            XCTAssertEqual(a.obstacleTypes, b.obstacleTypes)
            XCTAssertEqual(a.zones.map(\.x), b.zones.map(\.x))
            XCTAssertEqual(a.zones.map(\.y), b.zones.map(\.y))
            XCTAssertEqual(a.effect, b.effect)
        }
    }

    func testSheltersLandOnTheBoard() {
        for wave in 1...40 {
            for zone in Endless.config(forWave: wave).zones {
                XCTAssertTrue((0...1).contains(zone.x), "wave \(wave)")
                XCTAssertTrue((0...1).contains(zone.y), "wave \(wave)")
                let resolved = zone.resolved(in: playRect)
                XCTAssertTrue(playRect.insetBy(dx: -resolved.radius, dy: -resolved.radius)
                                .contains(resolved.center), "wave \(wave) put a shelter off-board")
            }
        }
    }

    /// Same rule as the levels: an effect that recolours, dims or dashes the line must not
    /// share a board with a cutter, or it fights the doomed-tail warning.
    func testEffectsNeverFightTheCutterWarning() {
        for wave in 1...60 {
            let c = Endless.config(forWave: wave)
            if c.obstacleTypes.contains(.cutter) {
                XCTAssertFalse(c.effect.conflictsWithCutters,
                               "wave \(wave) uses \(c.effect.rawValue) alongside a cutter")
            }
        }
    }

    // MARK: - Scoring

    func testClearingFasterIsWorthMore() {
        let quick = Endless.waveBonus(wave: 3, timeRemaining: 20)
        let slow  = Endless.waveBonus(wave: 3, timeRemaining: 2)
        XCTAssertGreaterThan(quick, slow)
    }

    func testLaterWavesAreWorthMore() {
        XCTAssertGreaterThan(Endless.waveBonus(wave: 9, timeRemaining: 0),
                             Endless.waveBonus(wave: 2, timeRemaining: 0))
    }

    func testNoTimeLeftIsNeverNegative() {
        XCTAssertGreaterThan(Endless.waveBonus(wave: 1, timeRemaining: -5), 0)
    }

    // MARK: - Separation from the levels

    /// Endless boards must never be mistaken for level data — they are generated, share no
    /// ids with levels.json, and belong to no world.
    func testEndlessBoardsAreNotLevels() {
        let levelIDs = Set(LevelConfig.all.map(\.id))
        for wave in 1...30 {
            let c = Endless.config(forWave: wave)
            XCTAssertFalse(levelIDs.contains(c.id), "wave \(wave) collides with a real level id")
            XCTAssertEqual(c.world, 0)
            XCTAssertNil(WorldConfig.world(id: c.world))
        }
    }
}
