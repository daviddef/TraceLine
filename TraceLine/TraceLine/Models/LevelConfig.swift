import Foundation

enum ObstacleType: String, Codable, CaseIterable {
    case blocker, mover, magnetic, shrinker, cutter

    var themeIndex: Int {
        switch self {
        case .blocker:  return 0
        case .mover:    return 1
        case .magnetic: return 2
        case .shrinker: return 3
        case .cutter:   return 4
        }
    }

    /// Cutters sever the line instead of ending the round. Every other type is a wall.
    var severs: Bool { self == .cutter }
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

    /// Built in code rather than decoded — endless generates its boards per wave.
    init(id: Int, name: String?, world: Int, timeLimit: TimeInterval, targetCoverage: Float,
         obstacleTypes: [ObstacleType], spawnInterval: TimeInterval, maxObstacles: Int,
         gridSize: Int, safeZones: [SafeZoneConfig]? = nil, lineEffect: LineEffect? = nil) {
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
