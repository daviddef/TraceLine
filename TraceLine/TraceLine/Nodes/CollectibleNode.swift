import SpriteKit

/// A collectible you route your line through to eat. Contact is a hazard *inverted* — it
/// is good — so it wears no hazard colour. Kinds so far:
///   - `.pip`    — a gold orb worth bonus points.
///   - `.shield` — green: deflects the next object that hits the line.
///   - `.freeze` — cyan: slows the clock and every moving hazard for a few seconds.
///   - `.ghost`  — purple: the line passes through itself and hazards for a few seconds.
final class CollectibleNode: SKNode {

    enum Kind { case pip, shield, freeze, ghost }

    let kind: Kind

    static let radius: CGFloat = 11
    /// How close the drawing tip must come to eat it — a touch bigger than the body, so a
    /// near-miss still feels like a catch rather than a tease.
    static let collectRadius: CGFloat = 20
    static let pipValue = 250
    static let powerUpValue = 100

    /// Points banked for eating this one (a power-up's real reward is its effect).
    var value: Int { kind == .pip ? Self.pipValue : Self.powerUpValue }

    static func tint(for kind: Kind) -> SKColor {
        switch kind {
        case .pip:    return SKColor(hex: "#ffd24a")
        case .shield: return SKColor(hex: "#34d399")
        case .freeze: return SKColor(hex: "#38bdf8")
        case .ghost:  return SKColor(hex: "#c084fc")
        }
    }

    private var tint: SKColor { Self.tint(for: kind) }

    init(kind: Kind = .pip) {
        self.kind = kind
        super.init()
        let tint = Self.tint(for: kind)

        let glow = SKShapeNode(circleOfRadius: Self.radius * 2.1)
        glow.fillColor = tint.withAlphaComponent(0.22)
        glow.strokeColor = .clear
        glow.blendMode = .add
        addChild(glow)

        let body = SKShapeNode(circleOfRadius: Self.radius)
        body.fillColor = tint
        body.strokeColor = .clear
        // Ghost reads as ghostly — a translucent body.
        body.alpha = kind == .ghost ? 0.55 : 1
        addChild(body)

        // A ring marks a power-up as more than points. Ghost skips it (it stays wispy).
        if kind == .shield || kind == .freeze {
            let ring = SKShapeNode(circleOfRadius: Self.radius * 1.5)
            ring.strokeColor = tint
            ring.lineWidth = 2
            ring.fillColor = .clear
            ring.alpha = 0.7
            addChild(ring)
            ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.6),
                                               .fadeAlpha(to: 0.7, duration: 0.6)])))
        }

        if kind != .ghost {
            let shine = SKShapeNode(circleOfRadius: Self.radius * 0.34)
            shine.fillColor = .white
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -Self.radius * 0.32, y: Self.radius * 0.32)
            shine.alpha = 0.9
            addChild(shine)
        }

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
