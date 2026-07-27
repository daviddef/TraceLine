import Foundation

final class PlayerProgress {
    static let shared = PlayerProgress()
    private let defaults = UserDefaults.standard

    /// Clearing this level unlocks every remaining theme (end of World 1).
    static let worldOneFinalLevel = 10

    func recordCompletion(levelId: Int, stars: Int, score: Int) {
        let key = "level_\(levelId)"
        let current = defaults.integer(forKey: key + "_stars")
        if stars > current { defaults.set(stars, forKey: key + "_stars") }
        let currentScore = defaults.integer(forKey: key + "_score")
        if score > currentScore { defaults.set(score, forKey: key + "_score") }
        let highScore = defaults.integer(forKey: "global_highscore")
        if score > highScore { defaults.set(score, forKey: "global_highscore") }
    }

    func stars(for levelId: Int) -> Int {
        defaults.integer(forKey: "level_\(levelId)_stars")
    }

    func bestScore(for levelId: Int) -> Int {
        defaults.integer(forKey: "level_\(levelId)_score")
    }

    var globalHighScore: Int { defaults.integer(forKey: "global_highscore") }

    /// Levels cleared at least once.
    var completedLevelCount: Int {
        LevelConfig.all.filter { stars(for: $0.id) >= 1 }.count
    }

    func isUnlocked(_ levelId: Int) -> Bool {
        if freePlayEnabled || levelId == 1 { return true }
        return stars(for: levelId - 1) >= 1
    }

    /// A world opens when the previous world's final level is cleared. World 1 is always
    /// open — and Free Play opens all of them.
    func isWorldUnlocked(_ worldId: Int) -> Bool {
        guard !freePlayEnabled else { return true }
        guard worldId > 1 else { return true }
        guard let previous = WorldConfig.world(id: worldId - 1),
              let final = previous.finalLevelID else { return false }
        return stars(for: final) >= 1
    }

    /// The furthest world the player can actually play — where "Play" should land them.
    var furthestUnlockedWorld: Int {
        WorldConfig.all.last { isWorldUnlocked($0.id) }?.id ?? 1
    }

    // MARK: - Purchases
    // Written only by Store, which is inactive in v1, so these stay false.

    func isEntitled(_ productID: String) -> Bool {
        defaults.bool(forKey: "iap_\(productID)")
    }

    func setEntitled(_ productID: String, _ entitled: Bool) {
        defaults.set(entitled, forKey: "iap_\(productID)")
    }

    // MARK: - Themes

    func activeThemeKey() -> ThemeKey {
        let raw = defaults.string(forKey: "active_theme") ?? ThemeKey.neon.rawValue
        return ThemeKey(rawValue: raw) ?? .neon
    }

    func setTheme(_ key: ThemeKey) {
        defaults.set(key.rawValue, forKey: "active_theme")
    }

    // MARK: - Preferences

    /// Sound effects on/off. Defaults to on — but the hardware silent switch always
    /// wins regardless, because the audio session is `.ambient` (see SoundHook).
    /// `object(forKey:)` distinguishes "never set" (nil → default on) from an explicit off.
    var soundEnabled: Bool {
        get { defaults.object(forKey: "sound_enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "sound_enabled") }
    }

    /// When on, the game holds still — no camera shake or kick. This is the *in-app*
    /// override; the effective setting also honours the system Reduce Motion switch
    /// (see `Motion.isReduced`), so a player who has it on system-wide never has to
    /// find this toggle. Defaults off.
    var reduceMotion: Bool {
        get { defaults.object(forKey: "reduce_motion") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "reduce_motion") }
    }

    /// Real bloom on the drawn line — a soft luminous halo instead of the cheaper fixed
    /// glow. On by default; the one graphics knob a weaker device can drop. `object(forKey:)`
    /// distinguishes "never set" (nil → default on) from an explicit off.
    var glowEnabled: Bool {
        get { defaults.object(forKey: "glow_enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "glow_enabled") }
    }

    /// Whether the first-run how-to-play has been shown. The game fails you fast, so a cold
    /// open is punishing; this gates a one-time tutorial before the first visit to the menu.
    var hasSeenTutorial: Bool {
        get { defaults.bool(forKey: "seen_tutorial") }
        set { defaults.set(newValue, forKey: "seen_tutorial") }
    }

    /// Free Play: every world, level and theme unlocked, no earning required. Free for now;
    /// this is the flag a future purchase would flip. While it is on, the unlock checks
    /// below all answer true, so the whole game is open without touching the real star
    /// record underneath.
    var freePlayEnabled: Bool {
        get { defaults.bool(forKey: "free_play") }
        set { defaults.set(newValue, forKey: "free_play") }
    }

    /// Total stars earned across the whole game.
    var totalStars: Int { LevelConfig.all.reduce(0) { $0 + stars(for: $1.id) } }

    /// True if a world's final level has been cleared.
    func hasClearedWorld(_ worldId: Int) -> Bool {
        guard let world = WorldConfig.world(id: worldId), let final = world.finalLevelID
        else { return false }
        return stars(for: final) >= 1
    }

    func isThemeUnlocked(_ key: ThemeKey) -> Bool {
        if freePlayEnabled { return true }
        switch Theme.theme(for: key).requirement {
        case .free:                 return true
        case .clearWorld(let w):    return hasClearedWorld(w)
        case .collectStars(let n):  return totalStars >= n
        }
    }

    func unlockedThemes() -> [ThemeKey] { ThemeKey.allCases.filter(isThemeUnlocked) }


    /// Debug helper — unlocks every level so later levels can be reached directly.
    func unlockAll() {
        for level in LevelConfig.all {
            defaults.set(max(1, stars(for: level.id)), forKey: "level_\(level.id)_stars")
        }
    }

    /// Debug helper — marks levels 1...count as cleared, for inspecting a mid-journey
    /// map without playing there.
    func seedProgress(upTo count: Int) {
        for level in LevelConfig.all where level.id <= count {
            let stars = [3, 2, 3, 1, 2][(level.id - 1) % 5]
            defaults.set(stars, forKey: "level_\(level.id)_stars")
            defaults.set(level.id * 1000, forKey: "level_\(level.id)_score")
        }
        defaults.set(4200, forKey: "global_highscore")
    }

    /// Debug helper — wipes all saved progress.
    func reset() {
        for level in LevelConfig.all {
            defaults.removeObject(forKey: "level_\(level.id)_stars")
            defaults.removeObject(forKey: "level_\(level.id)_score")
        }
        defaults.removeObject(forKey: "global_highscore")
        defaults.removeObject(forKey: "active_theme")
    }
}
