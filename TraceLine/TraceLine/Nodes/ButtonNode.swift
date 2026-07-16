import SpriteKit

/// A rounded button drawn in code. Every child carries the same `name` so that
/// `atPoint(_:)`, which returns the deepest node under the touch, reports the
/// button's identity no matter whether the label or the background was hit.
final class ButtonNode: SKNode {

    private let background: SKShapeNode
    private let label: SKLabelNode

    init(title: String,
         theme: Theme,
         name: String,
         position: CGPoint,
         isPrimary: Bool = true,
         size: CGSize = CGSize(width: 220, height: 54)) {

        background = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
        label = SKLabelNode(fontNamed: Fonts.display(for: theme))
        super.init()

        background.fillColor = isPrimary ? theme.hudAccentColor : .clear
        background.strokeColor = isPrimary ? .clear : theme.hudTextColor.withAlphaComponent(0.3)
        background.lineWidth = 2
        background.name = name
        addChild(background)

        label.text = title
        label.fontSize = 18
        label.fontColor = isPrimary ? contrastingText(on: theme) : theme.hudTextColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        addChild(label)

        self.name = name
        self.position = position
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }

    /// Light themes need dark label text on an accent-filled button, and vice versa.
    private func contrastingText(on theme: Theme) -> SKColor {
        var white: CGFloat = 0, alpha: CGFloat = 0
        theme.hudAccentColor.getWhite(&white, alpha: &alpha)
        return white > 0.6 ? SKColor(hex: "#111111") : .white
    }

    /// A brief press-in, for touch feedback.
    func flash() {
        run(.sequence([.scale(to: 0.95, duration: 0.06), .scale(to: 1.0, duration: 0.06)]))
    }
}
