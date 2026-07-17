import CoreGraphics

/// Minimum distance (pts) between consecutive recorded points.
/// Keeps the array small; anything closer is ignored.
private let MIN_POINT_SPACING: CGFloat = 4

/// How close the tip must come to an obstacle before counting as a near-miss.
let NEAR_MISS_THRESHOLD: CGFloat = 20

/// Owns the recorded path and every drawing rule check.
/// Deliberately free of SpriteKit so it can be reasoned about (and tested) in isolation.
final class DrawingEngine {

    // MARK: - Public state
    private(set) var points: [CGPoint] = []
    private(set) var totalDistance: CGFloat = 0
    private(set) var nearMissCount: Int = 0

    var pointCount: Int { points.count }
    var currentTip: CGPoint? { points.last }

    /// Obstacle ids currently inside the near-miss radius, so one slow pass
    /// counts as a single near-miss rather than one per recorded point.
    private var obstaclesInNearMissZone: Set<Int> = []

    // MARK: - Start / reset
    func begin(at point: CGPoint) {
        points = [point]
        totalDistance = 0
        nearMissCount = 0
        obstaclesInNearMissZone.removeAll()
    }

    // MARK: - Extend line
    /// Call from touchesMoved. If the result is not `.ok`, stop drawing and fail the round.
    ///
    /// The point the player asks for is not necessarily the point that gets drawn: magnets
    /// bend it on the way in. Everything downstream — crossing, collision, coverage —
    /// uses the deflected point, because that is where the line actually went.
    func extend(to requested: CGPoint, obstacles: [ObstacleDescriptor]) -> DrawResult {
        guard let last = points.last else { return .ok }
        let newPoint = pulled(requested, obstacles: obstacles)
        let d = GeometryHelpers.distance(last, newPoint)
        guard d >= MIN_POINT_SPACING else { return .ok }

        // 1. Self-crossing
        if wouldCross(newPoint: newPoint) { return .fail(.lineCrossed) }

        // 2. Obstacle collision — test the whole proposed segment, not just its
        //    endpoint, so a fast flick can't tunnel straight through an obstacle.
        for obs in obstacles where !obs.severs && obs.intersectsSegment(from: last, to: newPoint) {
            return .fail(.obstacleHit)
        }

        // 3. Near-misses (no fail, just counted for the 3-star check)
        updateNearMisses(at: newPoint, obstacles: obstacles)

        // All clear — record the point
        points.append(newPoint)
        totalDistance += d
        return .ok
    }

    /// Obstacles fall onto a stationary finger too, so the tip needs a collision
    /// check every frame and not only when the player moves.
    func checkTipCollision(obstacles: [ObstacleDescriptor]) -> DrawResult {
        guard let tip = points.last else { return .ok }
        for obs in obstacles where !obs.severs && obs.contains(tip) { return .fail(.obstacleHit) }
        updateNearMisses(at: tip, obstacles: obstacles)
        return .ok
    }

    /// Bends a point toward any magnet in range. Strongest up close and zero at the edge
    /// of the field, so the pull has a visible boundary rather than reaching out of
    /// nowhere.
    ///
    /// This is what makes a magnet dangerous: it can drag the line into the magnet itself,
    /// or — far worse — into the path you have already drawn, which is a crossing and ends
    /// the round. Your own line remains the real hazard.
    func pulled(_ point: CGPoint, obstacles: [ObstacleDescriptor]) -> CGPoint {
        var p = point
        for obs in obstacles where obs.pull > 0 && obs.pullRadius > 0 {
            guard case .circle(let centre, _) = obs.shape else { continue }
            let d = GeometryHelpers.distance(p, centre)
            guard d < obs.pullRadius, d > 0.001 else { continue }
            let falloff = 1 - d / obs.pullRadius
            let step = min(obs.pull * falloff, d)      // never overshoot the centre
            p = CGPoint(x: p.x + (centre.x - p.x) / d * step,
                        y: p.y + (centre.y - p.y) / d * step)
        }
        return p
    }

    // MARK: - Cutting
    /// Severs the path wherever `hits` reports a crossing, keeping only the piece still
    /// attached to the drawing tip and discarding everything beyond the cut.
    ///
    /// The last crossing is the one that matters: with several cuts, the only surviving
    /// piece is the one after the final one, because that is the piece the finger is
    /// still holding.
    ///
    /// `totalDistance` is deliberately left alone — the player really did draw that far,
    /// and the score is a record of effort. The punishment lands on coverage, which is
    /// recomputed from `points` and so retracts on its own.
    /// Index of the last segment `hits` reports a crossing on, or nil for no crossing.
    ///
    /// Shared by `cut` and by the doomed-tail preview, so what the player is warned
    /// about and what they actually lose are computed the same way and cannot drift.
    func severIndex(where hits: (CGPoint, CGPoint) -> Bool) -> Int? {
        guard points.count >= 2 else { return nil }
        var last: Int?
        for i in 0..<(points.count - 1) where hits(points[i], points[i + 1]) {
            last = i
        }
        return last
    }

    /// Number of leading points that would be lost to a cut at `severIndex`.
    func doomedCount(where hits: (CGPoint, CGPoint) -> Bool) -> Int {
        guard let index = severIndex(where: hits) else { return 0 }
        return index + 1
    }

    @discardableResult
    func cut(where hits: (CGPoint, CGPoint) -> Bool) -> Bool {
        guard let cut = severIndex(where: hits) else { return false }

        let survivors = Array(points[(cut + 1)...])
        // Always keep the tip: the finger is still down, and drawing has to continue
        // from somewhere.
        points = survivors.isEmpty ? [points[points.count - 1]] : survivors
        return true
    }

    private func updateNearMisses(at point: CGPoint, obstacles: [ObstacleDescriptor]) {
        var stillNear: Set<Int> = []
        for obs in obstacles where obs.distanceTo(point) < NEAR_MISS_THRESHOLD {
            stillNear.insert(obs.id)
            if !obstaclesInNearMissZone.contains(obs.id) { nearMissCount += 1 }
        }
        obstaclesInNearMissZone = stillNear
    }

    // MARK: - Coverage calculation
    /// Divides `playRect` into gridSize×gridSize cells and returns the fraction of
    /// cells the path passes through. Cells are walked along each segment rather than
    /// sampled at vertices only, so a long straight run fills every cell it crosses.
    func coveragePercent(in playRect: CGRect, gridSize: Int = 20) -> Float {
        guard points.count > 1, gridSize > 0 else { return 0 }
        let cellW = playRect.width  / CGFloat(gridSize)
        let cellH = playRect.height / CGFloat(gridSize)
        var occupied = Set<Int>()

        func mark(_ p: CGPoint) {
            let col = Int((p.x - playRect.minX) / cellW)
            let row = Int((p.y - playRect.minY) / cellH)
            guard col >= 0, col < gridSize, row >= 0, row < gridSize else { return }
            occupied.insert(row * gridSize + col)
        }

        mark(points[0])
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let steps = max(1, Int(GeometryHelpers.distance(a, b) / min(cellW, cellH) * 2))
            for s in 1...steps {
                let t = CGFloat(s) / CGFloat(steps)
                mark(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return Float(occupied.count) / Float(gridSize * gridSize)
    }

    // MARK: - Self-crossing check
    /// True if a segment from the last recorded point to `newPoint` would intersect
    /// any prior segment. The immediately preceding segment is skipped: it shares an
    /// endpoint with the new one and would always report an intersection.
    private func wouldCross(newPoint: CGPoint) -> Bool {
        let n = points.count
        guard n >= 2 else { return false }
        let a = points[n - 1]
        for i in 0..<(n - 2) {
            if GeometryHelpers.segmentsIntersect(a, newPoint, points[i], points[i + 1]) {
                return true
            }
        }
        return false
    }
}

// MARK: - Supporting types

enum DrawResult: Equatable {
    case ok
    case fail(FailReason)
}

/// A lightweight description of an obstacle's position and hit zone.
/// ObstacleNode produces one of these each frame, keeping DrawingEngine
/// free of any SpriteKit dependency.
struct ObstacleDescriptor {
    enum Shape {
        case circle(center: CGPoint, radius: CGFloat)
        case rect(CGRect)
    }
    /// Identity of the originating node, so near-misses can be de-duplicated per obstacle.
    let id: Int
    let shape: Shape
    /// True for cutters: they sever the line rather than ending the round.
    var severs: Bool = false

    /// Magnets only: how hard the line is bent per recorded point, and how far the field
    /// reaches. Zero for everything else.
    var pull: CGFloat = 0
    var pullRadius: CGFloat = 0

    /// Hit zones are padded by the line's half-width plus a small forgiveness margin.
    private static let padding: CGFloat = 6

    func contains(_ point: CGPoint) -> Bool {
        switch shape {
        case .circle(let c, let r):
            return GeometryHelpers.pointInCircle(point, center: c, radius: r + Self.padding)
        case .rect(let r):
            return GeometryHelpers.pointInRect(point, rect: r, margin: Self.padding)
        }
    }

    /// True if the segment [a,b] touches the hit zone at any point along its length.
    func intersectsSegment(from a: CGPoint, to b: CGPoint) -> Bool {
        switch shape {
        case .circle(let c, let r):
            return GeometryHelpers.distanceToSegment(c, a, b) <= r + Self.padding
        case .rect(let r):
            let padded = r.insetBy(dx: -Self.padding, dy: -Self.padding)
            if padded.contains(a) || padded.contains(b) { return true }
            let corners = [
                CGPoint(x: padded.minX, y: padded.minY), CGPoint(x: padded.maxX, y: padded.minY),
                CGPoint(x: padded.maxX, y: padded.maxY), CGPoint(x: padded.minX, y: padded.maxY),
            ]
            for i in 0..<4 {
                if GeometryHelpers.segmentsIntersect(a, b, corners[i], corners[(i + 1) % 4]) {
                    return true
                }
            }
            return false
        }
    }

    func distanceTo(_ point: CGPoint) -> CGFloat {
        switch shape {
        case .circle(let c, let r):
            return max(0, GeometryHelpers.distance(point, c) - r)
        case .rect(let r):
            let dx = max(r.minX - point.x, 0, point.x - r.maxX)
            let dy = max(r.minY - point.y, 0, point.y - r.maxY)
            return sqrt(dx * dx + dy * dy)
        }
    }
}
