import Foundation

/// All possible states the game can be in.
enum GamePhase: Equatable {
    case idle           // waiting for first touch
    case drawing        // player has finger down, line extending
    case paused         // pause overlay shown
    case failFlash      // brief flash before transitioning to game-over
    case levelComplete  // coverage target hit, showing win animation
}

/// The reasons a round can end in failure.
enum FailReason {
    case fingerLifted
    case lineCrossed
    case obstacleHit
    case timeExpired
    case burnedOut

    var displayText: String {
        switch self {
        case .fingerLifted: return "💥 Finger lifted"
        case .lineCrossed:  return "🚫 Line crossed itself"
        case .obstacleHit:  return "⛔ Hit an obstacle"
        case .timeExpired:  return "⏱ Time's up"
        case .burnedOut:    return "🔥 The line burned out"
        }
    }

    /// A light, family-friendly line for the game-over screen — it still says what went
    /// wrong, just with a wink. Picked at random so failing a lot stays fresh.
    var quip: String {
        let bank: [String]
        switch self {
        case .fingerLifted:
            bank = ["💥 You let go — so did the line.", "💥 Commitment issues.",
                    "💥 Fingers down! All of them.", "💥 So close, yet so lifted."]
        case .lineCrossed:
            bank = ["🚫 You crossed your own line.", "🚫 Tangled!",
                    "🚫 Don't cross the streams.", "🚫 Your past self got you."]
        case .obstacleHit:
            bank = ["⛔ Right into it. Bonk.", "⛔ That one was solid.",
                    "⛔ Maybe go *around* next time.", "⛔ Ouch."]
        case .timeExpired:
            bank = ["⏱ The clock won this round.", "⏱ Too careful, too slow.",
                    "⏱ Time's up — draw bolder!"]
        case .burnedOut:
            bank = ["🔥 The flame caught the tip.", "🔥 Burned to the end.",
                    "🔥 Should've run for a shelter."]
        }
        return bank.randomElement() ?? displayText
    }
}

/// Centralised state machine — owned by GameScene, observed via delegate.
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
