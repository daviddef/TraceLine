import CoreGraphics

/// A shelter on the board. Hazards rebound off it, so a line drawn inside cannot be
/// reached — hiding costs you the clock, not your line.
///
/// Zones are placed by level design rather than earned. Territory cannot be claimed the
/// way Qix does it: sealing a region means touching your own line, and touching your own
/// line is a crossing, which ends the round. Enclosing anything is structurally illegal
/// here, so shelters have to be part of the board.
///
/// Kept free of SpriteKit so the geometry stays testable alongside DrawingEngine.
struct SafeZone {
    let center: CGPoint
    let radius: CGFloat

    func contains(_ point: CGPoint) -> Bool {
        GeometryHelpers.distance(point, center) <= radius
    }

    /// True only when the whole segment is inside. A segment straddling the edge is
    /// deliberately *not* sheltered — the part sticking out is exposed, and it should be
    /// treated that way.
    func shelters(from a: CGPoint, to b: CGPoint) -> Bool {
        contains(a) && contains(b)
    }

    /// Where a horizontal lane at `y` is blocked, as an x range, or nil if the lane
    /// passes clear. A cutter cannot enter a zone, so this is what casts the shadow that
    /// makes the far side of the lane safe.
    func laneBlock(atY y: CGFloat, halfHeight: CGFloat) -> ClosedRange<CGFloat>? {
        let dy = abs(y - center.y)
        let reach = radius + halfHeight
        guard dy < reach else { return nil }
        let halfSpan = (reach * reach - dy * dy).squareRoot()
        return (center.x - halfSpan)...(center.x + halfSpan)
    }
}

/// Normalised placement, so a zone sits in the same spot on every screen size.
/// x and y are fractions of the play area; radius is a fraction of its width.
struct SafeZoneConfig: Codable, Equatable {
    let x: Float
    let y: Float
    let radius: Float

    func resolved(in playRect: CGRect) -> SafeZone {
        SafeZone(
            center: CGPoint(x: playRect.minX + CGFloat(x) * playRect.width,
                            y: playRect.minY + CGFloat(y) * playRect.height),
            radius: CGFloat(radius) * playRect.width
        )
    }
}
