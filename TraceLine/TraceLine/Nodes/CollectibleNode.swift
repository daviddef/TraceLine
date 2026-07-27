import SpriteKit

/// A collectible you route your line through to eat. Contact is a hazard *inverted* —
/// it is good — so it wears no hazard colour. Two kinds so far:
///   - `.pip`   — a warm gold orb worth bonus points.
///   - `.shield` — a green orb that grants a one-hit shield (deflects the next object).
final class CollectibleNode: SKNode {

    enum Kind { case pip, shield }

    let kind: Kind

    static let radius: CGFloat = 11
    /// How close the drawing tip must come to eat it — a touch bigger than the body, so a
    /// near-miss still feels like a catch rather than a tease.
    static let collectRadius: CGFloat = 20
    static let pipValue = 250
    static let shieldValue = 100

    /// Points banked for eating this one (the shield's real reward is the shield itself).
    var value: Int { kind == .pip ? Self.pipValue : Self.shieldValue }

    private static let gold  = SKColor(hex: "#ffd24a")
    private static let green = SKColor(hex: "#34d399")
    private var tint: SKColor { kind == .pip ? Self.gold : Self.green }

    init(kind: Kind = .pip) {
        self.kind = kind
        super.init()
        let tint = kind == .pip ? Self.gold : Self.green

        let glow = SKShapeNode(circleOfRadius: Self.radius * 2.1)
        glow.fillColor = tint.withAlphaComponent(0.22)
        glow.strokeColor = .clear
        glow.blendMode = .add
        addChild(glow)

        let body = SKShapeNode(circleOfRadius: Self.radius)
        body.fillColor = tint
        body.strokeColor = .clear
        addChild(body)

        if kind == .shield {
            // A ring around the orb reads as a barrier — "this one protects you".
            let ring = SKShapeNode(circleOfRadius: Self.radius * 1.5)
            ring.strokeColor = tint
            ring.lineWidth = 2
            ring.fillColor = .clear
            ring.alpha = 0.7
            addChild(ring)
            ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.6),
                                               .fadeAlpha(to: 0.7, duration: 0.6)])))
        }

        let shine = SKShapeNode(circleOfRadius: Self.radius * 0.34)
        shine.fillColor = .white
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -Self.radius * 0.32, y: Self.radius * 0.32)
        shine.alpha = 0.9
        addChild(shine)

        run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.6),
                                      .scale(to: 1.0, duration: 0.6)])))
        run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.9),
                                      .moveBy(x: 0, y: -5, duration: 0.9)])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — nodes are built in code") }

    /// Eat it: a bright pop of sparks in its own colour, then remove.
    func collect() {
        removeAllActions()
        let pop = SKEmitterNode()
        pop.particleTexture = LineNode.softDot
        pop.numParticlesToEmit = 20
        pop.particleBirthRate = 1600
        pop.particleLifetime = 0.5
        pop.particleLifetimeRange = 0.2
        pop.particleSize = CGSize(width: 9, height: 9)
        pop.particleScaleSpeed = -1.6
        pop.particleAlphaSpeed = -2.0
        pop.particleSpeed = 170
        pop.particleSpeedRange = 80
        pop.emissionAngleRange = .pi * 2
        pop.particleColor = tint
        pop.particleColorBlendFactor = 1
        pop.particleBlendMode = .add
        pop.targetNode = parent
        pop.position = position
        parent?.addChild(pop)
        pop.run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))

        run(.sequence([.group([.scale(to: 1.6, duration: 0.12), .fadeOut(withDuration: 0.12)]),
                       .removeFromParent()]))
    }
}
