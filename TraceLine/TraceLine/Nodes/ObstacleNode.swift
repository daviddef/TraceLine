import SpriteKit

final class ObstacleNode: SKNode {

    let obstacleType: ObstacleType
    var fallSpeed: CGFloat = 80          // points per second

    /// Horizontal speed, movers only. Sign is the current direction of travel.
    private var driftSpeed: CGFloat = 0

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
        case .magnetic:           return Self.magneticRadius
        case .mover:              return Self.moverSize.width / 2
        case .cutter:             return Self.cutterSize.width / 2
        }
    }

    // Half-extents of the hit zone, kept in one place so the visual shape and the
    // descriptor handed to DrawingEngine can never drift apart.
    private static let circleRadius: CGFloat = 14
    private static let magneticRadius: CGFloat = 12
    private static let moverSize = CGSize(width: 50, height: 12)
    static let cutterSize = CGSize(width: 46, height: 18)

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
            let shape = SKShapeNode(circleOfRadius: Self.circleRadius)
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }

        case .mover:
            let shape = SKShapeNode(rectOf: Self.moverSize, cornerRadius: 6)
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }

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

        case .shrinker:
            let path = CGMutablePath()
            let s = Self.circleRadius
            path.move(to: CGPoint(x: 0, y: -s))
            path.addLine(to: CGPoint(x: s, y: 0))
            path.addLine(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s, y: 0))
            path.closeSubpath()
            let shape = SKShapeNode(path: path)
            shape.fillColor = color
            shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(like: shape, color: color) }
            // Rotation is safe as an SKAction: unlike a move action it never writes position.
            run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3)))
        }
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
        case .magnetic:
            return ObstacleDescriptor(id: hash, shape: .circle(center: pos, radius: Self.magneticRadius))
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
