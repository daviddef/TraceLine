import SpriteKit

/// World 4's darkness. A near-opaque veil over the whole board with a soft torch that
/// follows the drawing tip — so hazards lurk unseen until your light reaches them.
///
/// The player's own line is drawn *above* this node (a higher zPosition), so it stays
/// self-lit like the neon it is: you always see where you have been, you just cannot see
/// what is waiting in the dark ahead.
///
/// Two layers make the torch read as light rather than a bald cut-out:
///   1. A crop-masked veil with a soft transparent hole — this is what actually reveals
///      the board beneath. The mask just moves each frame; nothing is re-rendered.
///   2. A warm additive glow over the revealed patch, so it looks illuminated.
final class DarknessNode: SKNode {

    private let mask = SKSpriteNode()
    private let glow = SKSpriteNode()

    init(sceneSize: CGSize, theme: Theme, torchRadius: CGFloat = 104) {
        super.init()

        // --- The veil, with a hole cropped out of it -------------------------------------
        let crop = SKCropNode()

        // A solid sheet a touch darker than the theme's own background, so the board reads
        // as "lights out" rather than a flat black rectangle. Sized past the scene edges so
        // there is no seam at the play-area border.
        let veil = SKSpriteNode(color: Self.veilColour(for: theme),
                                size: CGSize(width: sceneSize.width * 1.1,
                                             height: sceneSize.height * 1.1))
        crop.addChild(veil)

        // The mask must blanket the whole veil with its opaque region wherever the hole
        // sits. Worst case the tip is at one veil corner and the mask still has to reach
        // the opposite corner, so it spans twice the veil's diagonal (square, so direction
        // does not matter).
        let diagonal = (veil.size.width * veil.size.width
                        + veil.size.height * veil.size.height).squareRoot()
        let side = diagonal * 2 + torchRadius * 2
        let pointSize = CGSize(width: side, height: side)
        mask.texture = Self.holeTexture(pointSize: pointSize, holeRadius: torchRadius)
        mask.size = pointSize
        crop.maskNode = mask
        addChild(crop)

        // --- The warm light cast over the revealed patch --------------------------------
        glow.texture = LineNode.softDot                     // a soft white radial
        glow.size = CGSize(width: torchRadius * 2.6, height: torchRadius * 2.6)
        glow.color = SKColor(hex: "#ffe9b8")                // a warm torch tone
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.32
        addChild(glow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — nodes are built in code") }

    /// Move the torch to follow the drawing tip. Call each frame.
    func moveTorch(to point: CGPoint) {
        mask.position = point
        glow.position = point
    }

    private static func veilColour(for theme: Theme) -> SKColor {
        // Darken the theme background toward black and hold it just shy of full alpha —
        // pitch black feels broken, but it must be opaque enough that a hazard in the dark
        // is genuinely hidden, not merely dimmed.
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        theme.background.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: r * 0.2, green: g * 0.2, blue: b * 0.2, alpha: 0.965)
    }

    /// An opaque field with a soft-edged transparent circle punched in the middle. The
    /// hole is where the board shows through; everything else stays dark.
    ///
    /// Rendered at a deliberately low pixel resolution — the mask is huge in points but a
    /// soft blur has no fine detail to lose, and SpriteKit scales the small texture up
    /// smoothly. Rendering it at native scale would be a hundreds-of-megabytes image.
    private static func holeTexture(pointSize: CGSize, holeRadius: CGFloat) -> SKTexture {
        // Cap the longest edge to a few hundred texels; the hole scales with it.
        let targetPx: CGFloat = 400
        let scale = targetPx / max(pointSize.width, pointSize.height)
        let pxSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        let holePx = holeRadius * scale

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: pxSize, format: format)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(origin: .zero, size: pxSize))

            // Punch the hole: destinationOut multiplies existing alpha by (1 − source
            // alpha), so an opaque-centre gradient erases the middle and feathers the rim.
            c.setBlendMode(.destinationOut)
            let mid = CGPoint(x: pxSize.width / 2, y: pxSize.height / 2)
            let colours = [UIColor.white.cgColor,                       // erases fully
                           UIColor.white.withAlphaComponent(0).cgColor] // leaves opaque
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colours as CFArray,
                                            locations: [0, 1]) else { return }
            // Fully clear out to ~70% of the radius, then a short feather to the edge, so
            // what the torch lands on is bright rather than half-veiled.
            c.drawRadialGradient(gradient, startCenter: mid, startRadius: holePx * 0.7,
                                 endCenter: mid, endRadius: holePx, options: [])
        }
        return SKTexture(image: image)
    }
}
