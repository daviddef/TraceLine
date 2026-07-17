import UIKit

/// Hooks for feedback. Audio is out of scope for v1 (HANDOVER: "add hooks but no
/// audio assets yet"), so these are haptics-only for now — `SoundHook` marks where
/// audio would be triggered once assets exist.
enum Haptics {
    static func fail() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        SoundHook.play(.fail)
    }

    static func win() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        SoundHook.play(.win)
    }

    /// The line has just been severed — sharper than a tap, softer than a fail.
    static func cut() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        SoundHook.play(.cut)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        SoundHook.play(.tap)
    }
}

/// Placeholder for the v1 sound hooks. No audio assets ship yet.
enum SoundHook {
    enum Cue { case tap, fail, win, nearMiss, cut }
    static func play(_ cue: Cue) {
        // Intentionally empty — wire to SKAudioNode / AVAudioPlayer when assets land.
    }
}
