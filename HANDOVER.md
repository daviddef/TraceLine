# TraceLine — Claude Code Handover Brief

## What You Are Building

**TraceLine** is an iOS game where the player draws a continuous freehand line on a canvas without ever lifting their finger. Two rules govern all gameplay:

1. **Never lift your finger** — the instant contact breaks, the round ends
2. **Lines can never cross** — the path cannot intersect itself

As levels progress, **obstacles fall from the top of the screen**. The player must navigate around them while maintaining their continuous line. If the line touches an obstacle, the round ends.

A companion wireframe prototype (HTML) and a research report have already been produced. The wireframe demonstrates all game screens, the drawing mechanic, collision logic (including a working JS implementation of the self-crossing detection algorithm), and the theme system. Those files are included in this handover package.

---

## Deliverables Already Complete

| File | Purpose |
|---|---|
| `HANDOVER.md` | This document — read first |
| `SWIFT_ARCHITECTURE.md` | Full Swift/SpriteKit technical spec — file structure, classes, protocols, algorithms |
| `wireframe.html` | Interactive prototype — open in browser to see all 6 screens and play the mechanic |
| `ios-drawing-game-research.md` | Research report — competitive analysis, game design rationale, framework comparison |

---

## Technology Stack

| Decision | Choice | Reason |
|---|---|---|
| Language | Swift 5.9+ | Native, best iOS performance |
| Game framework | SpriteKit | Apple-native 2D, built-in physics + particles, Game Center ready, no royalties |
| Minimum iOS | iOS 16.0 | Wide device coverage, modern APIs |
| Architecture | MVC + GameState machine | Clean separation; GameScene owns rendering, GameManager owns state |
| Persistence | UserDefaults (scores) + simple JSON (level data) | No backend needed for v1 |
| Monetisation hooks | StoreKit 2 stubs only | Implement IAP shell but don't activate for v1 |

---

## Xcode Project Setup

1. Create a new Xcode project: **Game** template → **SpriteKit**
2. Product name: `TraceLine`
3. Bundle ID: `com.yourname.traceline`
4. Language: Swift
5. Minimum deployment: iOS 16.0
6. Uncheck "Include Tests" for now
7. Delete the default `GameScene.sks` and `Actions.sks` — all scenes are built in code
8. Delete the default `GameScene.swift` — replace with the files in `SWIFT_ARCHITECTURE.md`

---

## Game Concept in Full

### Core Loop
- Player presses finger to canvas → line starts drawing at touch point
- Player drags finger → line extends, score accumulates by distance
- Player must fill as much of the play area as possible before:
  - Time runs out (countdown timer)
  - They lift their finger
  - Their line crosses itself
  - Their line touches a falling obstacle
- Level clears when `coveragePercent >= levelTarget` (e.g. 70% of grid cells covered)

### Fail Conditions (in priority order)
1. **Finger lifted** — `touchesEnded` fires while `isDrawing == true` → `.fingerLifted`
2. **Line crossed** — new segment intersects any prior segment → `.lineCrossed`
3. **Obstacle hit** — drawing tip enters obstacle hitbox → `.obstacleHit`
4. **Time expired** — countdown reaches zero, coverage target not met → `.timeExpired`

### Win Condition
Coverage percentage of the play grid reaches `level.targetCoverage` before time runs out. Stars awarded:
- ⭐ Level cleared (coverage ≥ target)
- ⭐⭐ Cleared with ≥10s remaining
- ⭐⭐⭐ Cleared with no near-misses (line never came within 20pt of an obstacle)

---

## The Self-Crossing Detection Algorithm

This was proven in the wireframe prototype. Translate directly to Swift:

```swift
// Cross product of vectors (b-a) × (c-a)
func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

// True if point c lies on segment [a,b] (assumes collinear)
func onSegment(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Bool {
    min(a.x,b.x) <= c.x && c.x <= max(a.x,b.x) &&
    min(a.y,b.y) <= c.y && c.y <= max(a.y,b.y)
}

// True if segment [p1,p2] intersects [p3,p4]
func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint,
                       _ p3: CGPoint, _ p4: CGPoint) -> Bool {
    let d1 = cross(p3,p4,p1), d2 = cross(p3,p4,p2)
    let d3 = cross(p1,p2,p3), d4 = cross(p1,p2,p4)
    if ((d1>0 && d2<0) || (d1<0 && d2>0)) &&
       ((d3>0 && d4<0) || (d3<0 && d4>0)) { return true }
    if d1==0 && onSegment(p3,p4,p1) { return true }
    if d2==0 && onSegment(p3,p4,p2) { return true }
    if d3==0 && onSegment(p1,p2,p3) { return true }
    if d4==0 && onSegment(p1,p2,p4) { return true }
    return false
}

// Check if the proposed new segment (from last point to newPt) crosses any prior segment.
// Skip the immediately adjacent segment (i == points.count-2) to avoid false positives.
func wouldCross(newPt: CGPoint, points: [CGPoint]) -> Bool {
    guard points.count >= 2 else { return false }
    let a = points[points.count - 1]
    for i in 0..<(points.count - 2) {
        if segmentsIntersect(a, newPt, points[i], points[i+1]) { return true }
    }
    return false
}
```

**Performance note:** For levels with many points, run this check every N points (N=3) rather than every touch event to keep it under 1ms. Store points sparsely (min distance 4pt between recorded points).

---

## Obstacle System

### Obstacle Types

| Type | Shape | Behaviour | Hit zone |
|---|---|---|---|
| `Blocker` | Circle | Falls straight down, static speed | Circle radius |
| `Mover` | Rectangle | Slides horizontally while falling | Rect bounds |
| `Magnetic` | Circle + pulsing ring | Falls, visually warns player of proximity | Circle radius (no actual pull in v1 — visual only) |
| `Shrinker` | Diamond | Falls and rotates, narrows a corridor | Rotated rect |

### Obstacle Spawning
- Spawn from y = `playAreaTop + 40` at random x within play bounds
- Minimum spacing: no two obstacles within 60pt of each other at spawn
- Fall speed: `baseSpeed + (level * 0.3)` points/second
- Introduce new types: Blocker (level 1), Mover (level 4), Magnetic (level 7), Shrinker (level 10)
- Spawn interval: `max(1.0, 3.0 - level * 0.15)` seconds

### Collision with Player Line
Check distance from current touch point to each obstacle every touch event:
- Circle obstacles: `distance(touchPoint, obstacle.position) < obstacle.radius + LINE_WIDTH/2 + 4`
- Rect obstacles: use `CGRect.contains` with an expanded rect (inset by `-LINE_WIDTH/2`)

---

## Theme System

Four themes, selectable from the main menu, persisted in `UserDefaults`:

| Key | Name | Background | Line colour | Obstacle colour | Special |
|---|---|---|---|---|---|
| `neon` | Neon | `#0d0d1a` | `#6366f1` | `#ec4899` | Glow/bloom shader on line |
| `clay` | Clay | `#fef9f0` | `#f97316` | `#84cc16` | Thick stroke, slight bevel texture |
| `retro` | Retro | `#020f02` | `#22c55e` | `#facc15` | Pixelated line, scanline overlay |
| `watercolour` | Watercolour | `#f0f9ff` | `#06b6d4` | `#a78bfa` | Soft feathered edges on line |

The `Theme` struct holds all colour/style values. `GameScene` reads the active theme at `didMove(to:)` and applies it to all nodes. Switching themes doesn't require scene reload — call `applyTheme()` which updates all existing nodes.

For v1: Neon is the default, others are unlocked by completing World 1 (levels 1–10).

---

## Level Data Structure

```swift
struct LevelConfig: Codable {
    let id: Int
    let world: Int
    let timeLimit: TimeInterval       // seconds
    let targetCoverage: Float         // 0.0–1.0
    let obstacleTypes: [ObstacleType] // which types are active
    let spawnInterval: TimeInterval   // seconds between spawns
    let maxObstacles: Int             // on screen at once
    let gridSize: Int                 // play area divided into N×N cells for coverage
}
```

Levels 1–5: No obstacles, just the drawing mechanic. Teach the rules.
Level 6: First Blocker obstacle introduced.
Levels 7–10: Increasing obstacle count and speed.
Level 11+: Movers introduced. New world.

Store level configs as `levels.json` in the app bundle. Do not hard-code in Swift.

---

## Scoring

```swift
struct RoundScore {
    var baseDistance: CGFloat       // total path length drawn
    var coveragePct: Float          // board coverage 0–1
    var timeRemaining: TimeInterval // seconds left when cleared
    var nearMissCount: Int          // times line came within 20pt of obstacle
    var starsEarned: Int            // 1–3

    var total: Int {
        let base   = Int(baseDistance * 2)
        let cover  = Int(coveragePct * 1000)
        let speed  = timeRemaining > 10 ? Int(timeRemaining * 20) : 0
        let clean  = nearMissCount == 0 ? 500 : 0
        return base + cover + speed + clean
    }
}
```

---

## Screens & Navigation Flow

```
HomeScene
  ├── [Play]         → LevelSelectScene
  ├── [Themes]       → ThemeSelectScene (modal overlay)
  ├── [Leaderboard]  → GKLeaderboard (Game Center)
  └── [Settings]     → SettingsScene (modal)

LevelSelectScene
  └── [Tap level]    → GameScene(levelConfig:)

GameScene
  ├── [Win]          → WinScene(score:) → LevelSelectScene
  ├── [Fail]         → GameOverScene(reason:score:) → GameScene (retry) or LevelSelectScene
  └── [Pause]        → PauseOverlay (modal node, not a new scene)
```

Use `SKView.presentScene(_:transition:)` with `SKTransition.fade(withDuration:)` for all scene changes.

---

## Game Center Integration

- Enable Game Center in Xcode → Signing & Capabilities
- Leaderboard ID: `traceline.highscore.alltime`
- Achievement IDs (stubs for v1):
  - `traceline.firstclear` — Complete level 1
  - `traceline.nolift10` — Complete 10 levels without ever lifting
  - `traceline.speedrun` — Clear a level with 20+ seconds remaining
- Authenticate: `GKLocalPlayer.local.authenticateHandler` in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`

---

## File Delivery

The full Swift file specifications with complete class/protocol/method signatures are in `SWIFT_ARCHITECTURE.md`. Build files in this order:

1. `Theme.swift` — data only, no dependencies
2. `GameState.swift` — enums and state machine
3. `LevelConfig.swift` + `levels.json` — level data
4. `DrawingEngine.swift` — core mechanic, no SpriteKit dependency
5. `ObstacleNode.swift` — SpriteKit node subclass
6. `HUDNode.swift` — SpriteKit node subclass
7. `GameScene.swift` — wires everything together
8. `GameOverScene.swift` + `WinScene.swift`
9. `LevelSelectScene.swift`
10. `HomeScene.swift`
11. `ThemeSelectScene.swift`

---

## What NOT to Build in v1

- Multiplayer
- iCloud sync (UserDefaults only)
- In-app purchases (stubs only)
- iPad layout (iPhone portrait only)
- Sound (add hooks but no audio assets yet)
- Analytics (add hooks but no SDK)
