import SpriteKit

/// Renders the player's drawn path.
final class LineNode: SKNode {

    private let shapeNode = SKShapeNode()
    private var glowNode: SKShapeNode?
    private(set) var isFailing = false
    private let theme: Theme
    private let effect: LineEffect

    /// Sparks thrown from the drawing tip.
    private var sparkNode: SKEmitterNode?
    /// The travelling highlight used by `.comet`.
    private var cometNode: SKShapeNode?
    /// Seconds since the round began, driving the time-based effects.
    private var elapsed: TimeInterval = 0

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

    init(theme: Theme, effect: LineEffect = .plain) {
        self.theme = theme
        self.effect = effect
        super.init()
        setupShape()
        setupEffect()
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

    // MARK: - Effects

    private func setupEffect() {
        switch effect {
        case .plain, .prism:
            break

        case .spark:
            let emitter = SKEmitterNode()
            emitter.particleTexture = Self.softDot
            // Tuned by looking at it. The first attempt used 5pt embers that shrank and
            // faded within half a second — individually invisible against a line that
            // already glows. Fewer, larger, slower-fading particles read as sparks;
            // more of them read as fog.
            emitter.particleBirthRate = 0            // only while the finger is moving
            emitter.particleLifetime = 0.7
            emitter.particleLifetimeRange = 0.4
            emitter.particleSize = CGSize(width: 11, height: 11)
            emitter.particleScaleSpeed = -0.9
            emitter.particleAlphaSpeed = -1.2
            emitter.particleSpeed = 46
            emitter.particleSpeedRange = 32
            emitter.emissionAngleRange = .pi * 2
            emitter.particleColor = theme.lineColor
            emitter.particleColorBlendFactor = 1
            emitter.particleBlendMode = .add
            emitter.zPosition = 2
            emitter.targetNode = self          // embers stay put rather than trailing the tip
            addChild(emitter)
            sparkNode = emitter

        case .comet:
            let comet = SKShapeNode(circleOfRadius: theme.lineWidth * 1.5)
            comet.fillColor = theme.lineColor
            comet.strokeColor = .clear
            comet.blendMode = .add
            comet.alpha = 0
            comet.zPosition = 3
            addChild(comet)
            cometNode = comet
        }
    }

    /// A soft round particle, built once in code — the game ships no image assets.
    private static let softDot: SKTexture = {
        let side = 16
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            let colours = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colours as CFArray, locations: [0, 1]) else { return }
            let mid = CGPoint(x: size.width / 2, y: size.height / 2)
            c.drawRadialGradient(gradient, startCenter: mid, startRadius: 0,
                                 endCenter: mid, endRadius: size.width / 2, options: [])
        }
        return SKTexture(image: image)
    }()

    /// Drives the time-based effects. Call once per frame from the scene while drawing.
    func advance(dt: TimeInterval, isDrawing: Bool) {
        guard !isFailing else { return }
        elapsed += dt

        switch effect {
        case .plain:
            break

        case .prism:
            // Hue drifts; saturation and brightness are taken from the theme's own line
            // colour so the line stays as legible as it was against that background.
            var h: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, a: CGFloat = 0
            theme.lineColor.getHue(&h, saturation: &sat, brightness: &bri, alpha: &a)
            let hue = (h + CGFloat(elapsed) * 0.16).truncatingRemainder(dividingBy: 1)
            let colour = SKColor(hue: hue, saturation: sat, brightness: bri, alpha: a)
            shapeNode.strokeColor = colour
            glowNode?.strokeColor = colour.withAlphaComponent(0.8)

        case .spark:
            sparkNode?.particleBirthRate = isDrawing ? 55 : 0
            if let tip = renderPoints.last { sparkNode?.position = tip }

        case .comet:
            guard renderPoints.count >= 2, let comet = cometNode else { return }
            // One sweep of the whole path every 1.6s.
            let phase = (elapsed.truncatingRemainder(dividingBy: 1.6)) / 1.6
            let index = phase * Double(renderPoints.count - 1)
            let i = min(renderPoints.count - 2, Int(index))
            let t = CGFloat(index - Double(i))
            let a = renderPoints[i], b = renderPoints[i + 1]
            comet.position = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            comet.alpha = 0.9
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
        sparkNode?.particleBirthRate = 0
        cometNode?.alpha = 0
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
        elapsed = 0
        sparkNode?.particleBirthRate = 0
        cometNode?.alpha = 0
        shapeNode.strokeColor = theme.lineColor
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
