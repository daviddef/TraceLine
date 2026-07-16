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
