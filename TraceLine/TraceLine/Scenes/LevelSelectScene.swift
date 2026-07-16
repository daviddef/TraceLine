import SpriteKit

final class LevelSelectScene: SKScene {

    private let theme: Theme
    private let columns = 4
    private let cellSize: CGFloat = 68
    private let spacing: CGFloat = 14

    init(theme: Theme, size: CGSize) {
        self.theme = theme
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    override func didMove(to view: SKView) {
        backgroundColor = theme.background

        let back = SKLabelNode(fontNamed: Fonts.display(for: theme))
        back.text = "‹"
        back.fontSize = 34
        back.fontColor = theme.hudTextColor
        back.horizontalAlignmentMode = .left
        back.position = CGPoint(x: -size.width / 2 + 24, y: size.height / 2 - 90)
        back.name = "back_button"
        addChild(back)

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "Choose Level"
        title.fontSize = 26
        title.fontColor = theme.hudTextColor
        title.position = CGPoint(x: 0, y: size.height / 2 - 92)
        addChild(title)

        let worldLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
        worldLabel.text = "World 1 — The Grid"
        worldLabel.fontSize = 13
        worldLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        worldLabel.position = CGPoint(x: 0, y: size.height / 2 - 130)
        addChild(worldLabel)

        addLevelGrid(topY: size.height / 2 - 190)
    }

    private func addLevelGrid(topY: CGFloat) {
        let levels = LevelConfig.all
        let rowWidth = CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing
        let startX = -rowWidth / 2 + cellSize / 2

        for (index, level) in levels.enumerated() {
            let col = index % columns
            let row = index / columns
            let position = CGPoint(x: startX + CGFloat(col) * (cellSize + spacing),
                                   y: topY - CGFloat(row) * (cellSize + spacing))
            addChild(levelCell(level: level, at: position))
        }
    }

    private func levelCell(level: LevelConfig, at position: CGPoint) -> SKNode {
        let unlocked = PlayerProgress.shared.isUnlocked(level.id)
        let stars = PlayerProgress.shared.stars(for: level.id)
        let name = unlocked ? "level_\(level.id)" : "locked"

        let container = SKNode()
        container.position = position

        let box = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize), cornerRadius: 14)
        box.fillColor = unlocked
            ? theme.hudAccentColor.withAlphaComponent(stars > 0 ? 0.22 : 0.10)
            : theme.hudTextColor.withAlphaComponent(0.05)
        box.strokeColor = unlocked
            ? theme.hudAccentColor.withAlphaComponent(0.6)
            : theme.hudTextColor.withAlphaComponent(0.1)
        box.lineWidth = 1.5
        box.name = name
        container.addChild(box)

        let label = SKLabelNode(fontNamed: Fonts.display(for: theme))
        label.text = unlocked ? "\(level.id)" : "🔒"
        label.fontSize = unlocked ? 24 : 18
        label.fontColor = unlocked ? theme.hudTextColor : theme.hudTextColor.withAlphaComponent(0.3)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: unlocked ? 6 : 0)
        label.name = name
        container.addChild(label)

        if unlocked {
            let starLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
            starLabel.text = String(repeating: "★", count: stars)
                + String(repeating: "☆", count: 3 - stars)
            starLabel.fontSize = 10
            starLabel.fontColor = stars > 0 ? SKColor(hex: "#facc15")
                                            : theme.hudTextColor.withAlphaComponent(0.25)
            starLabel.verticalAlignmentMode = .center
            starLabel.position = CGPoint(x: 0, y: -18)
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

        guard name.hasPrefix("level_"),
              let id = Int(name.dropFirst("level_".count)),
              let level = LevelConfig.level(id: id) else { return }

        Haptics.tap()
        let scene = GameScene(levelConfig: level, theme: theme, size: size)
        view?.presentScene(scene, transition: .fade(withDuration: 0.3))
    }
}
