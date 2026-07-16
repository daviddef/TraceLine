import SpriteKit

final class ObstacleNode: SKNode {

    let obstacleType: ObstacleType
    var fallSpeed: CGFloat = 80          // points per second

    /// Horizontal speed, movers only. Sign is the current direction of travel.
    private var driftSpeed: CGFloat = 0

    // Half-extents of the hit zone, kept in one place so the visual shape and the
    // descriptor handed to DrawingEngine can never drift apart.
    private static let circleRadius: CGFloat = 14
    private static let magneticRadius: CGFloat = 12
    private static let moverSize = CGSize(width: 50, height: 12)

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
        position.y -= fallSpeed * CGFloat(dt)

        guard obstacleType == .mover, driftSpeed != 0 else { return }
        position.x += driftSpeed * CGFloat(dt)
        let halfWidth = Self.moverSize.width / 2
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
        }
    }
}
