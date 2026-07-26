import SpriteKit

/// Depth behind the play area: a soft vignette that darkens the edges, and a field of
/// slow-drifting motes. Purely atmospheric — it sits below the grid and never interacts
/// with anything. It lifts every screen at once, which is the cheapest kind of "better
/// graphics" there is.
///
/// Theme-aware: on a dark theme the motes glow faintly light; on a light theme they read
/// as soft dark flecks, so the effect never washes out.
final class BackgroundNode: SKNode {

    init(theme: Theme, size: CGSize) {
        super.init()
        zPosition = -10

        addVignette(theme: theme, size: size)
        addMotes(theme: theme, size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    /// A radial darkening toward the edges, giving the flat background a centre of focus.
    private func addVignette(theme: Theme, size: CGSize) {
        let texture = Self.radialTexture(edge: Self.vignetteEdgeColour(for: theme))
        let vignette = SKSpriteNode(texture: texture)
        vignette.size = CGSize(width: size.width * 1.1, height: size.height * 1.1)
        vignette.blendMode = .alpha
        vignette.zPosition = -1
        addChild(vignette)
    }

    /// Slow, faint motes drifting upward — the sense of a living space rather than a void.
    private func addMotes(theme: Theme, size: CGSize) {
        let bright = Self.isDark(theme.background)
        let colour = bright ? theme.lineColor : SKColor.black
        let baseAlpha: CGFloat = bright ? 0.14 : 0.06

        for _ in 0..<26 {
            let r = CGFloat.random(in: 1.5...4)
            let mote = SKShapeNode(circleOfRadius: r)
            mote.fillColor = colour
            mote.strokeColor = .clear
            mote.alpha = 0
            mote.position = CGPoint(x: .random(in: -size.width / 2 ... size.width / 2),
                                    y: .random(in: -size.height / 2 ... size.height / 2))
            addChild(mote)

            let drift = CGFloat.random(in: 30...70)
            let dur = Double.random(in: 6...12)
            let peak = baseAlpha * CGFloat.random(in: 0.6...1.4)
            mote.run(.repeatForever(.sequence([
                .group([.moveBy(x: .random(in: -12...12), y: drift, duration: dur),
                        .sequence([.fadeAlpha(to: peak, duration: dur * 0.4),
                                   .fadeAlpha(to: 0, duration: dur * 0.6)])]),
                .run { [weak mote] in
                    mote?.position = CGPoint(x: .random(in: -size.width / 2 ... size.width / 2),
                                             y: -size.height / 2 - 10)
                },
            ])), withKey: "drift")
        }
    }

    // MARK: - Helpers

    private static func isDark(_ colour: SKColor) -> Bool {
        var w: CGFloat = 0, a: CGFloat = 0
        colour.getWhite(&w, alpha: &a)
        return w < 0.5
    }

    private static func vignetteEdgeColour(for theme: Theme) -> SKColor {
        // Darken dark themes further; on light themes a barely-there warm shadow.
        isDark(theme.background) ? SKColor.black.withAlphaComponent(0.55)
                                 : SKColor.black.withAlphaComponent(0.08)
    }

    /// A transparent-centre, coloured-edge radial gradient, built once as a texture.
    private static func radialTexture(edge: SKColor) -> SKTexture {
        let side = 512
        let size = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colours = [SKColor.clear.cgColor, edge.cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colours as CFArray,
                                            locations: [0.45, 1.0]) else { return }
            let mid = CGPoint(x: size.width / 2, y: size.height / 2)
            c.drawRadialGradient(gradient, startCenter: mid, startRadius: 0,
                                 endCenter: mid, endRadius: size.width * 0.72, options: [])
        }
        return SKTexture(image: image)
    }
}
