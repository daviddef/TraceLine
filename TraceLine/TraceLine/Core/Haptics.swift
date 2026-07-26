import UIKit
import AVFoundation

/// Hooks for feedback: a haptic and a sound for each game event. The sounds are the
/// short synthesized cues in Resources/Audio (see Tools/generate_audio.py).
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

/// Plays the game's sound effects. AVAudioPlayer rather than SpriteKit's
/// `playSoundFileNamed`, so cues can fire from anywhere (menus, not just a scene) and
/// so the audio session can be configured to behave like a casual game should.
///
/// Two deliberate choices:
///   - The session category is `.ambient`, so we mix under the player's own music and,
///     crucially, obey the hardware silent switch — a phone on mute stays silent.
///   - One preloaded player per cue, plus a couple of spare copies for the cues that
///     retrigger fast (tap, cut), because a single AVAudioPlayer restarts rather than
///     overlaps. Preloading avoids the first-play stall.
enum SoundHook {
    enum Cue: String, CaseIterable { case tap, fail, win, nearMiss, cut }

    /// How many overlapping voices each cue keeps. Rapid cues need a few; one-shots need one.
    private static func voices(for cue: Cue) -> Int {
        switch cue {
        case .tap, .cut, .nearMiss: return 3
        case .win, .fail:           return 1
        }
    }

    private static var pools: [Cue: [AVAudioPlayer]] = [:]
    private static var nextVoice: [Cue: Int] = [:]
    private static var didConfigureSession = false

    /// Preload every cue. Safe to call more than once; only the first does work.
    static func warmUp() {
        guard pools.isEmpty else { return }
        configureSessionIfNeeded()
        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav", subdirectory: "Audio")
                    ?? Bundle.main.url(forResource: cue.rawValue, withExtension: "wav") else {
                continue
            }
            let players: [AVAudioPlayer] = (0..<voices(for: cue)).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
            if !players.isEmpty { pools[cue] = players }
        }
    }

    static func play(_ cue: Cue) {
        guard PlayerProgress.shared.soundEnabled else { return }
        if pools.isEmpty { warmUp() }
        guard let players = pools[cue], !players.isEmpty else { return }
        let i = (nextVoice[cue] ?? 0) % players.count
        nextVoice[cue] = i + 1
        let player = players[i]
        player.currentTime = 0
        player.play()
    }

    private static func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        // .ambient: obey the silent switch and mix with the user's music rather than
        // interrupting it. .mixWithOthers is implicit for .ambient but stated for clarity.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
