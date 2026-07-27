import SpriteKit

/// A bonus pip you route your line through to eat. It is a hazard inverted — contact is
/// *good* — so it deliberately does not wear any hazard colour: a warm gold orb that reads
/// as treasure, gently pulsing and bobbing so the eye is drawn to it.
final class CollectibleNode: SKNode {

    static let radius: CGFloat = 11
    /// How close the drawing tip must come to eat it — a touch bigger than the body, so a
    /// near-miss still feels like a catch rather than a tease.
    static let collectRadius: CGFloat = 20

    /// Points awarded for eating this pip.
    static let value = 250

    private static let gold = SKColor(hex: "#ffd24a")

    override init() {
        super.init()

        let glow = SKShapeNode(circleOfRadius: Self.radius * 2.1)
        glow.fillColor = Self.gold.withAlphaComponent(0.22)
        glow.strokeColor = .clear
        glow.blendMode = .add
        addChild(glow)

        let body = SKShapeNode(circleOfRadius: Self.radius)
        body.fillColor = Self.gold
        body.strokeColor = .clear
        addChild(body)

        // A bright highlight, up and to the left, so the orb reads as round and glossy.
        let shine = SKShapeNode(circleOfRadius: Self.radius * 0.34)
        shine.fillColor = .white
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -Self.radius * 0.32, y: Self.radius * 0.32)
        shine.alpha = 0.9
        addChild(shine)

        // Alive: a soft breathing pulse and a slow bob so it never sits dead on the board.
        run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.6),
                                      .scale(to: 1.0, duration: 0.6)])))
        run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.9),
                                      .moveBy(x: 0, y: -5, duration: 0.9)])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — nodes are built in code") }

    /// Eat it: a bright pop of sparks, then remove. The reward feedback lives here so every
    /// caller pops the same way.
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
        pop.particleColor = Self.gold
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
