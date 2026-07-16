import Foundation
import CoreGraphics

enum GeometryHelpers {

    /// Cross product of vectors (b−a) × (c−a)
    static func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    /// True if point c lies on segment [a,b], assuming the three points are collinear
    static func onSegment(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
        min(a.x, b.x) <= c.x && c.x <= max(a.x, b.x) &&
        min(a.y, b.y) <= c.y && c.y <= max(a.y, b.y)
    }

    /// True if segment [p1,p2] intersects segment [p3,p4]
    static func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint,
                                  _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        let d1 = cross(p3, p4, p1)
        let d2 = cross(p3, p4, p2)
        let d3 = cross(p1, p2, p3)
        let d4 = cross(p1, p2, p4)
        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
           ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) { return true }
        if d1 == 0 && onSegment(p3, p4, p1) { return true }
        if d2 == 0 && onSegment(p3, p4, p2) { return true }
        if d3 == 0 && onSegment(p1, p2, p3) { return true }
        if d4 == 0 && onSegment(p1, p2, p4) { return true }
        return false
    }

    /// Euclidean distance between two points
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }

    /// True if point lies within a circle
    static func pointInCircle(_ point: CGPoint, center: CGPoint, radius: CGFloat) -> Bool {
        distance(point, center) <= radius
    }

    /// True if point lies within an axis-aligned rect expanded by `margin` on each side
    static func pointInRect(_ point: CGPoint, rect: CGRect, margin: CGFloat = 0) -> Bool {
        rect.insetBy(dx: -margin, dy: -margin).contains(point)
    }

    /// Shortest distance from `point` to the segment [a,b].
    static func distanceToSegment(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return distance(point, a) }
        var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq
        t = max(0, min(1, t))
        return distance(point, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }
}
