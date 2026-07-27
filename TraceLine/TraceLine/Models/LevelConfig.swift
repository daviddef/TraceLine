import Foundation

enum ObstacleType: String, Codable, CaseIterable {
    case blocker, mover, magnetic, shrinker, cutter, fuse, hunter

    var themeIndex: Int {
        switch self {
        case .blocker:  return 0
        case .mover:    return 1
        case .magnetic: return 2
        case .shrinker: return 3
        case .cutter:   return 4
        case .fuse:     return 5
        case .hunter:   return 6
        }
    }

    /// Hunters steer toward the drawing tip instead of falling — World 5's mechanic.
    var hunts: Bool { self == .hunter }

    /// Cutters sever the line instead of ending the round. Every other type is a wall.
    var severs: Bool { self == .cutter }

    /// Fuses ignite the line rather than ending the round on contact. World 3's hazard —
    /// the first one you can beat rather than only dodge.
    var ignites: Bool { self == .fuse }

    /// Neither severing nor igniting hazards end the round on contact.
    var isLethal: Bool { !severs && !ignites }
}

struct LevelConfig: Codable, Identifiable {
    let id: Int

    /// "Gridlock" tells you what you are in for; "8" does not. Optional so older data
    /// still decodes.
    let name: String?

    var displayName: String { name ?? "Level \(id)" }
    let world: Int
    let timeLimit: TimeInterval
    let targetCoverage: Float        // e.g. 0.65 = 65% of grid cells
    let obstacleTypes: [ObstacleType]
    let spawnInterval: TimeInterval
    let maxObstacles: Int
    let gridSize: Int                // NxN for coverage calculation

    /// Shelters placed on the board. Optional so levels written before they existed
    /// still decode.
    let safeZones: [SafeZoneConfig]?

    /// Cosmetic flourish on the drawn line. Optional; absent means plain.
    let lineEffect: LineEffect?

    var effect: LineEffect { lineEffect ?? .plain }

    /// World 3's wind: a constant drift on the line, in points per recorded point.
    /// Optional; absent means still air.
    let windX: Float?
    let windY: Float?

    var wind: CGVector { CGVector(dx: CGFloat(windX ?? 0), dy: CGFloat(windY ?? 0)) }
    var hasWind: Bool { (windX ?? 0) != 0 || (windY ?? 0) != 0 }

    /// World 4's darkness: the board goes dark but for a torch around the drawing tip.
    /// Optional; absent means the lights are on.
    let dark: Bool?

    var isDark: Bool { dark ?? false }

    /// Bonus pips scattered on the board — route your line through one to eat it for points.
    /// Optional; absent means none.
    let collectibles: Int?

    var collectibleCount: Int { collectibles ?? 0 }

    /// Built in code rather than decoded — endless generates its boards per wave.
    init(id: Int, name: String?, world: Int, timeLimit: TimeInterval, targetCoverage: Float,
         obstacleTypes: [ObstacleType], spawnInterval: TimeInterval, maxObstacles: Int,
         gridSize: Int, safeZones: [SafeZoneConfig]? = nil, lineEffect: LineEffect? = nil,
         windX: Float? = nil, windY: Float? = nil, dark: Bool? = nil, collectibles: Int? = nil) {
        self.id = id
        self.name = name
        self.world = world
        self.timeLimit = timeLimit
        self.targetCoverage = targetCoverage
        self.obstacleTypes = obstacleTypes
        self.spawnInterval = spawnInterval
        self.maxObstacles = maxObstacles
        self.gridSize = gridSize
        self.safeZones = safeZones
        self.lineEffect = lineEffect
        self.windX = windX
        self.windY = windY
        self.dark = dark
        self.collectibles = collectibles
    }

    var zones: [SafeZoneConfig] { safeZones ?? [] }

    static func load() -> [LevelConfig] {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let levels = try? JSONDecoder().decode([LevelConfig].self, from: data)
        else {
            assertionFailure("levels.json missing or malformed")
            return []
        }
        return levels
    }

    /// Loaded once at launch — the level list never changes at runtime.
    static let all: [LevelConfig] = load()

    static func level(id: Int) -> LevelConfig? { all.first { $0.id == id } }
}
