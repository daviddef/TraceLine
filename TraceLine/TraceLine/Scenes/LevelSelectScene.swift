import SpriteKit

/// The world map. Levels sit on a single continuous trail that the player's own progress
/// draws: solid behind them, faint ahead. A grid of identical numbered boxes says nothing
/// about where you are or what is coming — this says both, in the game's own language.
///
/// The trail is a legal TraceLine. It never crosses itself, because the map should obey
/// the rules it is a map of.
final class LevelSelectScene: SKScene {

    private let theme: Theme
    /// Which world's trail is on screen. One world, one trail — twenty nodes on a single
    /// wave would be a list again.
    private var worldID: Int
    private let nodeRadius: CGFloat = 24
    /// Fitted to the screen rather than fixed, so the trail fills the board on a big
    /// phone instead of stopping two-thirds down.
    private var spacing: CGFloat {
        let usable = size.height - 210 - 100
        return min(78, usable / CGFloat(max(1, levels.count - 1)))
    }
    private var amplitude: CGFloat { min(86, size.width * 0.2) }

    init(theme: Theme, size: CGSize, worldID: Int? = nil) {
        self.theme = theme
        self.worldID = worldID ?? PlayerProgress.shared.furthestUnlockedWorld
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    private var world: WorldConfig? { WorldConfig.world(id: worldID) }
    private var levels: [LevelConfig] { world?.levels ?? [] }

    /// How many levels are cleared — where the drawn part of the trail ends.
    private var clearedCount: Int {
        levels.filter { PlayerProgress.shared.stars(for: $0.id) >= 1 }.count
    }

    private var topY: CGFloat { size.height / 2 - 210 }

    /// A gentle wave with a deterministic wobble, so the trail looks hand-placed but
    /// never moves between launches — a map that rearranges itself under the player's
    /// thumb is disorienting rather than characterful.
    private func position(forIndex i: Int) -> CGPoint {
        let t = CGFloat(i)
        let wobble = CGFloat(sin(Double(i) * 12.9898) * 43758.5453)
        let jitter = (wobble - wobble.rounded(.down)) - 0.5      // −0.5 ..< 0.5, stable
        return CGPoint(x: sin(t * 0.82) * amplitude + jitter * 26,
                       y: topY - t * spacing)
    }

    override func didMove(to view: SKView) { rebuild() }

    private func rebuild() {
        removeAllChildren()
        backgroundColor = theme.background
        addHeader()
        addTrail()
        for (i, level) in levels.enumerated() {
            addChild(levelNode(level: level, at: position(forIndex: i)))
        }
    }

    private func addHeader() {
        let back = SKLabelNode(fontNamed: Fonts.display(for: theme))
        back.text = "‹"
        back.fontSize = 34
        back.fontColor = theme.hudTextColor
        back.horizontalAlignmentMode = .left
        back.position = CGPoint(x: -size.width / 2 + 24, y: size.height / 2 - 90)
        back.name = "back_button"
        addChild(back)

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = world?.displayTitle ?? "World \(worldID)"
        title.fontSize = 24
        title.fontColor = theme.hudTextColor
        title.position = CGPoint(x: 0, y: size.height / 2 - 92)
        addChild(title)

        let stars = levels.reduce(0) { $0 + PlayerProgress.shared.stars(for: $1.id) }
        let progress = SKLabelNode(fontNamed: Fonts.body(for: theme))
        progress.text = "\(clearedCount) of \(levels.count) cleared   ·   ★ \(stars)/\(levels.count * 3)"
        progress.fontSize = 13
        progress.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        progress.position = CGPoint(x: 0, y: size.height / 2 - 128)
        addChild(progress)

        // Worlds you have not opened are still worth seeing — the point of a locked door
        // is knowing it is there.
        addWorldArrow(direction: -1, enabled: WorldConfig.world(id: worldID - 1) != nil)
        addWorldArrow(direction: 1, enabled: WorldConfig.world(id: worldID + 1) != nil)
    }

    private func addWorldArrow(direction: Int, enabled: Bool) {
        guard enabled else { return }
        let arrow = SKLabelNode(fontNamed: Fonts.display(for: theme))
        arrow.text = direction < 0 ? "‹" : "›"
        arrow.fontSize = 28
        arrow.fontColor = theme.hudTextColor.withAlphaComponent(0.55)
        arrow.verticalAlignmentMode = .center
        // Inboard, beside the progress line: out at the edge it sat directly under the
        // back button and read as a second one.
        arrow.position = CGPoint(x: CGFloat(direction) * (size.width / 2 - 96),
                                 y: size.height / 2 - 128)
        arrow.name = direction < 0 ? "world_prev" : "world_next"
        addChild(arrow)
    }

    /// One continuous line through every level: drawn where the player has been, faint
    /// where they have not. This is the progression — the map is a line they are still
    /// drawing.
    private func addTrail() {
        let points = (0..<levels.count).map { position(forIndex: $0) }
        guard points.count >= 2 else { return }

        // The trail behind the player.
        let drawnTo = max(0, clearedCount - 1)
        if drawnTo >= 1 {
            let path = CGMutablePath()
            path.move(to: points[0])
            for i in 1...drawnTo { path.addLine(to: points[i]) }
            let drawn = SKShapeNode(path: path)
            drawn.strokeColor = theme.lineColor
            drawn.lineWidth = theme.lineWidth
            drawn.lineCap = .round
            drawn.lineJoin = .round
            drawn.fillColor = .clear
            drawn.zPosition = 1
            addChild(drawn)

            if theme.lineGlowWidth > 0 {
                let glow = SKShapeNode(path: path)
                glow.strokeColor = theme.lineShadowColor
                glow.lineWidth = theme.lineWidth + theme.lineGlowWidth
                glow.lineCap = .round
                glow.lineJoin = .round
                glow.fillColor = .clear
                glow.alpha = 0.35
                glow.zPosition = 0
                addChild(glow)
            }
        }

        // The trail ahead of them.
        if drawnTo < points.count - 1 {
            let path = CGMutablePath()
            path.move(to: points[drawnTo])
            for i in (drawnTo + 1)..<points.count { path.addLine(to: points[i]) }
            let ahead = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [6, 8]))
            ahead.strokeColor = theme.hudTextColor.withAlphaComponent(0.22)
            ahead.lineWidth = 2
            ahead.fillColor = .clear
            ahead.zPosition = 1
            addChild(ahead)
        }

        // The drawing tip — the same accent the app icon uses for the live end of a line.
        // It sits a little way along the trail toward the next level rather than on the
        // last cleared node, where it would cover that node's number, and reads better
        // there anyway: the line is heading somewhere.
        let from = points[min(drawnTo, points.count - 1)]
        let toward = points[min(drawnTo + 1, points.count - 1)]
        let tip = SKShapeNode(circleOfRadius: 5)
        tip.fillColor = theme.obstacleColors[0]
        tip.strokeColor = .clear
        tip.position = CGPoint(x: from.x + (toward.x - from.x) * 0.3,
                               y: from.y + (toward.y - from.y) * 0.3)
        tip.zPosition = 1.5     // under the level nodes, so it never hides a number
        tip.run(.repeatForever(.sequence([
            .scale(to: 1.5, duration: 0.7), .scale(to: 1.0, duration: 0.7),
        ])))
        addChild(tip)
    }

    private func levelNode(level: LevelConfig, at position: CGPoint) -> SKNode {
        let unlocked = PlayerProgress.shared.isUnlocked(level.id)
            && PlayerProgress.shared.isWorldUnlocked(level.world)
        let stars = PlayerProgress.shared.stars(for: level.id)
        let isNext = unlocked && stars == 0
        let name = unlocked ? "level_\(level.id)" : "locked"

        let container = SKNode()
        container.position = position
        container.zPosition = 2

        let disc = SKShapeNode(circleOfRadius: nodeRadius)
        disc.fillColor = unlocked ? theme.background : theme.hudTextColor.withAlphaComponent(0.06)
        disc.strokeColor = unlocked ? theme.lineColor : theme.hudTextColor.withAlphaComponent(0.18)
        disc.lineWidth = isNext ? 3.5 : 2
        disc.name = name
        container.addChild(disc)

        if isNext {
            // Where you are going next, without a word of UI.
            disc.run(.repeatForever(.sequence([
                .scale(to: 1.08, duration: 0.8), .scale(to: 1.0, duration: 0.8),
            ])))
        }

        let label = SKLabelNode(fontNamed: Fonts.display(for: theme))
        label.text = unlocked ? "\(level.id)" : "🔒"
        label.fontSize = unlocked ? 20 : 15
        label.fontColor = unlocked ? theme.hudTextColor : theme.hudTextColor.withAlphaComponent(0.35)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        container.addChild(label)

        // Name and stars sit outboard, away from the trail.
        let onLeft = position.x > 0
        let textX = onLeft ? -(nodeRadius + 12) : (nodeRadius + 12)
        let alignment: SKLabelHorizontalAlignmentMode = onLeft ? .right : .left

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = level.displayName   // names are a preview of what is coming, not a secret
        title.fontSize = 14
        title.fontColor = unlocked ? theme.hudTextColor.withAlphaComponent(0.85)
                                   : theme.hudTextColor.withAlphaComponent(0.3)
        title.horizontalAlignmentMode = alignment
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: textX, y: 7)
        title.name = name
        container.addChild(title)

        if unlocked {
            let starLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
            starLabel.text = String(repeating: "★", count: stars) + String(repeating: "☆", count: 3 - stars)
            starLabel.fontSize = 10
            starLabel.fontColor = stars > 0 ? SKColor(hex: "#facc15")
                                            : theme.hudTextColor.withAlphaComponent(0.25)
            starLabel.horizontalAlignmentMode = alignment
            starLabel.verticalAlignmentMode = .center
            starLabel.position = CGPoint(x: textX, y: -8)
            starLabel.name = name
            container.addChild(starLabel)
        }

        return container
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self) else { return }
        guard let name = atPoint(pos).name else { return }

        if name == "back_button" {
            Haptics.tap()
            view?.presentScene(HomeScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
            return
        }

        if name == "world_prev" || name == "world_next" {
            let next = worldID + (name == "world_next" ? 1 : -1)
            guard WorldConfig.world(id: next) != nil else { return }
            Haptics.tap()
            worldID = next
            rebuild()
            return
        }

        guard name.hasPrefix("level_"),
              let id = Int(name.dropFirst("level_".count)),
              let level = LevelConfig.level(id: id) else { return }

        Haptics.tap()
        view?.presentScene(GameScene(levelConfig: level, theme: theme, size: size),
                           transition: .fade(withDuration: 0.3))
    }
}
