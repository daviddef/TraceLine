import CoreGraphics
import Foundation

/// Which game the scene is running.
enum GameMode: Equatable {
    /// One board from `levels.json`, cleared or failed.
    case levels
    /// Waves that never stop coming.
    case endless
}

/// Endless mode.
///
/// The problem endless has to solve is that filling the board is a *dead end*: coverage
/// counts cells the line crosses, so a board that fills up leaves nowhere legal to draw.
/// In level mode hitting the target is the win. Here it has to be a doorway instead.
///
/// So endless is **waves**. Reach the target and the board clears, the difficulty steps up,
/// and you keep going — without lifting your finger. The no-lift rule spans the whole run,
/// which means a run is one unbroken line drawn across many boards rather than a series of
/// separate attempts. That is the hook: not "survive a board", but "never let go".
enum Endless {

    /// Difficulty stops climbing here; past it the run is a test of endurance at full tilt
    /// rather than of ever-rising demand. Reaching this at all is already a long run.
    static let plateauWave = 25

    /// Hazards arrive one at a time, in the order World 1 and 2 teach them, so a player who
    /// came through the levels meets them in an order they already know.
    static func hazards(forWave wave: Int) -> [ObstacleType] {
        var types: [ObstacleType] = []
        if wave >= 2  { types.append(.blocker) }
        if wave >= 4  { types.append(.mover) }
        if wave >= 6  { types.append(.cutter) }
        if wave >= 9  { types.append(.magnetic) }
        if wave >= 12 { types.append(.shrinker) }
        return types
    }

    /// The board for a given wave. Deterministic: everyone who reaches wave 7 draws the
    /// same wave 7, which is what makes a leaderboard mean anything.
    static func config(forWave wave: Int) -> LevelConfig {
        let w = min(max(1, wave), plateauWave)
        let grid = min(32, 15 + w)
        let target = min(0.80, 0.40 + Float(w) * 0.02)
        let time = max(16, 46 - Double(w) * 1.2)

        return LevelConfig(
            id: 10_000 + wave,          // outside the levels.json range
            name: "Wave \(wave)",
            world: 0,                   // endless belongs to no world
            timeLimit: time,
            targetCoverage: target,
            obstacleTypes: hazards(forWave: wave),
            spawnInterval: max(1.2, 5.0 - Double(w) * 0.2),
            maxObstacles: min(8, 1 + w / 2),
            gridSize: grid,
            safeZones: shelters(forWave: wave),
            lineEffect: effect(forWave: wave)
        )
    }

    /// Shelters, placed from the wave number so the board is the same for everyone.
    private static func shelters(forWave wave: Int) -> [SafeZoneConfig] {
        guard wave >= 5 else { return [] }
        let count = wave >= 11 ? 2 : 1
        return (0..<count).map { i in
            // A stable hash of the wave, so placement looks scattered but never moves.
            let seed = Double((wave &* 7919) &+ (i &* 104_729))
            let fx = 0.22 + 0.56 * fract(sin(seed * 12.9898) * 43758.5453)
            let fy = 0.20 + 0.60 * fract(sin(seed * 78.233) * 24634.6345)
            return SafeZoneConfig(x: Float(fx), y: Float(fy), radius: 0.12)
        }
    }

    /// A flourish every few waves, so long runs are not visually monotonous. Effects that
    /// recolour, dim or dash the line are skipped once cutters are in play, exactly as in
    /// the levels — the doomed-tail warning has to stay readable.
    private static func effect(forWave wave: Int) -> LineEffect {
        let safeOnly = hazards(forWave: wave).contains(.cutter)
        let pool: [LineEffect] = safeOnly
            ? [.plain, .spark, .comet, .ember]
            : [.plain, .spark, .prism, .pulse, .fade, .chase, .flicker]
        return pool[(wave / 3) % pool.count]
    }

    private static func fract(_ x: Double) -> Double { x - x.rounded(.down) }

    /// Banked for clearing a wave: the wave itself is worth more each time, and time left
    /// on the clock converts to points, so clearing fast is worth more than clearing.
    static func waveBonus(wave: Int, timeRemaining: TimeInterval) -> Int {
        wave * 100 + Int(max(0, timeRemaining) * 10)
    }
}
