import CoreGraphics
import Foundation

struct RoundScore {
    var baseDistance: CGFloat       // total path length drawn
    var coveragePct: Float          // board coverage 0–1
    var timeRemaining: TimeInterval // seconds left when cleared
    var nearMissCount: Int          // times the line came within 20pt of an obstacle
    var starsEarned: Int            // 1–3

    var base:  Int { Int(baseDistance * 2) }
    var cover: Int { Int(coveragePct * 1000) }
    var speed: Int { timeRemaining > 10 ? Int(timeRemaining * 20) : 0 }
    var clean: Int { nearMissCount == 0 ? 500 : 0 }

    var total: Int { base + cover + speed + clean }
}
