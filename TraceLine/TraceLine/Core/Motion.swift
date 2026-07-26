import UIKit

/// The single source of truth for "should the game hold still?".
///
/// Motion is reduced if the player turned it on in Settings *or* if they have iOS's
/// system-wide Reduce Motion switch enabled — so someone who is motion-sensitive never
/// has to discover the in-app toggle for the game to respect them.
enum Motion {
    static var isReduced: Bool {
        PlayerProgress.shared.reduceMotion || UIAccessibility.isReduceMotionEnabled
    }
}
