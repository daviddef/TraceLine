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
        app.launchArguments = ["--unlock-all", "--screenshot"] + extraArgs
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
        // 1 — Home
        launch([])
        shoot("01-home")

        // 2 — Gameplay, mid-round, with obstacles on the board (level 8).
        launch(["--demo-path", "--level", "8"])
        Thread.sleep(forTimeInterval: 1.0)
        shoot("02-gameplay")

        // 3 — Level select
        launch([])
        coordinate(sceneX: 0, sceneY: -40).tap()
        Thread.sleep(forTimeInterval: 1.2)
        shoot("03-levels")

        // 4 — Win screen, after the stars have animated in.
        launch(["--debug-win"])
        Thread.sleep(forTimeInterval: 1.8)
        shoot("04-win")

        // 5 — Themes
        launch([])
        coordinate(sceneX: 0, sceneY: -176).tap()   // Themes, with Continue present
        Thread.sleep(forTimeInterval: 1.2)
        shoot("05-themes")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
    }
}
