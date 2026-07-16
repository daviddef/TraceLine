import SpriteKit

/// Renders the player's drawn path.
final class LineNode: SKNode {

    private let shapeNode = SKShapeNode()
    private var glowNode: SKShapeNode?
    private(set) var isFailing = false
    private let theme: Theme

    /// The path is grown a point at a time rather than rebuilt from the full array
    /// on every touch, which matters once a path is thousands of points long.
    private var path = CGMutablePath()
    private var renderedPointCount = 0

    init(theme: Theme) {
        self.theme = theme
        super.init()
        setupShape()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    private func setupShape() {
        shapeNode.strokeColor = theme.lineColor
        shapeNode.lineWidth   = theme.lineWidth
        shapeNode.lineCap     = theme.lineCap
        shapeNode.lineJoin    = .round
        shapeNode.fillColor   = .clear
        shapeNode.alpha       = theme.lineAlpha
        shapeNode.isAntialiased = !theme.pixelated
        addChild(shapeNode)

        if theme.lineGlowWidth > 0 {
            let glow = SKShapeNode()
            glow.strokeColor = theme.lineShadowColor
            glow.lineWidth   = theme.lineWidth + theme.lineGlowWidth
            glow.lineCap     = theme.lineCap
            glow.lineJoin    = .round
            glow.fillColor   = .clear
            glow.alpha       = 0.4
            insertChild(glow, at: 0)
            glowNode = glow
        }
    }

    /// Call whenever the engine's point array changes.
    func update(points: [CGPoint]) {
        guard points.count >= 2 else {
            shapeNode.path = nil
            glowNode?.path = nil
            return
        }

        if points.count > renderedPointCount, renderedPointCount >= 1 {
            // Common case: append only what's new.
            for p in points[renderedPointCount...] { path.addLine(to: p) }
        } else if points.count != renderedPointCount {
            // The array changed shape (a reset, or a new round) — rebuild from scratch.
            path = CGMutablePath()
            path.move(to: points[0])
            for p in points.dropFirst() { path.addLine(to: p) }
        }
        renderedPointCount = points.count

        shapeNode.path = path
        glowNode?.path = path
    }

    /// Flash red on fail, then fade out.
    /// `colorize` is deliberately not used here — it only affects SKSpriteNode textures
    /// and is a no-op on a shape node's stroke.
    func triggerFail(completion: @escaping () -> Void) {
        isFailing = true
        let failColor = SKColor(hex: "#ff2255")
        shapeNode.strokeColor = failColor
        glowNode?.strokeColor = failColor

        let flash = SKAction.sequence([
            .scale(to: 1.04, duration: 0.08),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.25),
            .fadeOut(withDuration: 0.25),
        ])
        run(flash) { completion() }
    }

    func reset() {
        isFailing = false
        path = CGMutablePath()
        renderedPointCount = 0
        shapeNode.path = nil
        glowNode?.path = nil
        shapeNode.alpha = theme.lineAlpha
        shapeNode.strokeColor = theme.lineColor
        glowNode?.strokeColor = theme.lineShadowColor
        glowNode?.alpha = 0.4
        alpha = 1
        setScale(1)
    }
}
