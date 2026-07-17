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

        let window = UIWindow(frame: UIScreen.main.bounds)
        let rootViewController = GameViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        self.window = window

        GameCenter.authenticate(presentingFrom: rootViewController)
        Store.start()   // no-ops while Store.isEnabled is false
        return true
    }
}
