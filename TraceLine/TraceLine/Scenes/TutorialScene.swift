import SpriteKit

/// The first-run how-to-play. TraceLine fails you fast and its two rules are unusual
/// (never lift, never cross), so a cold open into level 1 is punishing. This shows once —
/// a line that draws itself, the two rules, and a way in — then never again.
final class TutorialScene: SKScene {

    private let theme: Theme

    init(theme: Theme, size: CGSize) {
        self.theme = theme
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    override func didMove(to view: SKView) {
        backgroundColor = theme.background
        addChild(BackgroundNode(theme: theme, size: size))

        let title = SKLabelNode(fontNamed: Fonts.display(for: theme))
        title.text = "How to Play"
        title.fontSize = 40
        title.fontColor = theme.lineColor
        title.position = CGPoint(x: 0, y: size.height / 2 - 130)
        addChild(title)

        addSelfDrawingDemo(topY: size.height / 2 - 200)

        // The two rules, and the one instruction. Emoji so they read at a glance.
        addRule("✏️", "Touch and hold — the line follows your finger",  y: -20)
        addRule("✋", "Never lift your finger, or the round ends",       y: -78)
        addRule("✕",  "Never cross the line you've already drawn",       y: -136)

        let goal = SKLabelNode(fontNamed: Fonts.body(for: theme))
        goal.text = "Fill enough of the board before time runs out."
        goal.fontSize = 13
        goal.fontColor = theme.hudTextColor.withAlphaComponent(0.55)
        goal.position = CGPoint(x: 0, y: -196)
        goal.preferredMaxLayoutWidth = size.width - 60
        goal.numberOfLines = 2
        goal.verticalAlignmentMode = .center
        addChild(goal)

        addChild(ButtonNode(title: "▶  Let's Go", theme: theme, name: "play_button",
                            position: CGPoint(x: 0, y: -size.height / 2 + 130), isPrimary: true))
    }

    /// A serpentine that redraws itself on a loop, a bright tip leading it — the core loop
    /// in one glance: your finger lays down a continuous line.
    private func addSelfDrawingDemo(topY: CGFloat) {
        let width = min(320, size.width - 80)
        let height: CGFloat = 150
        let left = -width / 2, right = width / 2
        let rows = 4
        let spacing = height / CGFloat(rows - 1)

        var pts: [CGPoint] = []
        var y = topY
        var goingRight = true
        for _ in 0..<rows {
            pts.append(CGPoint(x: goingRight ? left : right, y: y))
            pts.append(CGPoint(x: goingRight ? right : left, y: y))
            y -= spacing
            goingRight.toggle()
        }
        // Resample into evenly spaced points so the reveal advances at a steady pace.
        let dense = Self.resample(pts, step: 6)

        let line = SKShapeNode()
        line.strokeColor = theme.lineColor
        line.lineWidth = theme.lineWidth
        line.lineCap = .round
        line.lineJoin = .round
        line.fillColor = .clear
        addChild(line)

        let glow = SKShapeNode()
        glow.strokeColor = theme.lineColor.withAlphaComponent(0.35)
        glow.lineWidth = theme.lineWidth + 8
        glow.lineCap = .round
        glow.lineJoin = .round
        glow.fillColor = .clear
        glow.zPosition = -1
        addChild(glow)

        let tip = SKShapeNode(circleOfRadius: theme.lineWidth)
        tip.fillColor = theme.hudAccentColor
        tip.strokeColor = .clear
        tip.zPosition = 1
        addChild(tip)

        let draw = SKAction.customAction(withDuration: 2.2) { _, elapsed in
            let frac = max(0, min(1, elapsed / 2.2))
            let count = max(2, Int(frac * CGFloat(dense.count)))
            let path = CGMutablePath()
            path.move(to: dense[0])
            for i in 1..<count { path.addLine(to: dense[i]) }
            line.path = path
            glow.path = path
            tip.position = dense[count - 1]
        }
        let clear = SKAction.run {
            line.path = nil; glow.path = nil; tip.position = dense[0]
        }
        run(.repeatForever(.sequence([draw, .wait(forDuration: 0.6), clear, .wait(forDuration: 0.3)])))
    }

    private func addRule(_ glyph: String, _ text: String, y: CGFloat) {
        let width = size.width - 56
        let icon = SKLabelNode(fontNamed: Fonts.body(for: theme))
        icon.text = glyph
        icon.fontSize = 22
        icon.horizontalAlignmentMode = .center
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: -width / 2 + 18, y: y)
        addChild(icon)

        let label = SKLabelNode(fontNamed: Fonts.body(for: theme))
        label.text = text
        label.fontSize = 15
        label.fontColor = theme.hudTextColor.withAlphaComponent(0.9)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width / 2 + 42, y: y)
        addChild(label)
    }

    /// Evenly spaced points along a polyline, so a reveal walks it at constant speed.
    private static func resample(_ pts: [CGPoint], step: CGFloat) -> [CGPoint] {
        guard pts.count >= 2 else { return pts }
        var out = [pts[0]]
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let d = GeometryHelpers.distance(a, b)
            let n = max(1, Int(d / step))
            for s in 1...n {
                let t = CGFloat(s) / CGFloat(n)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return out
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self),
              atPoint(pos).name == "play_button" else { return }
        Haptics.tap()
        PlayerProgress.shared.hasSeenTutorial = true
        view?.presentScene(HomeScene(theme: theme, size: size),
                           transition: .fade(withDuration: 0.35))
    }
}
