import SpriteKit

final class WinScene: SKScene {

    private let roundScore: RoundScore
    private let levelConfig: LevelConfig
    private let theme: Theme

    init(roundScore: RoundScore, levelConfig: LevelConfig, theme: Theme, size: CGSize) {
        self.roundScore = roundScore
        self.levelConfig = levelConfig
        self.theme = theme
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    private var nextLevel: LevelConfig? { LevelConfig.level(id: levelConfig.id + 1) }

    override func didMove(to view: SKView) {
        backgroundColor = theme.background
        addChild(BackgroundNode(theme: theme, size: size))
        if roundScore.starsEarned > 0 { celebrate() }

        addStars()

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "Level Clear!"
        title.fontSize = 34
        title.fontColor = theme.hudTextColor
        title.position = CGPoint(x: 0, y: 170)
        addChild(title)

        let subtitle = SKLabelNode(fontNamed: Fonts.body(for: theme))
        subtitle.text = "LEVEL \(levelConfig.id) · WORLD \(levelConfig.world)"
        subtitle.fontSize = 12
        subtitle.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        subtitle.position = CGPoint(x: 0, y: 145)
        addChild(subtitle)

        addBreakdown()

        let hasNext = nextLevel != nil
        addChild(ButtonNode(title: hasNext ? "Next Level  ›" : "World Complete!",
                            theme: theme,
                            name: hasNext ? "next_button" : "levels_button",
                            position: CGPoint(x: 0, y: -140)))
        addChild(ButtonNode(title: "‹  Level Select", theme: theme, name: "levels_button",
                            position: CGPoint(x: 0, y: -210), isPrimary: false))
    }

    /// Stars pop in one at a time, each earned one landing with a bounce and a sparkle.
    private func addStars() {
        for i in 0..<3 {
            let star = SKLabelNode(fontNamed: Fonts.display(for: theme))
            let earned = i < roundScore.starsEarned
            star.text = "★"
            star.fontSize = 44
            star.fontColor = earned ? SKColor(hex: "#facc15")
                                    : theme.hudTextColor.withAlphaComponent(0.15)
            let at = CGPoint(x: CGFloat(i - 1) * 56, y: 240)
            star.position = at
            star.setScale(0)
            addChild(star)

            let land = SKAction.run { [weak self] in
                guard earned else { return }
                Haptics.tap()
                self?.sparkle(at: at)
            }
            star.run(.sequence([
                .wait(forDuration: 0.25 + Double(i) * 0.28),
                .group([.scale(to: 1.35, duration: 0.16), .fadeIn(withDuration: 0.16)]),
                land,
                .scale(to: 0.92, duration: 0.08),
                .scale(to: 1.0, duration: 0.08),
            ]))
        }
    }

    /// A short burst of sparks thrown from an earned star.
    private func sparkle(at point: CGPoint) {
        let e = SKEmitterNode()
        e.particleTexture = LineNode.softDot
        e.numParticlesToEmit = 16
        e.particleBirthRate = 1200
        e.particleLifetime = 0.5
        e.particleLifetimeRange = 0.2
        e.position = point
        e.particleSize = CGSize(width: 8, height: 8)
        e.particleScaleSpeed = -1.4
        e.particleAlphaSpeed = -2.0
        e.particleSpeed = 150
        e.particleSpeedRange = 70
        e.emissionAngleRange = .pi * 2
        e.particleColor = SKColor(hex: "#facc15")
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        e.zPosition = 10
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    /// Confetti in the theme's own hazard palette rains from the top — a finite burst
    /// scaled to how many stars were earned, so a three-star clear feels like more.
    private func celebrate() {
        let intensity = CGFloat(roundScore.starsEarned) / 3
        let colours = theme.obstacleColors
        for (index, colour) in colours.prefix(6).enumerated() {
            let e = SKEmitterNode()
            e.particleTexture = Self.confettiTexture
            e.numParticlesToEmit = Int(26 * intensity) + 6
            e.particleBirthRate = 60
            e.particleLifetime = 3.0
            e.particleLifetimeRange = 0.8
            e.position = CGPoint(x: 0, y: size.height / 2 + 20)
            e.particlePositionRange = CGVector(dx: size.width, dy: 0)
            e.emissionAngle = -.pi / 2
            e.emissionAngleRange = 0.6
            e.particleSpeed = 170
            e.particleSpeedRange = 70
            e.yAcceleration = -260
            e.particleSize = CGSize(width: 8, height: 12)
            e.particleScaleRange = 0.4
            e.particleRotationRange = .pi
            e.particleRotationSpeed = index.isMultiple(of: 2) ? 4 : -4
            e.particleAlphaSpeed = -0.3
            e.particleColor = colour
            e.particleColorBlendFactor = 1
            e.zPosition = 6
            addChild(e)
            e.run(.sequence([.wait(forDuration: 5), .removeFromParent()]))
        }
    }

    /// A small confetti rectangle, built once in code.
    private static let confettiTexture: SKTexture = {
        let size = CGSize(width: 8, height: 12)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }()

    private func addBreakdown() {
        let rows: [(String, String)] = [
            ("Base Score", "+\(roundScore.base.formatted())"),
            ("Coverage (\(Int(roundScore.coveragePct * 100))%)", "+\(roundScore.cover.formatted())"),
            ("Speed Bonus", roundScore.speed > 0 ? "+\(roundScore.speed.formatted())" : "—"),
            ("Clean Run", roundScore.clean > 0 ? "+\(roundScore.clean.formatted())" : "—"),
        ]

        let width: CGFloat = 260
        var y: CGFloat = 90

        for (label, value) in rows {
            addChild(row(label: label, value: value, y: y, width: width, emphasised: false))
            y -= 34
        }

        let divider = SKShapeNode(rectOf: CGSize(width: width, height: 1))
        divider.fillColor = theme.hudTextColor.withAlphaComponent(0.15)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: y + 14)
        addChild(divider)

        addChild(row(label: "Total", value: roundScore.total.formatted(),
                     y: y - 10, width: width, emphasised: true))
    }

    private func row(label: String, value: String, y: CGFloat,
                     width: CGFloat, emphasised: Bool) -> SKNode {
        let container = SKNode()

        let l = SKLabelNode(fontNamed: emphasised ? Fonts.display(for: theme) : Fonts.body(for: theme))
        l.text = label
        l.fontSize = emphasised ? 18 : 15
        l.fontColor = emphasised ? theme.hudTextColor : theme.hudTextColor.withAlphaComponent(0.6)
        l.horizontalAlignmentMode = .left
        l.verticalAlignmentMode = .center
        l.position = CGPoint(x: -width / 2, y: y)
        container.addChild(l)

        let v = SKLabelNode(fontNamed: Fonts.display(for: theme))
        v.text = value
        v.fontSize = emphasised ? 22 : 15
        v.fontColor = emphasised ? theme.hudAccentColor : theme.hudTextColor
        v.horizontalAlignmentMode = .right
        v.verticalAlignmentMode = .center
        v.position = CGPoint(x: width / 2, y: y)
        container.addChild(v)

        return container
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self) else { return }
        guard let name = atPoint(pos).name else { return }
        Haptics.tap()

        switch name {
        case "next_button":
            guard let next = nextLevel else { return }
            let scene = GameScene(levelConfig: next, theme: theme, size: size)
            view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        case "levels_button":
            let scene = LevelSelectScene(theme: theme, size: size, worldID: levelConfig.world)
            view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        default:
            break
        }
    }
}
