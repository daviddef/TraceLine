import SpriteKit

/// CRT scanlines for the retro theme, per HANDOVER's theme table.
///
/// Sits below the HUD deliberately: `atPoint(_:)` returns the topmost node, and an
/// overlay above the HUD would swallow the pause button.
final class ScanlineNode: SKNode {

    init(size: CGSize) {
        super.init()

        let path = CGMutablePath()
        var y = -size.height / 2
        while y < size.height / 2 {
            path.move(to: CGPoint(x: -size.width / 2, y: y))
            path.addLine(to: CGPoint(x: size.width / 2, y: y))
            y += 3
        }

        let lines = SKShapeNode(path: path)
        lines.strokeColor = .black
        lines.alpha = 0.22
        lines.lineWidth = 1
        lines.isAntialiased = false
        addChild(lines)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }
}
