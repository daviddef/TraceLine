import SpriteKit

/// The faint background grid. Purely cosmetic, but it is drawn on the same cell
/// divisions the coverage calculation uses, so what the player sees matches what
/// the coverage bar is actually measuring.
final class GridNode: SKNode {

    init(theme: Theme, playRect: CGRect, gridSize: Int) {
        super.init()

        let path = CGMutablePath()
        let cellW = playRect.width  / CGFloat(gridSize)
        let cellH = playRect.height / CGFloat(gridSize)

        for i in 0...gridSize {
            let x = playRect.minX + CGFloat(i) * cellW
            path.move(to: CGPoint(x: x, y: playRect.minY))
            path.addLine(to: CGPoint(x: x, y: playRect.maxY))

            let y = playRect.minY + CGFloat(i) * cellH
            path.move(to: CGPoint(x: playRect.minX, y: y))
            path.addLine(to: CGPoint(x: playRect.maxX, y: y))
        }

        let grid = SKShapeNode(path: path)
        grid.strokeColor = theme.gridColor
        grid.lineWidth = 1
        grid.isAntialiased = false
        addChild(grid)

        // A slightly stronger border marks where the playable area ends.
        let border = SKShapeNode(rect: playRect, cornerRadius: 12)
        border.strokeColor = theme.gridColor
        border.lineWidth = 2
        border.fillColor = .clear
        addChild(border)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }
}
