import SpriteKit

final class GameOverScene: SKScene {

    private let reason: FailReason
    private let roundScore: RoundScore
    private let levelConfig: LevelConfig
    private let theme: Theme
    private let mode: GameMode
    private let wave: Int

    init(reason: FailReason, roundScore: RoundScore,
         levelConfig: LevelConfig, theme: Theme, size: CGSize,
         mode: GameMode = .levels, wave: Int = 1) {
        self.reason = reason
        self.roundScore = roundScore
        self.levelConfig = levelConfig
        self.theme = theme
        self.mode = mode
        self.wave = wave
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    override func didMove(to view: SKView) {
        backgroundColor = theme.background

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "💀 Game Over"
        title.fontSize = 34
        title.fontColor = theme.hudTextColor
        title.position = CGPoint(x: 0, y: 200)
        addChild(title)

        let reasonLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
        reasonLabel.text = reason.displayText
        reasonLabel.fontSize = 18
        reasonLabel.fontColor = SKColor(hex: "#ff2255")
        reasonLabel.position = CGPoint(x: 0, y: 150)
        addChild(reasonLabel)

        let survived = max(0, levelConfig.timeLimit - roundScore.timeRemaining)
        if mode == .endless {
            // A run is measured in waves survived, not in one board's coverage.
            let stats: [(String, String)] = [
                (roundScore.base.formatted(), "Score"),
                ("\(wave)", wave == 1 ? "Wave" : "Waves"),
                ("\(Int(survived))s", "Survived"),
            ]
            for (i, stat) in stats.enumerated() {
                addChild(statNode(value: stat.0, caption: stat.1,
                                  at: CGPoint(x: CGFloat(i - 1) * 110, y: 40)))
            }
            addChild(ButtonNode(title: "↺  Run Again", theme: theme, name: "endless_button",
                                position: CGPoint(x: 0, y: -80)))
            addChild(ButtonNode(title: "‹  Home", theme: theme, name: "home_button",
                                position: CGPoint(x: 0, y: -150), isPrimary: false))
            return
        }
        // Only the distance score is shown here. `total` folds in the speed and
        // clean-run bonuses, which are rewards for clearing a level — paying them out
        // on a failed round would report a bigger number than the HUD just showed.
        let stats: [(String, String)] = [
            (roundScore.base.formatted(), "Score"),
            ("\(Int(roundScore.coveragePct * 100))%", "Coverage"),
            ("\(Int(survived))s", "Survived"),
        ]
        for (i, stat) in stats.enumerated() {
            let x = CGFloat(i - 1) * 110
            addChild(statNode(value: stat.0, caption: stat.1, at: CGPoint(x: x, y: 40)))
        }

        addChild(ButtonNode(title: "↺  Try Again", theme: theme, name: "retry_button",
                            position: CGPoint(x: 0, y: -80)))
        addChild(ButtonNode(title: "‹  Level Select", theme: theme, name: "levels_button",
                            position: CGPoint(x: 0, y: -150), isPrimary: false))
    }

    private func statNode(value: String, caption: String, at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position

        let valueLabel = SKLabelNode(fontNamed: Fonts.display(for: theme))
        valueLabel.text = value
        valueLabel.fontSize = 26
        valueLabel.fontColor = theme.hudAccentColor
        valueLabel.horizontalAlignmentMode = .center
        container.addChild(valueLabel)

        let captionLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
        captionLabel.text = caption
        captionLabel.fontSize = 12
        captionLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        captionLabel.horizontalAlignmentMode = .center
        captionLabel.position = CGPoint(x: 0, y: -22)
        container.addChild(captionLabel)

        return container
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self) else { return }
        guard let name = atPoint(pos).name else { return }
        Haptics.tap()

        switch name {
        case "endless_button":
            let scene = GameScene(levelConfig: Endless.config(forWave: 1),
                                  theme: theme, size: size, mode: .endless)
            view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        case "home_button":
            view?.presentScene(HomeScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
        case "retry_button":
            let scene = GameScene(levelConfig: levelConfig, theme: theme, size: size)
            view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        case "levels_button":
            let scene = LevelSelectScene(theme: theme, size: size, worldID: levelConfig.world)
            view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        default:
            break
        }
    }
}
