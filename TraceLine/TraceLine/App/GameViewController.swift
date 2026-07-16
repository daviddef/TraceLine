import SpriteKit
import UIKit

final class GameViewController: UIViewController {

    private var skView: SKView { view as! SKView }
    private var hasPresentedScene = false

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        skView.ignoresSiblingOrder = true
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif
    }

    /// Scenes lay themselves out against a fixed size, so the first one is presented
    /// only once the view's real bounds are known.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !hasPresentedScene, view.bounds.width > 0 else { return }
        hasPresentedScene = true

        #if DEBUG
        // Reaching the win screen legitimately needs a full round, so allow jumping
        // straight to it while iterating on its layout.
        if CommandLine.arguments.contains("--debug-win"),
           let level = LevelConfig.level(id: 1) {
            let sample = RoundScore(baseDistance: 1_240, coveragePct: 0.91,
                                    timeRemaining: 22.5, nearMissCount: 0, starsEarned: 3)
            skView.presentScene(WinScene(roundScore: sample, levelConfig: level,
                                         theme: Theme.active, size: view.bounds.size))
            return
        }
        #endif

        skView.presentScene(HomeScene(theme: Theme.active, size: view.bounds.size))
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
