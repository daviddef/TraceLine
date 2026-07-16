import SpriteKit

/// Renders the player's drawn path.
final class LineNode: SKNode {

    private let shapeNode = SKShapeNode()
    private var glowNode: SKShapeNode?
    private(set) var isFailing = false
    private let theme: Theme

    /// The engine's points, decimated for drawing. A straight run needs two vertices,
    /// not one every 4pt: SKShapeNode tessellates a wide stroke per-vertex, and piling
    /// up near-collinear points makes the round joins overlap and tear the glow into
    /// visible triangles. Collision still uses the engine's full-resolution points —
    /// this only affects what is drawn.
    private var renderPoints: [CGPoint] = []
    private var consumedPointCount = 0

    /// Max perpendicular deviation (pt) before a point earns its own vertex.
    private static let simplifyTolerance: CGFloat = 0.6

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

        // A shorter array than last time means a new round — start over.
        if points.count < consumedPointCount {
            renderPoints = []
            consumedPointCount = 0
        }
        for p in points[consumedPointCount...] { appendSimplified(p) }
        consumedPointCount = points.count

        let path = CGMutablePath()
        path.move(to: renderPoints[0])
        for p in renderPoints.dropFirst() { path.addLine(to: p) }
        // Both nodes get the same immutable path; never hand SpriteKit a CGMutablePath
        // that is still being written to.
        let snapshot = path.copy()
        shapeNode.path = snapshot
        glowNode?.path = snapshot
    }

    /// Extends the drawn polyline, dropping the previous point when it turns out to sit
    /// on the straight line between its neighbours.
    private func appendSimplified(_ p: CGPoint) {
        guard renderPoints.count >= 2 else {
            renderPoints.append(p)
            return
        }
        let anchor = renderPoints[renderPoints.count - 2]
        let candidate = renderPoints[renderPoints.count - 1]
        if GeometryHelpers.distanceToSegment(candidate, anchor, p) < Self.simplifyTolerance {
            renderPoints[renderPoints.count - 1] = p   // straight run — extend it
        } else {
            renderPoints.append(p)                     // a real corner
        }
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
        renderPoints = []
        consumedPointCount = 0
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
