import SpriteKit

enum ThemeKey: String, CaseIterable, Codable {
    case neon, clay, retro, watercolour
}

struct Theme {
    let key: ThemeKey
    let displayName: String

    // Colours
    let background: SKColor
    let lineColor: SKColor
    let lineShadowColor: SKColor     // glow colour (neon) or shadow (clay)
    let obstacleColors: [SKColor]    // index matches ObstacleType.themeIndex
    let hudTextColor: SKColor
    let hudAccentColor: SKColor
    let gridColor: SKColor

    // Line style
    let lineWidth: CGFloat
    let lineGlowWidth: CGFloat       // 0 for non-neon themes
    let lineAlpha: CGFloat
    let lineCap: CGLineCap
    let pixelated: Bool              // retro only

    // Obstacle style
    let obstacleGlow: Bool           // neon / retro only

    static let neon = Theme(
        key: .neon,
        displayName: "Neon",
        background: SKColor(hex: "#0d0d1a"),
        lineColor: SKColor(hex: "#6366f1"),
        lineShadowColor: SKColor(hex: "#6366f1").withAlphaComponent(0.8),
        obstacleColors: [
            SKColor(hex: "#ec4899"),  // Blocker
            SKColor(hex: "#facc15"),  // Mover
            SKColor(hex: "#a78bfa"),  // Magnetic
            SKColor(hex: "#f97316"),  // Shrinker
            SKColor(hex: "#22d3ee"),  // Cutter
        ],
        hudTextColor: .white,
        hudAccentColor: SKColor(hex: "#6366f1"),
        gridColor: SKColor.white.withAlphaComponent(0.04),
        lineWidth: 4,
        lineGlowWidth: 12,
        lineAlpha: 1.0,
        lineCap: .round,
        pixelated: false,
        obstacleGlow: true
    )

    static let clay = Theme(
        key: .clay,
        displayName: "Clay",
        background: SKColor(hex: "#fef9f0"),
        lineColor: SKColor(hex: "#f97316"),
        lineShadowColor: SKColor(hex: "#c2410c").withAlphaComponent(0.3),
        obstacleColors: [
            SKColor(hex: "#84cc16"),
            SKColor(hex: "#06b6d4"),
            SKColor(hex: "#a78bfa"),
            SKColor(hex: "#ec4899"),
            SKColor(hex: "#ef4444"),  // Cutter
        ],
        hudTextColor: SKColor(hex: "#1c1917"),
        hudAccentColor: SKColor(hex: "#f97316"),
        gridColor: SKColor.black.withAlphaComponent(0.05),
        lineWidth: 6,
        lineGlowWidth: 0,
        lineAlpha: 1.0,
        lineCap: .round,
        pixelated: false,
        obstacleGlow: false
    )

    static let retro = Theme(
        key: .retro,
        displayName: "Retro",
        background: SKColor(hex: "#020f02"),
        lineColor: SKColor(hex: "#22c55e"),
        lineShadowColor: SKColor(hex: "#22c55e").withAlphaComponent(0.9),
        obstacleColors: [
            SKColor(hex: "#facc15"),
            SKColor(hex: "#f97316"),
            SKColor(hex: "#60a5fa"),
            SKColor(hex: "#ec4899"),
            SKColor(hex: "#38bdf8"),  // Cutter
        ],
        hudTextColor: SKColor(hex: "#22c55e"),
        hudAccentColor: SKColor(hex: "#22c55e"),
        gridColor: SKColor(hex: "#22c55e").withAlphaComponent(0.07),
        lineWidth: 4,
        lineGlowWidth: 14,
        lineAlpha: 1.0,
        lineCap: .round,
        pixelated: true,
        obstacleGlow: true
    )

    static let watercolour = Theme(
        key: .watercolour,
        displayName: "Watercolour",
        background: SKColor(hex: "#f0f9ff"),
        lineColor: SKColor(hex: "#06b6d4"),
        lineShadowColor: SKColor(hex: "#0891b2").withAlphaComponent(0.25),
        obstacleColors: [
            SKColor(hex: "#a78bfa"),
            SKColor(hex: "#f97316"),
            SKColor(hex: "#ec4899"),
            SKColor(hex: "#84cc16"),
            SKColor(hex: "#f43f5e"),  // Cutter
        ],
        hudTextColor: SKColor(hex: "#0c4a6e"),
        hudAccentColor: SKColor(hex: "#06b6d4"),
        gridColor: SKColor.black.withAlphaComponent(0.04),
        lineWidth: 5,
        lineGlowWidth: 0,
        lineAlpha: 0.85,
        lineCap: .round,
        pixelated: false,
        obstacleGlow: false
    )

    static func theme(for key: ThemeKey) -> Theme {
        switch key {
        case .neon:        return .neon
        case .clay:        return .clay
        case .retro:       return .retro
        case .watercolour: return .watercolour
        }
    }

    /// The theme the player has selected, from persisted progress.
    static var active: Theme { theme(for: PlayerProgress.shared.activeThemeKey()) }
}

// MARK: - SKColor hex initialiser
extension SKColor {
    convenience init(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >>  8) & 0xFF) / 255
        let b = CGFloat((rgb      ) & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
