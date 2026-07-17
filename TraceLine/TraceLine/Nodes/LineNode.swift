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

    /// Which engine point each render point came from. Decimation means the two arrays
    /// do not line up, and the doomed overlay has to be cut at the same place the engine
    /// will actually sever — otherwise the warning points somewhere the cut doesn't.
    private var renderSource: [Int] = []

    /// Drawn over the stretch of line a cutter is going to take.
    private var doomedNode: SKShapeNode?

    /// Clay only: an offset copy under the line, which reads as a bevel.
    private var bevelNode: SKShapeNode?

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

        if theme.lineBevelOffset != .zero {
            let bevel = SKShapeNode()
            bevel.strokeColor = theme.lineShadowColor
            bevel.lineWidth = theme.lineWidth
            bevel.lineCap = theme.lineCap
            bevel.lineJoin = .round
            bevel.fillColor = .clear
            bevel.position = CGPoint(x: theme.lineBevelOffset.dx, y: theme.lineBevelOffset.dy)
            insertChild(bevel, at: 0)
            bevelNode = bevel
        }

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
            renderSource = []
            consumedPointCount = 0
            doomedNode?.path = nil
        }
        for (offset, p) in points[consumedPointCount...].enumerated() {
            appendSimplified(p, sourceIndex: consumedPointCount + offset)
        }
        consumedPointCount = points.count

        let path = CGMutablePath()
        path.move(to: renderPoints[0])
        for p in renderPoints.dropFirst() { path.addLine(to: p) }
        // Both nodes get the same immutable path; never hand SpriteKit a CGMutablePath
        // that is still being written to.
        let snapshot = path.copy()
        shapeNode.path = snapshot
        glowNode?.path = snapshot
        bevelNode?.path = snapshot
    }

    /// Extends the drawn polyline, dropping the previous point when it turns out to sit
    /// on the straight line between its neighbours.
    private func appendSimplified(_ p: CGPoint, sourceIndex: Int) {
        guard renderPoints.count >= 2 else {
            renderPoints.append(p)
            renderSource.append(sourceIndex)
            return
        }
        let anchor = renderPoints[renderPoints.count - 2]
        let candidate = renderPoints[renderPoints.count - 1]
        if GeometryHelpers.distanceToSegment(candidate, anchor, p) < Self.simplifyTolerance {
            renderPoints[renderPoints.count - 1] = p   // straight run — extend it
            renderSource[renderSource.count - 1] = sourceIndex
        } else {
            renderPoints.append(p)                     // a real corner
            renderSource.append(sourceIndex)
        }
    }

    /// Highlights the leading `engineCount` points as doomed — the stretch a cutter will
    /// sever when it finishes its pass. Showing this while the player draws is what turns
    /// a cut from something the game took into something the player chose to spend.
    /// Pass 0 to clear.
    ///
    /// `points` is the engine's full-resolution array: the render points are decimated to
    /// corners, so stopping at the last whole corner would under-report the loss by up to
    /// a full straight run — on a serpentine, an entire row. The exact cut point is added
    /// as the final vertex so the warning ends precisely where the blade will.
    func markDoomed(points: [CGPoint], engineCount: Int, color: SKColor) {
        guard engineCount > 1, renderPoints.count >= 2, engineCount <= points.count else {
            doomedNode?.path = nil
            return
        }

        // Last render point still inside the doomed stretch.
        var last = 0
        while last + 1 < renderSource.count && renderSource[last + 1] < engineCount {
            last += 1
        }

        let path = CGMutablePath()
        path.move(to: renderPoints[0])
        if last >= 1 {
            for i in 1...last { path.addLine(to: renderPoints[i]) }
        }
        path.addLine(to: points[engineCount - 1])

        let node = doomedNode ?? makeDoomedNode()
        node.strokeColor = color
        node.path = path.copy(dashingWithPhase: 0, lengths: [7, 5])
    }

    private func makeDoomedNode() -> SKShapeNode {
        let node = SKShapeNode()
        node.lineWidth = theme.lineWidth + 2
        node.lineCap = .butt
        node.fillColor = .clear
        node.alpha = 0.9
        node.zPosition = 1          // over the line, under nothing else
        addChild(node)
        doomedNode = node
        return node
    }

    /// Flash red on fail, then fade out.
    /// `colorize` is deliberately not used here — it only affects SKSpriteNode textures
    /// and is a no-op on a shape node's stroke.
    func triggerFail(completion: @escaping () -> Void) {
        isFailing = true
        let failColor = SKColor(hex: "#ff2255")
        shapeNode.strokeColor = failColor
        glowNode?.strokeColor = failColor

        doomedNode?.path = nil
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
        renderSource = []
        consumedPointCount = 0
        doomedNode?.path = nil
        shapeNode.path = nil
        glowNode?.path = nil
        bevelNode?.path = nil
        shapeNode.alpha = theme.lineAlpha
        shapeNode.strokeColor = theme.lineColor
        glowNode?.strokeColor = theme.lineShadowColor
        glowNode?.alpha = 0.4
        alpha = 1
        setScale(1)
    }
}
