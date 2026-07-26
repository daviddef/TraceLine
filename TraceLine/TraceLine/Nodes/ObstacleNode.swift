import SpriteKit

final class ObstacleNode: SKNode {

    let obstacleType: ObstacleType
    var fallSpeed: CGFloat = 80          // points per second

    /// Horizontal speed, movers only. Sign is the current direction of travel.
    private var driftSpeed: CGFloat = 0

    /// Hunters only. The point they steer toward — the scene sets this to the drawing tip
    /// each frame. How fast they close is `Self.hunterSpeed`.
    var huntTarget: CGPoint?
    static let hunterSpeed: CGFloat = 58

    /// Cutters only. Direction is held separately from speed rather than being read off
    /// its sign: a stationary cutter still faces somewhere, and the lane shadow depends
    /// on which way it is going, not how fast.
    private(set) var crossSpeed: CGFloat = 0
    private(set) var crossDirection: CGFloat = 1

    /// The lane a cutter runs along, drawn on the board so the hazard is visible before
    /// it arrives. Owned by the scene, not this node — it must not move with the cutter.
    weak var laneNode: SKNode?

    /// Radius used when resolving contact with a safe zone.
    var hitRadius: CGFloat {
        switch obstacleType {
        case .blocker, .shrinker: return Self.circleRadius
        case .fuse:               return Self.fuseRadius
        case .magnetic:           return Self.magneticRadius
        case .mover:              return Self.moverSize.width / 2
        case .cutter:             return Self.cutterSize.width / 2
        case .hunter:             return Self.hunterRadius
        }
    }

    // Half-extents of the hit zone, kept in one place so the visual shape and the
    // descriptor handed to DrawingEngine can never drift apart.
    private static let circleRadius: CGFloat = 14
    private static let magneticRadius: CGFloat = 12
    private static let moverSize = CGSize(width: 50, height: 12)
    static let cutterSize = CGSize(width: 46, height: 18)

    /// How far a magnet's field reaches, and how hard it bends the line per point.
    /// The field ring is drawn at exactly this radius — a pull that reached beyond what
    /// the player can see would be the game cheating.
    static let magneticFieldRadius: CGFloat = 78
    private static let fuseRadius: CGFloat = 13
    private static let hunterRadius: CGFloat = 13
    /// Max deflection at the core, falling to zero at the field's edge. Tuned by looking
    /// at it: at 3.2 the bend was under 2pt — thinner than the line itself, so the field
    /// looked like decoration. At 18 the line visibly leans, and anything inside roughly
    /// 28pt gets dragged into the core, which is the danger the ring is warning about.
    static let magneticPull: CGFloat = 18

    // MARK: - Init
    init(type: ObstacleType, theme: Theme) {
        self.obstacleType = type
        super.init()
        setupShape(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    // MARK: - Shape setup
    private func setupShape(theme: Theme) {
        let color = theme.obstacleColors[obstacleType.themeIndex]
        switch obstacleType {
        case .blocker:
            // A mine: a round body ringed with spikes, so it reads as "do not touch" at a
            // glance rather than as a neutral dot. The spike tips sit at the true hit radius
            // so the silhouette does not promise a bigger danger than there is.
            let r = Self.circleRadius
            let spikes = SKShapeNode(path: Self.minePath(bodyR: r * 0.72, tipR: r, count: 8))
            spikes.fillColor = color
            spikes.strokeColor = .clear
            addChild(spikes)
            let body = SKShapeNode(circleOfRadius: r * 0.72)
            body.fillColor = color
            body.strokeColor = .clear
            addChild(body)
            if theme.obstacleGlow { addGlow(like: body, color: color) }
            // A dark eye at the centre for depth — a hint of the hazard's own colour, shaded.
            let eye = SKShapeNode(circleOfRadius: r * 0.28)
            eye.fillColor = Self.shade(color, 0.4)
            eye.strokeColor = .clear
            addChild(eye)

        case .mover:
            let shape = SKShapeNode(rectOf: Self.moverSize, cornerRadius: 6)
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }
            // Chevrons at both ends, pointing outward: a puck that shuttles side to side,
            // not a stationary bar. Shaded in the hazard's own colour so it works on any theme.
            let ink = Self.shade(color, 0.45)
            for dir in [CGFloat(-1), 1] {
                let chevron = SKShapeNode(path: Self.chevronPath(dir: dir))
                chevron.position = CGPoint(x: dir * (Self.moverSize.width / 2 - 9), y: 0)
                chevron.strokeColor = ink
                chevron.lineWidth = 2
                chevron.lineCap = .round
                chevron.fillColor = .clear
                addChild(chevron)
            }

        case .magnetic:
            let core = SKShapeNode(circleOfRadius: Self.magneticRadius)
            core.fillColor = color
            core.strokeColor = .clear
            addChild(core)
            if theme.obstacleGlow { addGlow(like: core, color: color) }

            let ring = SKShapeNode(circleOfRadius: 22)
            ring.fillColor = .clear
            ring.strokeColor = color.withAlphaComponent(0.4)
            ring.lineWidth = 2
            addChild(ring)
            ring.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.1, duration: 0.6),
                .fadeAlpha(to: 0.5, duration: 0.6),
            ])))

            // The field itself, drawn at the exact radius it acts over.
            let field = SKShapeNode(circleOfRadius: Self.magneticFieldRadius)
            field.fillColor = color.withAlphaComponent(0.05)
            field.strokeColor = color.withAlphaComponent(0.3)
            field.lineWidth = 1
            field.zPosition = -1
            addChild(field)
            field.run(.repeatForever(.sequence([
                .group([.scale(to: 1.05, duration: 1.1), .fadeAlpha(to: 0.45, duration: 1.1)]),
                .group([.scale(to: 0.97, duration: 1.1), .fadeAlpha(to: 0.9, duration: 1.1)]),
            ])))

        case .cutter:
            // A blunt-nosed body pointing the way it travels — reads as a train, car or
            // beetle depending on the theme's palette.
            let w = Self.cutterSize.width, h = Self.cutterSize.height
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -w / 2, y: -h / 2))
            path.addLine(to: CGPoint(x: w / 2 - h / 2, y: -h / 2))
            path.addQuadCurve(to: CGPoint(x: w / 2 - h / 2, y: h / 2),
                              control: CGPoint(x: w / 2 + h / 2, y: 0))
            path.addLine(to: CGPoint(x: -w / 2, y: h / 2))
            path.closeSubpath()
            let shape = SKShapeNode(path: path)
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }

        case .fuse:
            // A teardrop flame: round base, tapered tip, flickering. Reads as fire without
            // an image asset.
            // A rounded flame: bulbous base, S-curved shoulders, a soft leaning tip.
            func flamePath(scale: CGFloat) -> CGPath {
                let r = Self.fuseRadius * scale
                let f = CGMutablePath()
                f.move(to: CGPoint(x: 0, y: r * 1.6))                       // tip
                f.addCurve(to: CGPoint(x: -r, y: 0),                        // left shoulder
                           control1: CGPoint(x: -r * 0.7, y: r * 1.1),
                           control2: CGPoint(x: -r, y: r * 0.6))
                f.addCurve(to: CGPoint(x: 0, y: -r),                        // bulbous base, left half
                           control1: CGPoint(x: -r, y: -r * 0.6),
                           control2: CGPoint(x: -r * 0.6, y: -r))
                f.addCurve(to: CGPoint(x: r, y: 0),                         // bulbous base, right half
                           control1: CGPoint(x: r * 0.6, y: -r),
                           control2: CGPoint(x: r, y: -r * 0.6))
                f.addCurve(to: CGPoint(x: 0, y: r * 1.6),                   // right shoulder
                           control1: CGPoint(x: r, y: r * 0.6),
                           control2: CGPoint(x: r * 0.7, y: r * 1.1))
                f.closeSubpath()
                return f
            }

            let shape = SKShapeNode(path: flamePath(scale: 1.0))
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)

            // A brighter inner flame, concentric, and a flicker on both.
            let inner = SKShapeNode(path: flamePath(scale: 0.55))
            inner.fillColor = SKColor(hex: "#fff3d6").withAlphaComponent(0.85)
            inner.strokeColor = .clear
            inner.position = CGPoint(x: 0, y: Self.fuseRadius * 0.1)
            addChild(inner)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }
            let flicker = SKAction.repeatForever(.sequence([
                .group([.scaleX(to: 1.12, duration: 0.18), .scaleY(to: 0.94, duration: 0.18)]),
                .group([.scaleX(to: 0.92, duration: 0.16), .scaleY(to: 1.08, duration: 0.16)]),
                .group([.scaleX(to: 1.0, duration: 0.14), .scaleY(to: 1.0, duration: 0.14)]),
            ]))
            shape.run(flicker)

        case .shrinker:
            let s = Self.circleRadius
            let shape = SKShapeNode(path: Self.diamondPath(s))
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }
            // A second diamond inside that pulses in and out — the space contracting, which
            // is what a shrinker does. It rides above the body and does not affect the hit.
            let inner = SKShapeNode(path: Self.diamondPath(s * 0.62))
            inner.fillColor = Self.shade(color, 0.4)
            inner.strokeColor = .clear
            addChild(inner)
            inner.run(.repeatForever(.sequence([
                .scale(to: 0.45, duration: 0.7),
                .scale(to: 1.0, duration: 0.7),
            ])))
            // Rotation is safe as an SKAction: unlike a move action it never writes position.
            run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3)))

        case .hunter:
            // An arrowhead that points at its prey (the node's zRotation is aimed at the
            // tip each frame), with a bright eye near the nose and a slow menacing pulse.
            let r = Self.hunterRadius
            let path = CGMutablePath()
            path.move(to: CGPoint(x: r, y: 0))                       // nose
            path.addLine(to: CGPoint(x: -r * 0.8, y: r * 0.78))      // upper barb
            path.addLine(to: CGPoint(x: -r * 0.35, y: 0))            // notched tail
            path.addLine(to: CGPoint(x: -r * 0.8, y: -r * 0.78))     // lower barb
            path.closeSubpath()
            let shape = SKShapeNode(path: path)
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }
            let eye = SKShapeNode(circleOfRadius: r * 0.24)
            eye.fillColor = SKColor(hex: "#fff3d6")
            eye.strokeColor = .clear
            eye.position = CGPoint(x: r * 0.32, y: 0)
            addChild(eye)
            shape.run(.repeatForever(.sequence([
                .scale(to: 1.09, duration: 0.5),
                .scale(to: 1.0, duration: 0.5),
            ])))
        }
    }

    // MARK: - Shape helpers

    /// A diamond (square on its point) of half-diagonal `s`.
    private static func diamondPath(_ s: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -s))
        p.addLine(to: CGPoint(x: s, y: 0))
        p.addLine(to: CGPoint(x: 0, y: s))
        p.addLine(to: CGPoint(x: -s, y: 0))
        p.closeSubpath()
        return p
    }

    /// `count` triangular spikes ringing a body of radius `bodyR`, tips reaching `tipR`.
    private static func minePath(bodyR: CGFloat, tipR: CGFloat, count: Int) -> CGPath {
        let p = CGMutablePath()
        let half = (.pi / CGFloat(count)) * 0.55        // half the angular width of a spike base
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * .pi * 2
            p.move(to: CGPoint(x: cos(a - half) * bodyR, y: sin(a - half) * bodyR))
            p.addLine(to: CGPoint(x: cos(a) * tipR, y: sin(a) * tipR))
            p.addLine(to: CGPoint(x: cos(a + half) * bodyR, y: sin(a + half) * bodyR))
            p.closeSubpath()
        }
        return p
    }

    /// A small ">" chevron pointing in `dir` (+1 right, −1 left), centred on the origin.
    private static func chevronPath(dir: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -3 * dir, y: 4))
        p.addLine(to: CGPoint(x: 3 * dir, y: 0))
        p.addLine(to: CGPoint(x: -3 * dir, y: -4))
        return p
    }

    /// A darker shade of a colour — the same hue multiplied toward black, so hazard detail
    /// reads as shading on any theme rather than a fixed ink that fights some palettes.
    private static func shade(_ color: SKColor, _ factor: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: r * factor, green: g * factor, blue: b * factor, alpha: a)
    }

    /// SpriteKit has no native bloom, so a scaled translucent copy stands in for a glow.
    /// A proper SKEffectNode + CIFilter bloom would be the production upgrade.
    private func addGlow(like node: SKShapeNode, color: SKColor) {
        guard let glow = node.copy() as? SKShapeNode else { return }
        glow.fillColor = color.withAlphaComponent(0.25)
        glow.strokeColor = .clear
        glow.setScale(1.6)
        insertChild(glow, at: 0)
    }

    // MARK: - Movement
    /// Sends a cutter across the board from `direction` (+1 = left to right).
    func startCrossing(direction: CGFloat, speed: CGFloat) {
        crossDirection = direction >= 0 ? 1 : -1
        crossSpeed = abs(speed)
        xScale = crossDirection            // face the way it is going
    }

    /// The stretch of lane a cutter has yet to sweep — everything it can still take.
    /// Lane behind it is already spent, so a line crossing there is safe.
    func remainingSweep(in playRect: CGRect, zones: [SafeZone] = []) -> CGRect? {
        guard obstacleType == .cutter else { return nil }
        let halfW = Self.cutterSize.width / 2
        let halfH = Self.cutterSize.height / 2
        let goingRight = crossDirection >= 0
        let leadingEdge = position.x + (goingRight ? halfW : -halfW)
        var minX = goingRight ? leadingEdge : playRect.minX - halfW
        var maxX = goingRight ? playRect.maxX + halfW : leadingEdge

        // A zone straddling the lane stops the cutter dead, so everything past it is out
        // of reach. This is what makes a shelter cast a shadow — and the doomed-tail
        // preview reads the same sweep, so it shows the shadow with no extra work.
        for zone in zones {
            guard let block = zone.laneBlock(atY: position.y, halfHeight: halfH) else { continue }
            if goingRight {
                if block.lowerBound > leadingEdge { maxX = min(maxX, block.lowerBound) }
            } else {
                if block.upperBound < leadingEdge { minX = max(minX, block.upperBound) }
            }
        }

        guard maxX > minX else { return nil }
        return CGRect(x: minX, y: position.y - halfH, width: maxX - minX, height: Self.cutterSize.height)
    }

    /// Bounces the obstacle off any shelter it has run into.
    func rebound(off zones: [SafeZone]) {
        for zone in zones {
            let delta = CGPoint(x: position.x - zone.center.x, y: position.y - zone.center.y)
            let distance = (delta.x * delta.x + delta.y * delta.y).squareRoot()
            let minimum = zone.radius + hitRadius
            guard distance < minimum, distance > 0.001 else { continue }

            let normal = CGPoint(x: delta.x / distance, y: delta.y / distance)
            position = CGPoint(x: zone.center.x + normal.x * minimum,
                               y: zone.center.y + normal.y * minimum)

            if obstacleType == .cutter {
                // Reverse along the lane rather than deflecting off it: a cutter that
                // left its telegraphed track would be exactly the unfair surprise the
                // lane exists to prevent.
                crossDirection = -crossDirection
                xScale = crossDirection
            } else {
                // Slide around the bubble.
                driftSpeed = normal.x * max(abs(fallSpeed), 40) * 0.9
            }
        }
    }

    /// True once the obstacle has left the board and can be recycled.
    func isOffBoard(_ playRect: CGRect) -> Bool {
        if obstacleType == .cutter {
            let margin = Self.cutterSize.width * 1.5
            return position.x < playRect.minX - margin || position.x > playRect.maxX + margin
        }
        // Hunters chase the tip and never fall away; the level's obstacle cap bounds how
        // many can be on the board at once.
        if obstacleType == .hunter { return false }
        return position.y < playRect.minY - 40
    }

    /// Call once after adding to the scene.
    func startFalling(in playWidth: CGFloat) {
        guard obstacleType == .mover else { return }
        // Spec: traverse half the play width in 1.5–3.0s, then reverse.
        let travelTime = CGFloat.random(in: 1.5...3.0)
        driftSpeed = (playWidth * 0.5) / travelTime
        if Bool.random() { driftSpeed = -driftSpeed }
    }

    /// Advances the obstacle. Movement is applied by hand rather than with SKActions
    /// because a move action captures a start position and writes `position` absolutely
    /// each frame, which would overwrite the falling motion applied here.
    func update(dt: TimeInterval, playRect: CGRect) {
        // Cutters run their lane instead of falling.
        if obstacleType == .cutter {
            position.x += crossDirection * crossSpeed * CGFloat(dt)
            return
        }

        // Hunters steer toward the drawing tip rather than falling. Slow enough to route
        // around, relentless enough that you cannot just sit still.
        if obstacleType == .hunter {
            guard let target = huntTarget else { return }
            let dx = target.x - position.x, dy = target.y - position.y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist > 0.5 {
                let step = min(Self.hunterSpeed * CGFloat(dt), dist)
                position.x += dx / dist * step
                position.y += dy / dist * step
            }
            // Face the prey, so the wedge visibly points at where it is going.
            zRotation = atan2(dy, dx)
            return
        }

        position.y -= fallSpeed * CGFloat(dt)

        guard driftSpeed != 0 else { return }
        position.x += driftSpeed * CGFloat(dt)
        let halfWidth = hitRadius
        if position.x - halfWidth < playRect.minX {
            position.x = playRect.minX + halfWidth
            driftSpeed = abs(driftSpeed)
        } else if position.x + halfWidth > playRect.maxX {
            position.x = playRect.maxX - halfWidth
            driftSpeed = -abs(driftSpeed)
        }
    }

    // MARK: - Descriptor for DrawingEngine (rebuilt each frame)
    func descriptor() -> ObstacleDescriptor {
        let pos = position
        switch obstacleType {
        case .blocker, .shrinker:
            return ObstacleDescriptor(id: hash, shape: .circle(center: pos, radius: Self.circleRadius))
        case .hunter:
            return ObstacleDescriptor(id: hash, shape: .circle(center: pos, radius: Self.hunterRadius))
        case .fuse:
            return ObstacleDescriptor(id: hash, shape: .circle(center: pos, radius: Self.fuseRadius),
                                      ignites: true)
        case .magnetic:
            return ObstacleDescriptor(id: hash, shape: .circle(center: pos, radius: Self.magneticRadius),
                                      pull: Self.magneticPull, pullRadius: Self.magneticFieldRadius)
        case .mover:
            return ObstacleDescriptor(id: hash, shape: .rect(CGRect(
                x: pos.x - Self.moverSize.width / 2,
                y: pos.y - Self.moverSize.height / 2,
                width: Self.moverSize.width,
                height: Self.moverSize.height
            )))
        case .cutter:
            return ObstacleDescriptor(id: hash, shape: .rect(CGRect(
                x: pos.x - Self.cutterSize.width / 2,
                y: pos.y - Self.cutterSize.height / 2,
                width: Self.cutterSize.width,
                height: Self.cutterSize.height
            )), severs: true)
        }
    }
}
