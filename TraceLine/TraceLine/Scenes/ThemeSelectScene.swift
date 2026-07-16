import SpriteKit

final class ThemeSelectScene: SKScene {

    /// The theme the scene is currently drawn in. Selecting a theme rebuilds the
    /// scene in place, so the choice previews itself immediately.
    private var theme: Theme

    init(theme: Theme, size: CGSize) {
        self.theme = theme
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    override func didMove(to view: SKView) { rebuild() }

    private func rebuild() {
        removeAllChildren()
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
        title.text = "Choose Theme"
        title.fontSize = 26
        title.fontColor = theme.hudTextColor
        title.position = CGPoint(x: 0, y: size.height / 2 - 92)
        addChild(title)

        let active = PlayerProgress.shared.activeThemeKey()
        let cardW = size.width - 96
        var y: CGFloat = size.height / 2 - 200

        for key in ThemeKey.allCases {
            addChild(themeCard(for: Theme.theme(for: key),
                               isActive: key == active,
                               isUnlocked: PlayerProgress.shared.isThemeUnlocked(key),
                               size: CGSize(width: cardW, height: 78),
                               at: CGPoint(x: 0, y: y)))
            y -= 94
        }

        let hint = SKLabelNode(fontNamed: Fonts.body(for: theme))
        hint.text = "🏆 Unlock themes by completing worlds"
        hint.fontSize = 12
        hint.fontColor = theme.hudTextColor.withAlphaComponent(0.45)
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 60)
        addChild(hint)
    }

    private func themeCard(for cardTheme: Theme, isActive: Bool, isUnlocked: Bool,
                           size cardSize: CGSize, at position: CGPoint) -> SKNode {
        let name = isUnlocked ? "theme_\(cardTheme.key.rawValue)" : "locked"
        let container = SKNode()
        container.position = position

        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 16)
        card.fillColor = cardTheme.background
        card.strokeColor = isActive ? theme.hudAccentColor
                                    : theme.hudTextColor.withAlphaComponent(0.15)
        card.lineWidth = isActive ? 3 : 1.5
        card.alpha = isUnlocked ? 1 : 0.4
        card.name = name
        container.addChild(card)

        // A sample of the theme's own line, drawn on its own background.
        let sample = CGMutablePath()
        sample.move(to: CGPoint(x: -cardSize.width / 2 + 20, y: -14))
        sample.addLine(to: CGPoint(x: -cardSize.width / 2 + 44, y: 14))
        sample.addLine(to: CGPoint(x: -cardSize.width / 2 + 68, y: -14))
        sample.addLine(to: CGPoint(x: -cardSize.width / 2 + 92, y: 14))
        let sampleLine = SKShapeNode(path: sample)
        sampleLine.strokeColor = cardTheme.lineColor
        sampleLine.lineWidth = cardTheme.lineWidth
        sampleLine.lineCap = cardTheme.lineCap
        sampleLine.fillColor = .clear
        sampleLine.alpha = isUnlocked ? cardTheme.lineAlpha : 0.4
        sampleLine.name = name
        container.addChild(sampleLine)

        let dot = SKShapeNode(circleOfRadius: 7)
        dot.fillColor = cardTheme.obstacleColors[0]
        dot.strokeColor = .clear
        dot.position = CGPoint(x: -cardSize.width / 2 + 112, y: 0)
        dot.alpha = isUnlocked ? 1 : 0.4
        dot.name = name
        container.addChild(dot)

        let nameLabel = SKLabelNode(fontNamed: Fonts.display(for: cardTheme))
        nameLabel.text = cardTheme.displayName
        nameLabel.fontSize = 18
        nameLabel.fontColor = cardTheme.hudTextColor
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: -cardSize.width / 2 + 136, y: 0)
        nameLabel.alpha = isUnlocked ? 1 : 0.4
        nameLabel.name = name
        container.addChild(nameLabel)

        let status = SKLabelNode(fontNamed: Fonts.display(for: theme))
        status.text = isUnlocked ? (isActive ? "✓" : "") : "🔒"
        status.fontSize = 20
        status.fontColor = cardTheme.hudAccentColor
        status.horizontalAlignmentMode = .right
        status.verticalAlignmentMode = .center
        status.position = CGPoint(x: cardSize.width / 2 - 20, y: 0)
        status.name = name
        container.addChild(status)

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

        guard name.hasPrefix("theme_"),
              let key = ThemeKey(rawValue: String(name.dropFirst("theme_".count))),
              PlayerProgress.shared.isThemeUnlocked(key) else { return }

        Haptics.tap()
        PlayerProgress.shared.setTheme(key)
        Analytics.log(.themeSelected(key))
        theme = Theme.theme(for: key)
        rebuild()
    }
}
