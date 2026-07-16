import SpriteKit

/// Score, timer ring, level label and coverage bar. Sits above the game layer.
final class HUDNode: SKNode {

    // MARK: - Nodes
    private let scoreLabel:  SKLabelNode
    private let levelLabel:  SKLabelNode
    private let timerLabel:  SKLabelNode
    private let hintLabel:   SKLabelNode
    private let timerRing   = SKShapeNode()
    private let timerFill   = SKShapeNode()
    private let coverageFill = SKShapeNode()
    private var targetMarker = SKShapeNode()

    private let theme: Theme
    private let maxTime: TimeInterval
    private let ringRadius: CGFloat = 22

    /// Set once the timer has gone red, so the colour isn't reassigned every frame.
    private var isInWarningState = false

    // MARK: - Init
    init(theme: Theme, levelConfig: LevelConfig, sceneSize: CGSize) {
        self.theme   = theme
        self.maxTime = levelConfig.timeLimit
        self.scoreLabel = SKLabelNode(fontNamed: Fonts.display(for: theme))
        self.levelLabel = SKLabelNode(fontNamed: Fonts.body(for: theme))
        self.timerLabel = SKLabelNode(fontNamed: Fonts.display(for: theme))
        self.hintLabel  = SKLabelNode(fontNamed: Fonts.body(for: theme))
        super.init()
        setupHUD(sceneSize: sceneSize, levelConfig: levelConfig)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    // MARK: - Setup
    private func setupHUD(sceneSize: CGSize, levelConfig: LevelConfig) {
        let top = sceneSize.height / 2 - 70   // below the notch / dynamic island

        // Score
        scoreLabel.fontSize  = 28
        scoreLabel.fontColor = theme.hudAccentColor
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.text = "0"
        scoreLabel.position = CGPoint(x: -sceneSize.width / 2 + 24, y: top)
        addChild(scoreLabel)

        // Level
        levelLabel.fontSize  = 14
        levelLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.6)
        levelLabel.horizontalAlignmentMode = .right
        levelLabel.verticalAlignmentMode = .center
        levelLabel.text = "LVL \(levelConfig.id)"
        levelLabel.position = CGPoint(x: sceneSize.width / 2 - 24, y: top)
        addChild(levelLabel)

        // Timer ring — a static track with an arc drawn over it.
        timerRing.path = CGPath(ellipseIn: CGRect(x: -ringRadius, y: -ringRadius,
                                                  width: ringRadius * 2, height: ringRadius * 2),
                                transform: nil)
        timerRing.strokeColor = theme.hudTextColor.withAlphaComponent(0.15)
        timerRing.lineWidth   = 4
        timerRing.fillColor   = .clear
        timerRing.position    = CGPoint(x: 0, y: top)
        addChild(timerRing)

        timerFill.strokeColor = theme.hudAccentColor
        timerFill.lineWidth   = 4
        timerFill.fillColor   = .clear
        timerFill.lineCap     = .round
        timerFill.position    = timerRing.position
        addChild(timerFill)

        timerLabel.fontSize  = 16
        timerLabel.fontColor = theme.hudTextColor
        timerLabel.verticalAlignmentMode = .center
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.text = "\(Int(maxTime))"
        timerLabel.position = timerRing.position
        addChild(timerLabel)

        // Coverage bar
        let barW = sceneSize.width - 48
        let barY = -sceneSize.height / 2 + 46
        let barBg = SKShapeNode(rectOf: CGSize(width: barW, height: 6), cornerRadius: 3)
        barBg.fillColor   = theme.hudTextColor.withAlphaComponent(0.1)
        barBg.strokeColor = .clear
        barBg.position    = CGPoint(x: 0, y: barY)
        addChild(barBg)

        coverageFill.fillColor   = theme.hudAccentColor
        coverageFill.strokeColor = .clear
        coverageFill.position    = CGPoint(x: -barW / 2, y: barY)
        addChild(coverageFill)

        // Where the player is trying to get to.
        targetMarker = SKShapeNode(rectOf: CGSize(width: 2, height: 14))
        targetMarker.fillColor   = theme.hudTextColor.withAlphaComponent(0.5)
        targetMarker.strokeColor = .clear
        targetMarker.position = CGPoint(x: -barW / 2 + CGFloat(levelConfig.targetCoverage) * barW,
                                        y: barY)
        addChild(targetMarker)

        // Pause. Only actionable before drawing starts — once the line is live,
        // reaching for a button means lifting a finger, which ends the round anyway.
        let pause = SKLabelNode(fontNamed: Fonts.display(for: theme))
        pause.text = "❚❚"
        pause.fontSize = 14
        pause.fontColor = theme.hudTextColor.withAlphaComponent(0.5)
        pause.verticalAlignmentMode = .center
        pause.horizontalAlignmentMode = .right
        pause.position = CGPoint(x: sceneSize.width / 2 - 24, y: top - 28)
        pause.name = "pause_button"
        addChild(pause)

        hintLabel.fontSize  = 12
        hintLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.45)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.text = "Touch and hold to draw — don't lift, don't cross"
        hintLabel.position = CGPoint(x: 0, y: barY + 18)
        addChild(hintLabel)
    }

    // MARK: - Updates (driven from GameScene.update)

    func updateScore(_ score: Int) {
        scoreLabel.text = score.formatted()
    }

    func updateTimer(remaining: TimeInterval) {
        timerLabel.text = "\(Int(ceil(remaining)))"
        let fraction = maxTime > 0 ? CGFloat(remaining / maxTime) : 0
        let arcPath = CGMutablePath()
        // Drains clockwise from 12 o'clock.
        arcPath.addArc(center: .zero, radius: ringRadius,
                       startAngle: .pi / 2,
                       endAngle: .pi / 2 - .pi * 2 * max(0, fraction),
                       clockwise: true)
        timerFill.path = arcPath

        if remaining <= 10 && !isInWarningState {
            isInWarningState = true
            let warn = SKColor(hex: "#ef4444")
            timerFill.strokeColor = warn
            timerLabel.fontColor  = warn
            timerLabel.run(.repeatForever(.sequence([
                .scale(to: 1.15, duration: 0.5),
                .scale(to: 1.0, duration: 0.5),
            ])))
        }
    }

    func updateCoverage(_ fraction: Float, targetFraction: Float, barWidth: CGFloat) {
        let w = max(0, min(CGFloat(fraction), 1) * barWidth)
        coverageFill.path = CGPath(rect: CGRect(x: 0, y: -3, width: w, height: 6), transform: nil)
        coverageFill.fillColor = fraction >= targetFraction
            ? SKColor(hex: "#22c55e")
            : theme.hudAccentColor
    }

    /// Hides the "how to play" hint once the player is actually drawing.
    func setHintVisible(_ visible: Bool) {
        hintLabel.run(.fadeAlpha(to: visible ? 1 : 0, duration: 0.2))
    }
}
