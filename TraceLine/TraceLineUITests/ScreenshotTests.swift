import XCTest

/// Captures App Store screenshots. Run against a 6.9" device (iPhone 17 Pro Max) —
/// Apple sizes the store listing from that class.
///
///     xcodebuild test -only-testing:TraceLineUITests/ScreenshotTests \
///       -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
///
/// Then export with: xcrun xcresulttool export attachments
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ extraArgs: [String]) {
        app = XCUIApplication()
        // Progress is set per shot, not globally: --unlock-all stars every level, which
        // would erase the level map's whole story.
        app.launchArguments = ["--screenshot"] + extraArgs
        app.launch()
        Thread.sleep(forTimeInterval: 1.2)
    }

    private func coordinate(sceneX: CGFloat, sceneY: CGFloat) -> XCUICoordinate {
        let frame = app.frame
        return app.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + sceneX / frame.width,
                                                             dy: 0.5 - sceneY / frame.height))
    }

    private func shoot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testCaptureStoreScreenshots() {
        // 1 — Home, part-way through so Continue and a best score are both real.
        launch(["--reset-progress", "--progress", "4"])
        shoot("01-home")

        // 2 — Gameplay, mid-round. Level 7 is the fullest board: blockers, movers, a
        // cutter on its lane with the doomed tail lit up, and two shelters.
        launch(["--demo-path", "--level", "7"])
        Thread.sleep(forTimeInterval: 1.0)
        shoot("02-gameplay")

        // 3 — Level select, mid-journey: the trail is the story, and a fully-cleared
        // board would show none of it.
        launch(["--reset-progress", "--progress", "4"])
        coordinate(sceneX: 0, sceneY: -40).tap()
        Thread.sleep(forTimeInterval: 1.5)
        shoot("03-levels")

        // 4 — Win screen, after the stars have animated in.
        launch(["--debug-win"])
        Thread.sleep(forTimeInterval: 1.8)
        shoot("04-win")

        // 5 — Themes. Needs every theme unlocked to show all four.
        launch(["--unlock-all"])
        coordinate(sceneX: 0, sceneY: -176).tap()   // Themes, with Continue present
        Thread.sleep(forTimeInterval: 1.2)
        shoot("05-themes")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
    }
}
