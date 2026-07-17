import Foundation

/// A world is a chapter: its own name, its own trail, and its own idea. Until now the
/// `world` field on a level was decoration — printed on the win screen and nowhere else.
struct WorldConfig: Codable, Identifiable {
    let id: Int
    let name: String
    let subtitle: String

    var displayTitle: String { "World \(id) — \(name)" }

    /// The levels in this world, in order.
    var levels: [LevelConfig] { LevelConfig.all.filter { $0.world == id } }

    /// Clearing this is what opens the next world.
    var finalLevelID: Int? { levels.last?.id }

    static func load() -> [WorldConfig] {
        guard let url = Bundle.main.url(forResource: "worlds", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let worlds = try? JSONDecoder().decode([WorldConfig].self, from: data)
        else {
            assertionFailure("worlds.json missing or malformed")
            return []
        }
        return worlds.sorted { $0.id < $1.id }
    }

    static let all: [WorldConfig] = load()

    static func world(id: Int) -> WorldConfig? { all.first { $0.id == id } }
}
