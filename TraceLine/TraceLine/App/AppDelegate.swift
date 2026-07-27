import GameKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // UI tests need a known starting state.
        if CommandLine.arguments.contains("--reset-progress") {
            PlayerProgress.shared.reset()
        }
        if CommandLine.arguments.contains("--unlock-all") {
            PlayerProgress.shared.unlockAll()
        }
        if let i = CommandLine.arguments.firstIndex(of: "--progress"),
           i + 1 < CommandLine.arguments.count,
           let count = Int(CommandLine.arguments[i + 1]) {
            PlayerProgress.shared.seedProgress(upTo: count)
        }
        // Any test/tooling launch expects to start at a known scene, not the first-run
        // tutorial. Mark it seen so the gate in GameViewController falls through.
        for arg in ["--reset-progress", "--unlock-all", "--progress"] where CommandLine.arguments.contains(arg) {
            PlayerProgress.shared.hasSeenTutorial = true
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        let rootViewController = GameViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        self.window = window

        GameCenter.authenticate(presentingFrom: rootViewController)
        Store.start()      // no-ops while Store.isEnabled is false
        SoundHook.warmUp()  // preload sound effects so the first cue doesn't stall
        return true
    }
}
