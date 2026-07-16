import XCTest
@testable import TraceLine

/// The IAP shell ships inactive. These tests exist so that flipping it on is a
/// deliberate act with a failing test attached, rather than something that slips into a
/// release — the store listing declares no in-app purchases.
final class StoreTests: XCTestCase {

    func testStoreIsDisabledForV1() {
        XCTAssertFalse(Store.isEnabled,
                       "IAP is stubs-only in v1. Enabling it means creating the products in "
                       + "App Store Connect and updating the listing's IAP declaration first.")
    }

    func testNothingIsPurchasedWhileDisabled() {
        for id in Store.ProductID.allCases {
            XCTAssertFalse(Store.isPurchased(id), "\(id.rawValue) reported as purchased")
        }
    }

    func testNoProductsAreLoadedWhileDisabled() async {
        await Store.loadProducts()
        XCTAssertTrue(Store.products.isEmpty, "a disabled store must not reach StoreKit")
    }

    func testPurchaseIsRefusedWhileDisabled() async {
        for id in Store.ProductID.allCases {
            let ok = await Store.purchase(id)
            XCTAssertFalse(ok, "a disabled store must not transact")
        }
    }

    func testProductIDsAreNamespacedUnderTheBundleID() {
        for id in Store.ProductID.allCases {
            XCTAssertTrue(id.rawValue.hasPrefix("com.defranceski.traceline."),
                          "\(id.rawValue) won't match an App Store Connect product")
        }
    }

    func testProductIDsAreUnique() {
        let ids = Store.ProductID.allCases.map(\.rawValue)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}

final class AnalyticsTests: XCTestCase {

    /// Event names and parameter keys are a wire format: reword the display text freely,
    /// but changing these silently splits a metric in two once a provider is attached.
    func testEventNamesAreStable() {
        XCTAssertEqual(Analytics.Event.levelStarted(id: 1).name, "level_started")
        XCTAssertEqual(Analytics.Event.levelCleared(id: 1, score: 0, stars: 0,
                                                    secondsRemaining: 0).name, "level_cleared")
        XCTAssertEqual(Analytics.Event.levelFailed(id: 1, reason: .lineCrossed,
                                                   coveragePercent: 0).name, "level_failed")
        XCTAssertEqual(Analytics.Event.themeSelected(.neon).name, "theme_selected")
        XCTAssertEqual(Analytics.Event.leaderboardOpened.name, "leaderboard_opened")
    }

    func testFailReasonAnalyticsNamesAreStable() {
        XCTAssertEqual(FailReason.fingerLifted.analyticsName, "finger_lifted")
        XCTAssertEqual(FailReason.lineCrossed.analyticsName, "line_crossed")
        XCTAssertEqual(FailReason.obstacleHit.analyticsName, "obstacle_hit")
        XCTAssertEqual(FailReason.timeExpired.analyticsName, "time_expired")
    }

    func testEventCarriesItsParameters() {
        let params = Analytics.Event.levelCleared(id: 7, score: 4340, stars: 3,
                                                  secondsRemaining: 22).parameters
        XCTAssertEqual(params["level"] as? Int, 7)
        XCTAssertEqual(params["score"] as? Int, 4340)
        XCTAssertEqual(params["stars"] as? Int, 3)
        XCTAssertEqual(params["seconds_remaining"] as? Int, 22)
    }

    func testFailedEventReportsTheReasonAndCoverage() {
        let params = Analytics.Event.levelFailed(id: 3, reason: .obstacleHit,
                                                 coveragePercent: 41).parameters
        XCTAssertEqual(params["reason"] as? String, "obstacle_hit")
        XCTAssertEqual(params["coverage"] as? Int, 41)
    }

    /// No SDK for v1, so nothing may leave the device — the App Store privacy
    /// declaration says data is not collected.
    func testLoggingIsInertAndCannotThrow() {
        Analytics.log(.levelStarted(id: 1))
        Analytics.log(.leaderboardOpened)
        Analytics.log(.themeSelected(.retro))
    }
}
