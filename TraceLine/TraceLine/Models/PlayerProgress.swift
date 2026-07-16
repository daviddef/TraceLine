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
        if levelId == 1 { return true }
        return stars(for: levelId - 1) >= 1
    }

    // MARK: - Themes

    func activeThemeKey() -> ThemeKey {
        let raw = defaults.string(forKey: "active_theme") ?? ThemeKey.neon.rawValue
        return ThemeKey(rawValue: raw) ?? .neon
    }

    func setTheme(_ key: ThemeKey) {
        defaults.set(key.rawValue, forKey: "active_theme")
    }

    /// Neon is always available; clearing World 1 unlocks the rest.
    func unlockedThemes() -> [ThemeKey] {
        guard stars(for: Self.worldOneFinalLevel) >= 1 else { return [.neon] }
        return ThemeKey.allCases
    }

    func isThemeUnlocked(_ key: ThemeKey) -> Bool { unlockedThemes().contains(key) }

    /// Debug helper — unlocks every level so later levels can be reached directly.
    func unlockAll() {
        for level in LevelConfig.all {
            defaults.set(max(1, stars(for: level.id)), forKey: "level_\(level.id)_stars")
        }
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
