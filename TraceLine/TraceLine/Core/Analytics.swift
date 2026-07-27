import Foundation

/// Analytics hooks with no SDK behind them, per HANDOVER § "What NOT to build in v1"
/// ("Analytics — add hooks but no SDK").
///
/// The call sites are what's valuable here: they mark the moments worth measuring, so
/// adopting a provider later is a change to `send(_:)` alone rather than a hunt through
/// the scenes. Nothing leaves the device today, which is what keeps the App Store
/// privacy declaration ("data not collected") honest — wiring a provider in means
/// revisiting that declaration and PRIVACY.md.
enum Analytics {

    enum Event {
        case levelStarted(id: Int)
        // `drawSpeed` is the round's measured sustained drawing rate in points per second
        // (distance drawn ÷ time actually drawing). The difficulty curve assumes ~400 pt/s
        // sustained and nobody had been timed; this is how the model gets checked against a
        // human once a provider (or the DEBUG console) is watching.
        case levelCleared(id: Int, score: Int, stars: Int, secondsRemaining: Int, drawSpeed: Int)
        case levelFailed(id: Int, reason: FailReason, coveragePercent: Int, drawSpeed: Int)
        case themeSelected(ThemeKey)
        case leaderboardOpened

        var name: String {
            switch self {
            case .levelStarted:      return "level_started"
            case .levelCleared:      return "level_cleared"
            case .levelFailed:       return "level_failed"
            case .themeSelected:     return "theme_selected"
            case .leaderboardOpened: return "leaderboard_opened"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .levelStarted(let id):
                return ["level": id]
            case .levelCleared(let id, let score, let stars, let secondsRemaining, let drawSpeed):
                return ["level": id, "score": score, "stars": stars,
                        "seconds_remaining": secondsRemaining, "draw_speed": drawSpeed]
            case .levelFailed(let id, let reason, let coverage, let drawSpeed):
                return ["level": id, "reason": reason.analyticsName, "coverage": coverage,
                        "draw_speed": drawSpeed]
            case .themeSelected(let key):
                return ["theme": key.rawValue]
            case .leaderboardOpened:
                return [:]
            }
        }
    }

    static func log(_ event: Event) {
        send(event)
    }

    private static func send(_ event: Event) {
        // No provider for v1. An SDK would forward event.name and event.parameters from
        // here — and would need a privacy-declaration update before it could ship.
        #if DEBUG
        print("[Analytics] \(event.name) \(event.parameters)")
        #endif
    }
}

extension FailReason {
    /// Stable across releases — display text can be reworded, event values cannot.
    var analyticsName: String {
        switch self {
        case .fingerLifted: return "finger_lifted"
        case .lineCrossed:  return "line_crossed"
        case .obstacleHit:  return "obstacle_hit"
        case .timeExpired:  return "time_expired"
        case .burnedOut:    return "burned_out"
        }
    }
}
