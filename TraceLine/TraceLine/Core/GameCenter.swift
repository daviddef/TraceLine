import GameKit
import UIKit

/// Game Center wrapper. Authentication is kicked off at launch; score submission and
/// achievements no-op silently when the player isn't signed in, so nothing here can
/// interrupt a round.
enum GameCenter {

    static let leaderboardID = "traceline.highscore.alltime"

    enum Achievement: String {
        case firstClear = "traceline.firstclear"
        case noLift10   = "traceline.nolift10"
        case speedrun   = "traceline.speedrun"
    }

    static func authenticate(presentingFrom viewController: UIViewController?) {
        GKLocalPlayer.local.authenticateHandler = { authVC, error in
            if let authVC {
                viewController?.present(authVC, animated: true)
                return
            }
            if let error {
                print("[GameCenter] authentication failed: \(error.localizedDescription)")
            }
        }
    }

    static var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    static func submit(score: Int) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboardID]) { error in
            if let error {
                print("[GameCenter] score submission failed: \(error.localizedDescription)")
            }
        }
    }

    static func report(_ achievement: Achievement, percent: Double = 100) {
        guard isAuthenticated else { return }
        let a = GKAchievement(identifier: achievement.rawValue)
        a.percentComplete = percent
        a.showsCompletionBanner = true
        GKAchievement.report([a]) { error in
            if let error {
                print("[GameCenter] achievement report failed: \(error.localizedDescription)")
            }
        }
    }

    /// Reports the achievements a cleared level may have earned.
    ///
    /// `noLift10` needs no lift-tracking of its own: lifting a finger ends the round,
    /// so every completed level is by definition a level completed without lifting.
    static func reportCompletion(levelsCleared: Int, timeRemaining: TimeInterval) {
        report(.firstClear)
        report(.noLift10, percent: min(100, Double(levelsCleared) / 10 * 100))
        if timeRemaining >= 20 { report(.speedrun) }
    }

    /// Presents the native leaderboard UI.
    static func showLeaderboard(from viewController: UIViewController?) {
        guard isAuthenticated, let viewController else { return }
        let gcVC = GKGameCenterViewController(leaderboardID: leaderboardID,
                                              playerScope: .global,
                                              timeScope: .allTime)
        gcVC.gameCenterDelegate = GameCenterDelegateProxy.shared
        viewController.present(gcVC, animated: true)
    }
}

/// GKGameCenterControllerDelegate requires an NSObject; this keeps that requirement
/// out of the enum above.
final class GameCenterDelegateProxy: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDelegateProxy()
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
