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

    var displayText: String {
        switch self {
        case .fingerLifted: return "💥 Finger lifted"
        case .lineCrossed:  return "🚫 Line crossed itself"
        case .obstacleHit:  return "⛔ Hit an obstacle"
        case .timeExpired:  return "⏱ Time's up"
        }
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
