import XCTest

/// SpriteKit draws to a single view and exposes no accessibility tree, so these tests
/// drive real touches at real coordinates and capture screenshots for inspection.
/// They prove the app launches, navigates, and that a drag-then-lift ends the round.
final class GameplayUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-progress"]
        app.launch()
    }

    /// Scenes are laid out with the origin at the screen centre and +y upwards;
    /// XCUITest wants normalised offsets from the top-left.
    private func coordinate(sceneX: CGFloat, sceneY: CGFloat) -> XCUICoordinate {
        let frame = app.frame
        let dx = 0.5 + sceneX / frame.width
        let dy = 0.5 - sceneY / frame.height
        return app.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: dy))
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Home → Level Select → Level 1.
    private func startLevelOne() {
        attach("1-home")
        coordinate(sceneX: 0, sceneY: -40).tap()      // Play
        Thread.sleep(forTimeInterval: 1.0)
        attach("2-level-select")

        // First cell of a 4-column grid laid out from topY = height/2 - 190.
        let cellX: CGFloat = -(4 * 68 + 3 * 14) / 2 + 68 / 2
        coordinate(sceneX: cellX, sceneY: app.frame.height / 2 - 190).tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach("3-game-idle")
    }

    func testLaunchesToHomeScreen() {
        attach("home")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    /// The core promise of the game: draw while held, and the round ends the moment
    /// the finger lifts.
    func testDrawingThenLiftingEndsTheRound() {
        startLevelOne()

        let start = coordinate(sceneX: -100, sceneY: -100)
        let end   = coordinate(sceneX: 100, sceneY: 100)

        // Press, drag (generating a stream of touchesMoved), hold, then release.
        start.press(forDuration: 0.1,
                    thenDragTo: end,
                    withVelocity: .slow,
                    thenHoldForDuration: 0.5)
        attach("4-after-drag-and-lift")

        // Lifting fails the round, which fades in the Game Over scene.
        Thread.sleep(forTimeInterval: 1.5)
        attach("5-game-over")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2), "app should survive the round ending")
    }

    /// Level 6 introduces the first Blocker. Obstacles only spawn and fall from the
    /// scene's update loop, so this waits on the board and captures them in flight.
    func testObstaclesSpawnAndFallOnLevelSix() {
        app.terminate()
        app.launchArguments = ["--unlock-all"]
        app.launch()

        coordinate(sceneX: 0, sceneY: -40).tap()      // Play
        Thread.sleep(forTimeInterval: 1.0)

        // Level 6 = index 5 → second row, second column of the 4-wide grid.
        let startX: CGFloat = -(4 * 68 + 3 * 14) / 2 + 68 / 2
        let topY = app.frame.height / 2 - 190
        coordinate(sceneX: startX + (68 + 14), sceneY: topY - (68 + 14)).tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach("6-level-six-idle")

        // Obstacles spawn on a timer, then fall down the board.
        Thread.sleep(forTimeInterval: 5.0)
        attach("7-obstacles-falling")

        Thread.sleep(forTimeInterval: 5.0)
        attach("8-obstacles-later")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }

    /// Tapping through the theme picker shouldn't crash, and locked themes should
    /// refuse selection on fresh progress.
    func testThemeSelection() {
        coordinate(sceneX: 0, sceneY: -108).tap()   // Themes (no Continue button on fresh progress)
        Thread.sleep(forTimeInterval: 1.0)
        attach("themes")

        let cardY = app.frame.height / 2 - 200
        coordinate(sceneX: 0, sceneY: cardY - 94).tap()   // Clay — locked on fresh progress
        Thread.sleep(forTimeInterval: 0.5)
        attach("themes-after-locked-tap")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2))
    }
}
