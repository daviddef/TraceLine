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
        addChild(BackgroundNode(theme: theme, size: size))

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
        hint.text = "🏆 Each theme is earned — see what each one needs"
        hint.fontSize = 12
        hint.fontColor = theme.hudTextColor.withAlphaComponent(0.45)
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 60)
        addChild(hint)
    }

    private func themeCard(for cardTheme: Theme, isActive: Bool, isUnlocked: Bool,
                           size cardSize: CGSize, at position: CGPoint) -> SKNode {
        // Locked cards must stay clearly visible — a dark locked theme dimmed to nothing
        // (as retro was) hides what the player is working toward. So locked cards get a
        // neutral, fully-opaque treatment drawn in the *current* theme's colours, and hide
        // the real palette behind a lock until it is earned. Only unlocked cards preview
        // their own colours.
        let name = isUnlocked ? "theme_\(cardTheme.key.rawValue)" : "locked"
        let leftText = -cardSize.width / 2 + 24
        let container = SKNode()
        container.position = position

        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 16)
        card.fillColor = isUnlocked ? cardTheme.background
                                    : theme.hudTextColor.withAlphaComponent(0.07)
        card.strokeColor = isActive ? theme.hudAccentColor
                                    : theme.hudTextColor.withAlphaComponent(0.18)
        card.lineWidth = isActive ? 3 : 1.5
        card.name = name
        container.addChild(card)

        let nameLabel = SKLabelNode(fontNamed: Fonts.display(for: isUnlocked ? cardTheme : theme))
        nameLabel.text = cardTheme.displayName
        nameLabel.fontSize = 18
        nameLabel.fontColor = isUnlocked ? cardTheme.hudTextColor : theme.hudTextColor
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.name = name

        if isUnlocked {
            // Preview the theme's own line and hazard colour on its own background.
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
            sampleLine.alpha = cardTheme.lineAlpha
            sampleLine.name = name
            container.addChild(sampleLine)

            let dot = SKShapeNode(circleOfRadius: 7)
            dot.fillColor = cardTheme.obstacleColors[0]
            dot.strokeColor = .clear
            dot.position = CGPoint(x: -cardSize.width / 2 + 112, y: 0)
            dot.name = name
            container.addChild(dot)

            nameLabel.position = CGPoint(x: -cardSize.width / 2 + 136, y: 0)
            container.addChild(nameLabel)

            let status = SKLabelNode(fontNamed: Fonts.display(for: theme))
            status.text = isActive ? "✓" : ""
            status.fontSize = 20
            status.fontColor = cardTheme.hudAccentColor
            status.horizontalAlignmentMode = .right
            status.verticalAlignmentMode = .center
            status.position = CGPoint(x: cardSize.width / 2 - 20, y: 0)
            status.name = name
            container.addChild(status)
        } else {
            // Locked: a lock where the preview would be, the name, and what it costs.
            let lock = SKLabelNode(fontNamed: Fonts.body(for: theme))
            lock.text = "🔒"
            lock.fontSize = 22
            lock.verticalAlignmentMode = .center
            lock.horizontalAlignmentMode = .center
            lock.position = CGPoint(x: -cardSize.width / 2 + 48, y: 0)
            lock.name = name
            container.addChild(lock)

            nameLabel.position = CGPoint(x: leftText + 80, y: 11)
            container.addChild(nameLabel)

            let need = SKLabelNode(fontNamed: Fonts.body(for: theme))
            need.text = cardTheme.requirement.describedShort
            need.fontSize = 12
            need.fontColor = theme.hudAccentColor.withAlphaComponent(0.9)
            need.horizontalAlignmentMode = .left
            need.verticalAlignmentMode = .center
            need.position = CGPoint(x: leftText + 80, y: -12)
            need.name = name
            container.addChild(need)
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
