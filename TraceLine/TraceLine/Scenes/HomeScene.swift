import SpriteKit

final class HomeScene: SKScene {

    private let theme: Theme

    init(theme: Theme, size: CGSize) {
        self.theme = theme
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    /// The furthest level the player has unlocked — where "Continue" resumes.
    private var continueLevel: LevelConfig? {
        let unlocked = LevelConfig.all.filter { PlayerProgress.shared.isUnlocked($0.id) }
        guard let furthest = unlocked.last, furthest.id > 1 else { return nil }
        return furthest
    }

    override func didMove(to view: SKView) {
        backgroundColor = theme.background
        addDecorativeLine()

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "TraceLine"
        title.fontSize = 52
        title.fontColor = theme.lineColor
        title.position = CGPoint(x: 0, y: 190)
        addChild(title)

        let tagline = SKLabelNode(fontNamed: Fonts.body(for: theme))
        tagline.text = "DRAW. SURVIVE. DON'T LIFT."
        tagline.fontSize = 13
        tagline.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        tagline.position = CGPoint(x: 0, y: 155)
        addChild(tagline)

        addChild(ButtonNode(title: "▶  Play", theme: theme, name: "play_button",
                            position: CGPoint(x: 0, y: -40)))

        if let continueLevel {
            addChild(ButtonNode(title: "Continue — Level \(continueLevel.id)",
                                theme: theme, name: "continue_button",
                                position: CGPoint(x: 0, y: -108), isPrimary: false))
        }

        addChild(ButtonNode(title: "🎨  Themes", theme: theme, name: "themes_button",
                            position: CGPoint(x: 0, y: continueLevel == nil ? -108 : -176),
                            isPrimary: false))
        addChild(ButtonNode(title: "🏆  Leaderboard", theme: theme, name: "leaderboard_button",
                            position: CGPoint(x: 0, y: continueLevel == nil ? -176 : -244),
                            isPrimary: false))

        let best = PlayerProgress.shared.globalHighScore
        if best > 0 {
            let bestLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
            bestLabel.text = "Best \(best.formatted())"
            bestLabel.fontSize = 12
            bestLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.4)
            bestLabel.position = CGPoint(x: 0, y: -size.height / 2 + 50)
            addChild(bestLabel)
        }
    }

    /// A looping trace of the game's own mechanic behind the title.
    private func addDecorativeLine() {
        let path = CGMutablePath()
        let width = size.width - 80
        path.move(to: CGPoint(x: -width / 2, y: 60))
        var x = -width / 2
        var up = true
        while x < width / 2 {
            x += 26
            path.addLine(to: CGPoint(x: min(x, width / 2), y: up ? 92 : 40))
            up.toggle()
        }

        let line = SKShapeNode(path: path)
        line.strokeColor = theme.lineColor.withAlphaComponent(0.25)
        line.lineWidth = theme.lineWidth
        line.lineCap = .round
        line.lineJoin = .round
        line.fillColor = .clear
        addChild(line)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self) else { return }
        guard let name = atPoint(pos).name else { return }
        Haptics.tap()

        switch name {
        case "play_button":
            view?.presentScene(LevelSelectScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
        case "continue_button":
            guard let level = continueLevel else { return }
            view?.presentScene(GameScene(levelConfig: level, theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
        case "themes_button":
            view?.presentScene(ThemeSelectScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
        case "leaderboard_button":
            GameCenter.showLeaderboard(from: view?.window?.rootViewController)
        default:
            break
        }
    }
}
