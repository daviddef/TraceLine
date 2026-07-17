import SpriteKit

/// A shelter drawn on the board. Reads as a place rather than an obstacle: soft fill,
/// clear edge, and it sits under the line so the player's own path stays legible on top.
final class SafeZoneNode: SKNode {

    init(zone: SafeZone, theme: Theme) {
        super.init()
        position = zone.center

        let fill = SKShapeNode(circleOfRadius: zone.radius)
        fill.fillColor = theme.hudAccentColor.withAlphaComponent(0.18)
        fill.strokeColor = theme.hudAccentColor.withAlphaComponent(0.75)
        fill.lineWidth = 2
        addChild(fill)

        // A slow breath, so it reads as alive and safe rather than as another hazard.
        let halo = SKShapeNode(circleOfRadius: zone.radius)
        halo.fillColor = .clear
        halo.strokeColor = theme.hudAccentColor.withAlphaComponent(0.25)
        halo.lineWidth = 3
        addChild(halo)
        halo.run(.repeatForever(.sequence([
            .group([.scale(to: 1.06, duration: 1.6), .fadeAlpha(to: 0.15, duration: 1.6)]),
            .group([.scale(to: 1.0, duration: 1.6), .fadeAlpha(to: 0.5, duration: 1.6)]),
        ])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used — scenes are built in code") }
}
