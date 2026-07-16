# TraceLine — Swift Architecture Specification

> Read `HANDOVER.md` first for project overview, game rules, and setup instructions.
> This document specifies every Swift file: its purpose, types, properties, and key methods.
> Build files in the order listed in HANDOVER.md § "File Delivery".

---

## Project Structure

```
TraceLine/
├── App/
│   ├── AppDelegate.swift
│   └── GameViewController.swift
├── Core/
│   ├── Theme.swift
│   ├── GameState.swift
│   ├── DrawingEngine.swift
│   └── GeometryHelpers.swift
├── Models/
│   ├── LevelConfig.swift
│   ├── RoundScore.swift
│   └── PlayerProgress.swift
├── Nodes/
│   ├── ObstacleNode.swift
│   ├── HUDNode.swift
│   ├── LineNode.swift
│   └── GridNode.swift
├── Scenes/
│   ├── HomeScene.swift
│   ├── LevelSelectScene.swift
│   ├── GameScene.swift
│   ├── GameOverScene.swift
│   ├── WinScene.swift
│   └── ThemeSelectScene.swift
├── Resources/
│   ├── levels.json
│   └── (no image assets in v1 — all drawn in code)
└── Extensions/
    ├── CGPoint+Extensions.swift
    └── SKAction+Extensions.swift
```

---

## 1. `GeometryHelpers.swift`

Pure geometry functions. No SpriteKit imports needed — import only Foundation.

```swift
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

    /// True if segment [p1,p2] properly intersects segment [p3,p4]
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
        sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2))
    }

    /// True if point lies within a circle
    static func pointInCircle(_ point: CGPoint, center: CGPoint, radius: CGFloat) -> Bool {
        distance(point, center) <= radius
    }

    /// True if point lies within an axis-aligned rect expanded by `margin` on each side
    static func pointInRect(_ point: CGPoint, rect: CGRect, margin: CGFloat = 0) -> Bool {
        rect.insetBy(dx: -margin, dy: -margin).contains(point)
    }
}
```

---

## 2. `Theme.swift`

```swift
import SpriteKit

enum ThemeKey: String, CaseIterable, Codable {
    case neon, clay, retro, watercolour
}

struct Theme {
    let key: ThemeKey
    let displayName: String

    // Colours
    let background: SKColor
    let lineColor: SKColor
    let lineShadowColor: SKColor     // glow colour (neon) or shadow (clay)
    let obstacleColors: [SKColor]    // index matches ObstacleType rawValue
    let hudTextColor: SKColor
    let hudAccentColor: SKColor
    let gridColor: SKColor

    // Line style
    let lineWidth: CGFloat           // 4 = neon/retro, 6 = clay, 3 = watercolour
    let lineGlowWidth: CGFloat       // 0 for non-neon themes
    let lineAlpha: CGFloat           // 1.0 except watercolour = 0.85
    let lineCap: String              // "round" for all themes
    let pixelated: Bool              // true for retro only

    // Obstacle style
    let obstacleGlow: Bool           // true for neon/retro only

    static let neon = Theme(
        key: .neon,
        displayName: "Neon",
        background: SKColor(hex: "#0d0d1a"),
        lineColor: SKColor(hex: "#6366f1"),
        lineShadowColor: SKColor(hex: "#6366f1").withAlphaComponent(0.8),
        obstacleColors: [
            SKColor(hex: "#ec4899"),  // Blocker
            SKColor(hex: "#facc15"),  // Mover
            SKColor(hex: "#a78bfa"),  // Magnetic
            SKColor(hex: "#f97316"),  // Shrinker
        ],
        hudTextColor: .white,
        hudAccentColor: SKColor(hex: "#6366f1"),
        gridColor: SKColor.white.withAlphaComponent(0.04),
        lineWidth: 4,
        lineGlowWidth: 12,
        lineAlpha: 1.0,
        lineCap: "round",
        pixelated: false,
        obstacleGlow: true
    )

    static let clay = Theme(
        key: .clay,
        displayName: "Clay",
        background: SKColor(hex: "#fef9f0"),
        lineColor: SKColor(hex: "#f97316"),
        lineShadowColor: SKColor(hex: "#c2410c").withAlphaComponent(0.3),
        obstacleColors: [
            SKColor(hex: "#84cc16"),
            SKColor(hex: "#06b6d4"),
            SKColor(hex: "#a78bfa"),
            SKColor(hex: "#ec4899"),
        ],
        hudTextColor: SKColor(hex: "#1c1917"),
        hudAccentColor: SKColor(hex: "#f97316"),
        gridColor: SKColor.black.withAlphaComponent(0.05),
        lineWidth: 6,
        lineGlowWidth: 0,
        lineAlpha: 1.0,
        lineCap: "round",
        pixelated: false,
        obstacleGlow: false
    )

    static let retro = Theme(
        key: .retro,
        displayName: "Retro",
        background: SKColor(hex: "#020f02"),
        lineColor: SKColor(hex: "#22c55e"),
        lineShadowColor: SKColor(hex: "#22c55e").withAlphaComponent(0.9),
        obstacleColors: [
            SKColor(hex: "#facc15"),
            SKColor(hex: "#f97316"),
            SKColor(hex: "#60a5fa"),
            SKColor(hex: "#ec4899"),
        ],
        hudTextColor: SKColor(hex: "#22c55e"),
        hudAccentColor: SKColor(hex: "#22c55e"),
        gridColor: SKColor(hex: "#22c55e").withAlphaComponent(0.07),
        lineWidth: 4,
        lineGlowWidth: 14,
        lineAlpha: 1.0,
        lineCap: "round",  // swap to "square" for more retro feel
        pixelated: true,
        obstacleGlow: true
    )

    static let watercolour = Theme(
        key: .watercolour,
        displayName: "Watercolour",
        background: SKColor(hex: "#f0f9ff"),
        lineColor: SKColor(hex: "#06b6d4"),
        lineShadowColor: SKColor(hex: "#0891b2").withAlphaComponent(0.25),
        obstacleColors: [
            SKColor(hex: "#a78bfa"),
            SKColor(hex: "#f97316"),
            SKColor(hex: "#ec4899"),
            SKColor(hex: "#84cc16"),
        ],
        hudTextColor: SKColor(hex: "#0c4a6e"),
        hudAccentColor: SKColor(hex: "#06b6d4"),
        gridColor: SKColor.black.withAlphaComponent(0.04),
        lineWidth: 5,
        lineGlowWidth: 0,
        lineAlpha: 0.85,
        lineCap: "round",
        pixelated: false,
        obstacleGlow: false
    )

    static func theme(for key: ThemeKey) -> Theme {
        switch key {
        case .neon:        return .neon
        case .clay:        return .clay
        case .retro:       return .retro
        case .watercolour: return .watercolour
        }
    }
}

// MARK: - SKColor hex initialiser
extension SKColor {
    convenience init(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >>  8) & 0xFF) / 255
        let b = CGFloat((rgb      ) & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
```

---

## 3. `GameState.swift`

```swift
import Foundation

// All possible states the game can be in
enum GamePhase: Equatable {
    case idle           // waiting for first touch
    case drawing        // player has finger down, line extending
    case paused         // pause overlay shown
    case failFlash      // 0.5s red flash before transitioning to game-over
    case levelComplete  // coverage target hit, showing win animation
}

// The three reasons a round can end in failure
enum FailReason {
    case fingerLifted
    case lineCrossed
    case obstacleHit
    case timeExpired
    var displayText: String {
        switch self {
        case .fingerLifted: return "💥 Finger lifted"
        case .lineCrossed:  return "🚫 Line crossed itself"
        case .obstacleHit:  return "⛔ Hit an obstacle"
        case .timeExpired:  return "⏱ Time's up"
        }
    }
}

// Centralised state machine — owned by GameScene, observed via delegate
final class GameStateMachine {
    private(set) var phase: GamePhase = .idle
    private(set) var failReason: FailReason?
    weak var delegate: GameStateMachineDelegate?

    func transition(to newPhase: GamePhase, failReason: FailReason? = nil) {
        guard newPhase != phase else { return }
        let old = phase
        phase = newPhase
        self.failReason = failReason
        delegate?.stateMachine(self, didTransitionFrom: old, to: newPhase)
    }
}

protocol GameStateMachineDelegate: AnyObject {
    func stateMachine(_ machine: GameStateMachine,
                      didTransitionFrom old: GamePhase,
                      to new: GamePhase)
}
```

---

## 4. `DrawingEngine.swift`

Pure Swift, no SpriteKit. Owns the array of recorded points and all drawing rule checks. `GameScene` calls into this on every touch event and reads `path` to render.

```swift
import CoreGraphics

// Minimum distance (pts) between consecutive recorded points.
// Keeps array small; anything closer is ignored.
private let MIN_POINT_SPACING: CGFloat = 4

// How close the tip must come to an obstacle before counting as a near-miss
let NEAR_MISS_THRESHOLD: CGFloat = 20

final class DrawingEngine {

    // MARK: - Public state
    private(set) var points: [CGPoint] = []
    private(set) var totalDistance: CGFloat = 0
    private(set) var nearMissCount: Int = 0

    var pointCount: Int { points.count }
    var currentTip: CGPoint? { points.last }

    // MARK: - Start / reset
    func begin(at point: CGPoint) {
        points = [point]
        totalDistance = 0
        nearMissCount = 0
    }

    // MARK: - Extend line
    // Returns a DrawResult indicating success or the violation that occurred.
    // Call this in touchesMoved. If result != .ok, stop drawing and trigger fail.
    func extend(to newPoint: CGPoint,
                obstacles: [ObstacleDescriptor]) -> DrawResult {
        guard let last = points.last else { return .ok }
        let d = GeometryHelpers.distance(last, newPoint)
        guard d >= MIN_POINT_SPACING else { return .ok }

        // 1. Check self-crossing
        if wouldCross(newPoint: newPoint) { return .fail(.lineCrossed) }

        // 2. Check obstacle collision
        for obs in obstacles {
            if obs.contains(newPoint) { return .fail(.obstacleHit) }
        }

        // 3. Check near-misses (no fail, just count)
        for obs in obstacles {
            if obs.distanceTo(newPoint) < NEAR_MISS_THRESHOLD {
                nearMissCount += 1
            }
        }

        // All clear — record point
        points.append(newPoint)
        totalDistance += d
        return .ok
    }

    // MARK: - Coverage calculation
    // Divides the playRect into gridSize×gridSize cells.
    // Returns fraction of cells that contain at least one recorded point.
    func coveragePercent(in playRect: CGRect, gridSize: Int = 20) -> Float {
        guard points.count > 1 else { return 0 }
        let cellW = playRect.width  / CGFloat(gridSize)
        let cellH = playRect.height / CGFloat(gridSize)
        var occupied = Set<Int>()
        for p in points {
            let col = Int((p.x - playRect.minX) / cellW)
            let row = Int((p.y - playRect.minY) / cellH)
            let key = row * gridSize + col
            occupied.insert(key)
        }
        return Float(occupied.count) / Float(gridSize * gridSize)
    }

    // MARK: - Self-crossing check (private)
    // Check if a new segment from the last recorded point to newPoint
    // would intersect any prior non-adjacent segment.
    private func wouldCross(newPoint: CGPoint) -> Bool {
        let n = points.count
        guard n >= 2 else { return false }
        let a = points[n - 1]
        // Check against all segments except the immediately previous one
        for i in 0..<(n - 2) {
            if GeometryHelpers.segmentsIntersect(a, newPoint,
                                                  points[i], points[i + 1]) {
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

// A lightweight description of an obstacle's position and hit zone.
// ObstacleNode produces one of these each frame for DrawingEngine to consume.
// Keeps DrawingEngine free of SpriteKit dependency.
struct ObstacleDescriptor {
    enum Shape {
        case circle(center: CGPoint, radius: CGFloat)
        case rect(CGRect)
    }
    let shape: Shape

    func contains(_ point: CGPoint) -> Bool {
        switch shape {
        case .circle(let c, let r):
            return GeometryHelpers.pointInCircle(point, center: c, radius: r + 6)
        case .rect(let r):
            return GeometryHelpers.pointInRect(point, rect: r, margin: 6)
        }
    }

    func distanceTo(_ point: CGPoint) -> CGFloat {
        switch shape {
        case .circle(let c, let r):
            return max(0, GeometryHelpers.distance(point, c) - r)
        case .rect(let r):
            let dx = max(r.minX - point.x, 0, point.x - r.maxX)
            let dy = max(r.minY - point.y, 0, point.y - r.maxY)
            return sqrt(dx*dx + dy*dy)
        }
    }
}
```

---

## 5. `LevelConfig.swift` + `levels.json`

```swift
import Foundation

enum ObstacleType: String, Codable, CaseIterable {
    case blocker, mover, magnetic, shrinker
}

struct LevelConfig: Codable, Identifiable {
    let id: Int
    let world: Int
    let timeLimit: TimeInterval
    let targetCoverage: Float        // e.g. 0.65 = 65% of grid cells
    let obstacleTypes: [ObstacleType]
    let spawnInterval: TimeInterval
    let maxObstacles: Int
    let gridSize: Int                // NxN for coverage calculation

    static func load() -> [LevelConfig] {
        guard let url = Bundle.main.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let levels = try? JSONDecoder().decode([LevelConfig].self, from: data)
        else {
            assertionFailure("levels.json missing or malformed")
            return []
        }
        return levels
    }
}
```

**`levels.json`** (place in bundle root):

```json
[
  { "id":1,  "world":1, "timeLimit":60, "targetCoverage":0.50, "obstacleTypes":[],
    "spawnInterval":99, "maxObstacles":0, "gridSize":15 },
  { "id":2,  "world":1, "timeLimit":55, "targetCoverage":0.55, "obstacleTypes":[],
    "spawnInterval":99, "maxObstacles":0, "gridSize":15 },
  { "id":3,  "world":1, "timeLimit":50, "targetCoverage":0.60, "obstacleTypes":[],
    "spawnInterval":99, "maxObstacles":0, "gridSize":15 },
  { "id":4,  "world":1, "timeLimit":50, "targetCoverage":0.60, "obstacleTypes":[],
    "spawnInterval":99, "maxObstacles":0, "gridSize":15 },
  { "id":5,  "world":1, "timeLimit":50, "targetCoverage":0.65, "obstacleTypes":[],
    "spawnInterval":99, "maxObstacles":0, "gridSize":15 },
  { "id":6,  "world":1, "timeLimit":50, "targetCoverage":0.65, "obstacleTypes":["blocker"],
    "spawnInterval":4.0, "maxObstacles":3, "gridSize":18 },
  { "id":7,  "world":1, "timeLimit":50, "targetCoverage":0.65, "obstacleTypes":["blocker"],
    "spawnInterval":3.5, "maxObstacles":4, "gridSize":18 },
  { "id":8,  "world":1, "timeLimit":45, "targetCoverage":0.68, "obstacleTypes":["blocker","mover"],
    "spawnInterval":3.0, "maxObstacles":4, "gridSize":20 },
  { "id":9,  "world":1, "timeLimit":45, "targetCoverage":0.68, "obstacleTypes":["blocker","mover"],
    "spawnInterval":2.5, "maxObstacles":5, "gridSize":20 },
  { "id":10, "world":1, "timeLimit":45, "targetCoverage":0.70, "obstacleTypes":["blocker","mover","magnetic"],
    "spawnInterval":2.5, "maxObstacles":5, "gridSize":20 }
]
```

---

## 6. `ObstacleNode.swift`

```swift
import SpriteKit

final class ObstacleNode: SKNode {

    let obstacleType: ObstacleType
    var fallSpeed: CGFloat = 80        // points per second
    private var glowNode: SKShapeNode?

    // MARK: - Init
    init(type: ObstacleType, theme: Theme) {
        self.obstacleType = type
        super.init()
        setupShape(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Shape setup
    private func setupShape(theme: Theme) {
        let color = theme.obstacleColors[obstacleType.themeIndex]
        switch obstacleType {
        case .blocker:
            let shape = SKShapeNode(circleOfRadius: 14)
            shape.fillColor = color; shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(to: shape, color: color, radius: 24) }
            physicsBody = SKPhysicsBody(circleOfRadius: 14)

        case .mover:
            let shape = SKShapeNode(rectOf: CGSize(width: 50, height: 12), cornerRadius: 6)
            shape.fillColor = color; shape.strokeColor = .clear
            addChild(shape)
            if theme.obstacleGlow { addGlow(to: shape, color: color, radius: 10) }
            // Add horizontal sliding action (see startMoving())
            physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 50, height: 12))

        case .magnetic:
            let core = SKShapeNode(circleOfRadius: 12)
            core.fillColor = color; core.strokeColor = .clear
            addChild(core)
            // Pulsing ring
            let ring = SKShapeNode(circleOfRadius: 22)
            ring.fillColor = .clear
            ring.strokeColor = color.withAlphaComponent(0.4)
            ring.lineWidth = 2
            addChild(ring)
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.1, duration: 0.6),
                SKAction.fadeAlpha(to: 0.5, duration: 0.6)
            ])
            ring.run(.repeatForever(pulse))
            physicsBody = SKPhysicsBody(circleOfRadius: 12)

        case .shrinker:
            // Diamond shape via path
            let path = CGMutablePath()
            let s: CGFloat = 14
            path.move(to: CGPoint(x: 0, y: -s))
            path.addLine(to: CGPoint(x: s, y: 0))
            path.addLine(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s, y: 0))
            path.closeSubpath()
            let shape = SKShapeNode(path: path)
            shape.fillColor = color; shape.strokeColor = .clear
            addChild(shape)
            run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3)))
            physicsBody = SKPhysicsBody(polygonFrom: path)
        }

        // Physics: obstacles don't interact with each other, only detected by code
        physicsBody?.categoryBitMask    = PhysicsCategory.obstacle
        physicsBody?.collisionBitMask   = 0
        physicsBody?.contactTestBitMask = 0
        physicsBody?.isDynamic          = false
    }

    // MARK: - Glow helper (neon / retro themes)
    private func addGlow(to node: SKShapeNode, color: SKColor, radius: CGFloat) {
        // SpriteKit doesn't have native bloom, so we layer a blurred copy
        // In production, use SKEffectNode with CIFilter for proper glow
        let glow = node.copy() as! SKShapeNode
        glow.fillColor = color.withAlphaComponent(0.25)
        glow.setScale(1.6)
        insertChild(glow, at: 0)
        glowNode = glow
    }

    // MARK: - Movement
    // Call after adding to scene. boundingWidth = play area width.
    func startFalling(in playWidth: CGFloat) {
        if obstacleType == .mover {
            let travelTime = Double.random(in: 1.5...3.0)
            let moveRight = SKAction.moveBy(x: playWidth * 0.5, y: 0, duration: travelTime)
            let moveLeft  = moveRight.reversed()
            run(.repeatForever(.sequence([moveRight, moveLeft])))
        }
    }

    // MARK: - Descriptor for DrawingEngine (call each frame)
    func descriptor() -> ObstacleDescriptor {
        let pos = position   // in scene coordinates
        switch obstacleType {
        case .blocker, .magnetic:
            return ObstacleDescriptor(shape: .circle(center: pos, radius: 14))
        case .mover:
            return ObstacleDescriptor(shape: .rect(
                CGRect(x: pos.x - 25, y: pos.y - 6, width: 50, height: 12)
            ))
        case .shrinker:
            return ObstacleDescriptor(shape: .circle(center: pos, radius: 14))
        }
    }
}

// MARK: - ObstacleType helpers
extension ObstacleType {
    var themeIndex: Int {
        switch self {
        case .blocker:  return 0
        case .mover:    return 1
        case .magnetic: return 2
        case .shrinker: return 3
        }
    }
}

// MARK: - Physics categories
enum PhysicsCategory {
    static let none:     UInt32 = 0
    static let obstacle: UInt32 = 0b0001
    static let wall:     UInt32 = 0b0010
}
```

---

## 7. `LineNode.swift`

Renders the player's drawn path. Owns an `SKShapeNode` updated every frame.

```swift
import SpriteKit

final class LineNode: SKNode {

    private let shapeNode = SKShapeNode()
    private var glowNode: SKShapeNode?
    private(set) var isFailing = false
    private let theme: Theme

    init(theme: Theme) {
        self.theme = theme
        super.init()
        setupShape()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupShape() {
        shapeNode.strokeColor = theme.lineColor
        shapeNode.lineWidth   = theme.lineWidth
        shapeNode.lineCap     = .round
        shapeNode.lineJoin    = .round
        shapeNode.fillColor   = .clear
        addChild(shapeNode)

        if theme.lineGlowWidth > 0 {
            let glow = SKShapeNode()
            glow.strokeColor = theme.lineShadowColor
            glow.lineWidth   = theme.lineWidth + theme.lineGlowWidth
            glow.lineCap     = .round
            glow.alpha       = 0.4
            insertChild(glow, at: 0)
            glowNode = glow
        }
    }

    // Call every frame (or at minimum every touchesMoved) with full point array
    func update(points: [CGPoint]) {
        guard points.count >= 2 else {
            shapeNode.path = nil
            glowNode?.path = nil
            return
        }
        let path = CGMutablePath()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        shapeNode.path = path
        glowNode?.path = path
    }

    // Flash red on fail, then fade out
    func triggerFail(completion: @escaping () -> Void) {
        isFailing = true
        shapeNode.strokeColor = SKColor(hex: "#ff2255")
        glowNode?.strokeColor = SKColor(hex: "#ff2255")
        let flash = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.04, duration: 0.08),
                SKAction.colorize(with: SKColor(hex: "#ff2255"), colorBlendFactor: 1, duration: 0.08)
            ]),
            SKAction.wait(forDuration: 0.25),
            SKAction.fadeOut(withDuration: 0.25)
        ])
        shapeNode.run(flash) { completion() }
    }

    func reset() {
        isFailing = false
        shapeNode.path = nil
        glowNode?.path = nil
        shapeNode.alpha = 1
        shapeNode.strokeColor = theme.lineColor
        glowNode?.strokeColor = theme.lineShadowColor
        shapeNode.setScale(1)
    }
}
```

---

## 8. `HUDNode.swift`

An `SKNode` overlay containing score, timer ring, and level label. Sits above the game layer.

```swift
import SpriteKit

final class HUDNode: SKNode {

    // MARK: - Nodes
    private let scoreLabel   = SKLabelNode(fontNamed: "SF Pro Display")
    private let levelLabel   = SKLabelNode(fontNamed: "SF Pro Display")
    private let timerRing    = SKShapeNode()
    private let timerFill    = SKShapeNode()
    private let timerLabel   = SKLabelNode(fontNamed: "SF Pro Display")
    private let coverageBar  = SKShapeNode()
    private let coverageFill = SKShapeNode()

    private let theme: Theme
    private let maxTime: TimeInterval

    // MARK: - Init
    init(theme: Theme, levelConfig: LevelConfig, sceneSize: CGSize) {
        self.theme   = theme
        self.maxTime = levelConfig.timeLimit
        super.init()
        setupHUD(sceneSize: sceneSize, levelConfig: levelConfig)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup
    private func setupHUD(sceneSize: CGSize, levelConfig: LevelConfig) {
        let top = sceneSize.height / 2 - 60   // below notch area

        // Score
        scoreLabel.fontSize  = 28
        scoreLabel.fontColor = theme.hudAccentColor
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.text = "0"
        scoreLabel.position = CGPoint(x: -sceneSize.width/2 + 24, y: top)
        addChild(scoreLabel)

        // Level
        levelLabel.fontSize  = 14
        levelLabel.fontColor = theme.hudTextColor.withAlphaComponent(0.6)
        levelLabel.horizontalAlignmentMode = .right
        levelLabel.text = "LVL \(levelConfig.id)"
        levelLabel.position = CGPoint(x: sceneSize.width/2 - 24, y: top + 6)
        addChild(levelLabel)

        // Timer ring (drawn as two arcs)
        let ringRadius: CGFloat = 22
        let ringPath = CGPath(ellipseIn: CGRect(x: -ringRadius, y: -ringRadius,
                                                width: ringRadius*2, height: ringRadius*2),
                              transform: nil)
        timerRing.path        = ringPath
        timerRing.strokeColor = theme.hudTextColor.withAlphaComponent(0.15)
        timerRing.lineWidth   = 4
        timerRing.fillColor   = .clear
        timerRing.position    = CGPoint(x: 0, y: top + 8)
        addChild(timerRing)

        timerFill.strokeColor  = theme.hudAccentColor
        timerFill.lineWidth    = 4
        timerFill.fillColor    = .clear
        timerFill.position     = timerRing.position
        timerFill.zRotation    = .pi / 2    // start at 12 o'clock
        addChild(timerFill)

        timerLabel.fontSize  = 16
        timerLabel.fontColor = theme.hudTextColor
        timerLabel.verticalAlignmentMode = .center
        timerLabel.position  = timerRing.position
        addChild(timerLabel)

        // Coverage bar (bottom of screen)
        let barW = sceneSize.width - 48
        let barY = -sceneSize.height / 2 + 36
        let barBg = SKShapeNode(rectOf: CGSize(width: barW, height: 6), cornerRadius: 3)
        barBg.fillColor   = theme.hudTextColor.withAlphaComponent(0.1)
        barBg.strokeColor = .clear
        barBg.position    = CGPoint(x: 0, y: barY)
        addChild(barBg)

        coverageFill.fillColor   = theme.hudAccentColor
        coverageFill.strokeColor = .clear
        coverageFill.position    = CGPoint(x: -barW/2, y: barY)
        addChild(coverageFill)
    }

    // MARK: - Updates (called from GameScene.update(_:))

    func updateScore(_ score: Int) {
        scoreLabel.text = score.formatted()
    }

    func updateTimer(remaining: TimeInterval) {
        timerLabel.text = "\(Int(remaining))"
        let fraction = CGFloat(remaining / maxTime)
        let radius: CGFloat = 22
        let arcPath = CGMutablePath()
        arcPath.addArc(center: .zero, radius: radius,
                       startAngle: 0, endAngle: .pi * 2 * fraction,
                       clockwise: false)
        timerFill.path = arcPath
        // Warn: turn accent red when < 10s
        if remaining <= 10 {
            timerFill.strokeColor = SKColor(hex: "#ef4444")
            timerLabel.fontColor  = SKColor(hex: "#ef4444")
        }
    }

    func updateCoverage(_ fraction: Float, targetFraction: Float, barWidth: CGFloat) {
        let w = CGFloat(fraction) * barWidth
        coverageFill.path = CGPath(rect: CGRect(x: 0, y: -3, width: max(0, w), height: 6),
                                   transform: nil)
    }
}
```

---

## 9. `GameScene.swift`

The core scene. Wires together `DrawingEngine`, `LineNode`, `HUDNode`, `ObstacleNode`, and `GameStateMachine`.

```swift
import SpriteKit

final class GameScene: SKScene {

    // MARK: - Configuration
    let levelConfig: LevelConfig
    let theme: Theme

    // MARK: - Engine components
    private let stateMachine = GameStateMachine()
    private let drawingEngine = DrawingEngine()

    // MARK: - Nodes
    private var lineNode: LineNode!
    private var hudNode: HUDNode!
    private var obstacleNodes: [ObstacleNode] = []
    private var pauseOverlay: SKNode?

    // MARK: - Game state
    private var timeRemaining: TimeInterval = 0
    private var score: Int = 0
    private var lastUpdateTime: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0

    // MARK: - Play area (set in didMove)
    private var playRect: CGRect = .zero

    // MARK: - Init
    init(levelConfig: LevelConfig, theme: Theme, size: CGSize) {
        self.levelConfig = levelConfig
        self.theme       = theme
        super.init(size: size)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        stateMachine.delegate = self
        setupScene()
        setupHUD()
        setupPlayArea()
        timeRemaining = levelConfig.timeLimit
    }

    private func setupScene() {
        backgroundColor = theme.background
        // Draw grid
        let gridNode = GridNode(theme: theme, size: size)
        addChild(gridNode)
        // Line node
        lineNode = LineNode(theme: theme)
        addChild(lineNode)
    }

    private func setupHUD() {
        hudNode = HUDNode(theme: theme, levelConfig: levelConfig, sceneSize: size)
        hudNode.zPosition = 100
        addChild(hudNode)
    }

    private func setupPlayArea() {
        // Play area inset from edges to leave room for HUD
        let inset: CGFloat = 24
        let topInset: CGFloat = 100   // below HUD
        let bottomInset: CGFloat = 60 // above coverage bar
        playRect = CGRect(
            x: -size.width/2  + inset,
            y: -size.height/2 + bottomInset,
            width:  size.width  - inset * 2,
            height: size.height - topInset - bottomInset
        )
    }

    // MARK: - Main update loop
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        guard stateMachine.phase == .drawing || stateMachine.phase == .idle else { return }

        // Move obstacles downward
        for obs in obstacleNodes {
            obs.position.y -= obs.fallSpeed * CGFloat(dt)
            // Recycle obstacle when it exits the bottom
            if obs.position.y < playRect.minY - 40 {
                recycleObstacle(obs)
            }
        }

        // Spawn timer
        if stateMachine.phase == .drawing || stateMachine.phase == .idle {
            spawnTimer += dt
            if spawnTimer >= levelConfig.spawnInterval &&
               obstacleNodes.count < levelConfig.maxObstacles {
                spawnObstacle()
                spawnTimer = 0
            }
        }

        // Countdown timer (only while drawing has started)
        if stateMachine.phase == .drawing {
            timeRemaining -= dt
            hudNode.updateTimer(remaining: max(0, timeRemaining))
            if timeRemaining <= 0 { triggerFail(reason: .timeExpired) }
        }

        // Coverage
        let coverage = drawingEngine.coveragePercent(in: playRect,
                                                     gridSize: levelConfig.gridSize)
        hudNode.updateCoverage(coverage, targetFraction: levelConfig.targetCoverage,
                               barWidth: size.width - 48)

        // Win check
        if coverage >= levelConfig.targetCoverage && stateMachine.phase == .drawing {
            triggerWin(coverage: coverage)
        }
    }

    // MARK: - Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard stateMachine.phase == .idle else { return }
        let pos = touch.location(in: self)
        guard playRect.contains(pos) else { return }
        drawingEngine.begin(at: pos)
        stateMachine.transition(to: .drawing)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard stateMachine.phase == .drawing,
              let touch = touches.first else { return }
        let pos = touch.location(in: self)

        let descriptors = obstacleNodes.map { $0.descriptor() }
        let result = drawingEngine.extend(to: pos, obstacles: descriptors)

        switch result {
        case .ok:
            lineNode.update(points: drawingEngine.points)
            score = Int(drawingEngine.totalDistance * 2)
            hudNode.updateScore(score)
        case .fail(let reason):
            triggerFail(reason: reason)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard stateMachine.phase == .drawing else { return }
        triggerFail(reason: .fingerLifted)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Fail
    private func triggerFail(reason: FailReason) {
        stateMachine.transition(to: .failFlash, failReason: reason)
        lineNode.triggerFail {
            let scene = GameOverScene(
                reason: reason,
                score: self.score,
                levelConfig: self.levelConfig,
                theme: self.theme,
                size: self.size
            )
            self.view?.presentScene(scene, transition: .fade(withDuration: 0.3))
        }
    }

    // MARK: - Win
    private func triggerWin(coverage: Float) {
        stateMachine.transition(to: .levelComplete)
        clearInterval()
        let stars = starsEarned(coverage: coverage)
        PlayerProgress.shared.recordCompletion(levelId: levelConfig.id,
                                               stars: stars, score: score)
        let scene = WinScene(stars: stars, score: score,
                             levelConfig: levelConfig, theme: theme, size: size)
        run(.wait(forDuration: 0.6)) {
            self.view?.presentScene(scene, transition: .fade(withDuration: 0.4))
        }
    }

    private func starsEarned(coverage: Float) -> Int {
        if coverage >= levelConfig.targetCoverage + 0.15 &&
           timeRemaining > 10 && drawingEngine.nearMissCount == 0 { return 3 }
        if timeRemaining > 10 { return 2 }
        return 1
    }

    private func clearInterval() { spawnTimer = 0 }

    // MARK: - Obstacles
    private func spawnObstacle() {
        guard let type = levelConfig.obstacleTypes.randomElement() else { return }
        let obs = ObstacleNode(type: type, theme: theme)
        let x = CGFloat.random(in: playRect.minX + 20 ... playRect.maxX - 20)
        obs.position = CGPoint(x: x, y: playRect.maxY + 30)
        obs.fallSpeed = 60 + CGFloat(levelConfig.id) * 3
        obs.startFalling(in: playRect.width)
        obstacleNodes.append(obs)
        addChild(obs)
    }

    private func recycleObstacle(_ obs: ObstacleNode) {
        obs.removeFromParent()
        obstacleNodes.removeAll { $0 === obs }
    }
}

// MARK: - GameStateMachineDelegate
extension GameScene: GameStateMachineDelegate {
    func stateMachine(_ machine: GameStateMachine,
                      didTransitionFrom old: GamePhase,
                      to new: GamePhase) {
        // Use this for UI reactions to state changes (e.g. dim scene on pause)
        switch new {
        case .paused:
            showPauseOverlay()
        case .idle, .drawing:
            hidePauseOverlay()
        default:
            break
        }
    }

    private func showPauseOverlay() {
        // TODO: implement pause overlay SKNode
    }
    private func hidePauseOverlay() {
        pauseOverlay?.removeFromParent()
        pauseOverlay = nil
    }
}
```

---

## 10. `PlayerProgress.swift`

```swift
import Foundation

final class PlayerProgress {
    static let shared = PlayerProgress()
    private let defaults = UserDefaults.standard

    func recordCompletion(levelId: Int, stars: Int, score: Int) {
        let key = "level_\(levelId)"
        let current = defaults.integer(forKey: key + "_stars")
        if stars > current { defaults.set(stars, forKey: key + "_stars") }
        let currentScore = defaults.integer(forKey: key + "_score")
        if score > currentScore { defaults.set(score, forKey: key + "_score") }
        let highScore = defaults.integer(forKey: "global_highscore")
        if score > highScore { defaults.set(score, forKey: "global_highscore") }
    }

    func stars(for levelId: Int) -> Int {
        defaults.integer(forKey: "level_\(levelId)_stars")
    }

    func isUnlocked(_ levelId: Int) -> Bool {
        if levelId == 1 { return true }
        return stars(for: levelId - 1) >= 1
    }

    func activeThemeKey() -> ThemeKey {
        let raw = defaults.string(forKey: "active_theme") ?? ThemeKey.neon.rawValue
        return ThemeKey(rawValue: raw) ?? .neon
    }

    func setTheme(_ key: ThemeKey) {
        defaults.set(key.rawValue, forKey: "active_theme")
    }

    func unlockedThemes() -> [ThemeKey] {
        var unlocked: [ThemeKey] = [.neon]
        if stars(for: 10) >= 1 { unlocked.append(.clay) }
        if stars(for: 20) >= 1 { unlocked.append(.retro) }
        if stars(for: 30) >= 1 { unlocked.append(.watercolour) }
        return unlocked
    }
}
```

---

## 11. Scene Stubs (implement after core is working)

### `HomeScene.swift`
Present on app launch. Contains "Play", "Themes", "Leaderboard" buttons. All drawn in code using `SKLabelNode` and `SKShapeNode`. Reference `wireframe.html` for visual layout. Transition to `LevelSelectScene` on Play.

### `LevelSelectScene.swift`
Grid of level cells (4 columns). Read star count from `PlayerProgress`. Grey-out locked levels. On tap, push `GameScene(levelConfig:theme:size:)`.

### `GameOverScene.swift`
Show `reason.displayText`, score stats (distance, coverage, time survived). Two buttons: "Try Again" (new `GameScene` with same config) and "Level Select". Reference wireframe screen 4.

### `WinScene.swift`
Animate stars appearing (delay between each). Show score breakdown table. "Next Level" and "Level Select" buttons. Reference wireframe screen 5.

### `ThemeSelectScene.swift`
Four theme preview cards. Locked themes show a padlock. Tap unlocked theme → `PlayerProgress.shared.setTheme(_:)`. Reference wireframe screen 6.

### `GridNode.swift`
Draws the faint background grid lines in the play area colour from the active theme. Purely cosmetic.

---

## 12. `AppDelegate.swift` additions

```swift
// Add to application(_:didFinishLaunchingWithOptions:)
GKLocalPlayer.local.authenticateHandler = { viewController, error in
    if let vc = viewController {
        // Present Game Center auth VC
        self.window?.rootViewController?.present(vc, animated: true)
    }
}
```

---

## Build Order Reminder

1. `GeometryHelpers.swift` — no dependencies
2. `Theme.swift` — no dependencies
3. `GameState.swift` — no dependencies
4. `DrawingEngine.swift` — depends on GeometryHelpers, GameState
5. `LevelConfig.swift` + `levels.json`
6. `PlayerProgress.swift`
7. `ObstacleNode.swift` — depends on Theme, PhysicsCategory
8. `LineNode.swift` — depends on Theme
9. `GridNode.swift` — depends on Theme
10. `HUDNode.swift` — depends on Theme, LevelConfig
11. `GameScene.swift` — wires all above together
12. `GameOverScene.swift`, `WinScene.swift`
13. `LevelSelectScene.swift`
14. `HomeScene.swift`
15. `ThemeSelectScene.swift`
16. `AppDelegate.swift` — Game Center auth

Test after step 11 before continuing to UI scenes. The core game loop should be fully playable at that point.
