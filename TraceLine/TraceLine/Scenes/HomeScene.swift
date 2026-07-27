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
        addChild(BackgroundNode(theme: theme, size: size))

        let top = size.height / 2

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "TraceLine"
        title.fontSize = 48
        title.fontColor = theme.lineColor
        title.position = CGPoint(x: 0, y: top - 130)
        addChild(title)

        let tagline = SKLabelNode(fontNamed: Fonts.body(for: theme))
        tagline.text = "DRAW. SURVIVE. DON'T LIFT."
        tagline.fontSize = 13
        tagline.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        tagline.position = CGPoint(x: 0, y: top - 168)
        addChild(tagline)

        // Settings gear, top-right.
        addCornerIcon("⚙︎", name: "settings_button", x: size.width / 2 - 34, y: top - 54)

        addHighScoreBar(y: top - 224)

        // Primary action: the campaign map.
        addChild(ButtonNode(title: "▶  Play", theme: theme, name: "play_button",
                            position: CGPoint(x: 0, y: 66),
                            size: CGSize(width: 264, height: 58)))

        // The three ways to play, as cards side by side.
        addModeCards(y: -70)

        // Themes, secondary, below the cards.
        addChild(ButtonNode(title: "🎨  Themes", theme: theme, name: "themes_button",
                            position: CGPoint(x: 0, y: -186), isPrimary: false,
                            size: CGSize(width: 264, height: 54)))
    }

    // MARK: - Top bar: high score + leaderboard

    private func addHighScoreBar(y: CGFloat) {
        let best = PlayerProgress.shared.globalHighScore

        let caption = SKLabelNode(fontNamed: Fonts.body(for: theme))
        caption.text = best > 0 ? "BEST" : "NO SCORE YET"
        caption.fontSize = 11
        caption.fontColor = theme.hudTextColor.withAlphaComponent(0.45)
        caption.verticalAlignmentMode = .center
        caption.position = CGPoint(x: 0, y: y + 20)
        addChild(caption)

        // Score + trophy, centred as a group. The trophy opens the leaderboard.
        let number = SKLabelNode(fontNamed: Fonts.display(for: theme))
        number.text = best > 0 ? best.formatted() : "—"
        number.fontSize = 34
        number.fontColor = theme.hudAccentColor
        number.verticalAlignmentMode = .center
        number.horizontalAlignmentMode = .center
        addChild(number)

        let trophy = SKLabelNode(fontNamed: Fonts.body(for: theme))
        trophy.text = "🏆"
        trophy.fontSize = 26
        trophy.verticalAlignmentMode = .center
        trophy.horizontalAlignmentMode = .center
        trophy.name = "leaderboard_button"

        // A generous invisible hit pad behind the trophy, so it is easy to tap.
        let pad = SKShapeNode(circleOfRadius: 24)
        pad.fillColor = theme.hudTextColor.withAlphaComponent(0.06)
        pad.strokeColor = .clear
        pad.name = "leaderboard_button"

        let gap: CGFloat = 22
        let numHalf = number.frame.width / 2
        number.position = CGPoint(x: -22, y: y)
        let trophyX = number.position.x + numHalf + gap
        trophy.position = CGPoint(x: trophyX, y: y)
        pad.position = trophy.position
        addChild(pad)
        addChild(trophy)
    }

    // MARK: - Mode cards

    private func addModeCards(y: CGFloat) {
        let margin: CGFloat = 22, gap: CGFloat = 12
        let cardW = (size.width - margin * 2 - gap * 2) / 3
        let cardSize = CGSize(width: cardW, height: 104)
        let step = cardW + gap

        let cont = continueLevel
        addChild(modeCard(icon: "▶▶", title: "Continue",
                          subtitle: cont.map { "Level \($0.id)" } ?? "Locked",
                          name: "continue_button", enabled: cont != nil,
                          size: cardSize, at: CGPoint(x: -step, y: y)))
        addChild(modeCard(icon: "✦", title: "Free Play", subtitle: "All unlocked",
                          name: "freeplay_button", enabled: true,
                          size: cardSize, at: CGPoint(x: 0, y: y)))
        addChild(modeCard(icon: "∞", title: "Endless", subtitle: "One run",
                          name: "endless_button", enabled: true,
                          size: cardSize, at: CGPoint(x: step, y: y)))
    }

    private func modeCard(icon: String, title: String, subtitle: String,
                          name: String, enabled: Bool,
                          size cardSize: CGSize, at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        let tag = enabled ? name : "locked"

        let card = SKShapeNode(rectOf: cardSize, cornerRadius: 16)
        card.fillColor = theme.hudTextColor.withAlphaComponent(0.06)
        card.strokeColor = theme.hudTextColor.withAlphaComponent(0.18)
        card.lineWidth = 1.5
        card.name = tag
        card.alpha = enabled ? 1 : 0.4
        container.addChild(card)

        let iconLabel = SKLabelNode(fontNamed: Fonts.display(for: theme))
        iconLabel.text = icon
        iconLabel.fontSize = 26
        iconLabel.fontColor = theme.lineColor
        iconLabel.verticalAlignmentMode = .center
        iconLabel.horizontalAlignmentMode = .center
        iconLabel.position = CGPoint(x: 0, y: 22)
        iconLabel.name = tag
        iconLabel.alpha = enabled ? 1 : 0.4
        container.addChild(iconLabel)

        let titleLabel = SKLabelNode(fontNamed: Fonts.display(for: theme))
        titleLabel.text = title
        titleLabel.fontSize = 15
        titleLabel.fontColor = theme.hudTextColor
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: -14)
        titleLabel.name = tag
        titleLabel.alpha = enabled ? 1 : 0.5
        container.addChild(titleLabel)

        let subLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
        subLabel.text = subtitle
        subLabel.fontSize = 10
        subLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        subLabel.verticalAlignmentMode = .center
        subLabel.horizontalAlignmentMode = .center
        subLabel.position = CGPoint(x: 0, y: -36)
        subLabel.name = tag
        container.addChild(subLabel)

        return container
    }

    private func addCornerIcon(_ glyph: String, name: String, x: CGFloat, y: CGFloat) {
        let icon = SKLabelNode(fontNamed: Fonts.body(for: theme))
        icon.text = glyph
        icon.fontSize = 26
        icon.fontColor = theme.hudTextColor.withAlphaComponent(0.55)
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: x, y: y)
        icon.name = name
        addChild(icon)
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
        case "freeplay_button":
            // Free for now — this is where a future purchase would gate. It opens the whole
            // game: every world, level and theme, no earning required.
            PlayerProgress.shared.freePlayEnabled = true
            view?.presentScene(LevelSelectScene(theme: theme, size: size, worldID: 1),
                               transition: .fade(withDuration: 0.3))
        case "endless_button":
            view?.presentScene(GameScene(levelConfig: Endless.config(forWave: 1),
                                         theme: theme, size: size, mode: .endless),
                               transition: .fade(withDuration: 0.3))
        case "themes_button":
            view?.presentScene(ThemeSelectScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
        case "settings_button":
            view?.presentScene(SettingsScene(theme: theme, size: size),
                               transition: .fade(withDuration: 0.3))
        case "leaderboard_button":
            Analytics.log(.leaderboardOpened)
            GameCenter.showLeaderboard(from: view?.window?.rootViewController)
        default:
            break
        }
    }
}
