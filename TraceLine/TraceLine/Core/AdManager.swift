import UIKit

/// The seam for AdMob, deliberately inert until the SDK is wired — the same shape as
/// `Store` (IAP) and `Analytics`: the call sites are the valuable part, so adopting the
/// Google Mobile Ads SDK later is a change to this file alone rather than a hunt through
/// the scenes.
///
/// Everything is gated on `isEnabled`, which is false until, in order:
///   1. The `GoogleMobileAds` package is added (SwiftPM) — see project.yml.
///   2. Info.plist carries `GADApplicationIdentifier`, the `SKAdNetworkItems` list, and
///      `NSUserTrackingUsageDescription` (App Tracking Transparency).
///   3. A `PrivacyInfo.xcprivacy` manifest declares the tracking, and the App Store privacy
///      section + PRIVACY.md are updated from "Data Not Collected".
///   4. Real ad-unit ids replace the test ids below.
///   5. The listing copy drops the "No ads" line.
///
/// While disabled, every method is a no-op and the game behaves exactly as it does today.
enum AdManager {

    /// The v1 kill switch. Leave false until the five steps above are done.
    static let isEnabled = false

    /// From App Store Connect (given). Goes in Info.plist as `GADApplicationIdentifier`.
    static let applicationID = "ca-app-pub-4156851882993001~8627606652"

    /// Google's public *test* unit ids — safe to ship in a debug build, and what we develop
    /// against so we never accidentally serve (or click) a live ad. Real ids replace these
    /// at step 4.
    enum Unit {
        static let banner      = "ca-app-pub-3940256099942544/2934735716"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded    = "ca-app-pub-3940256099942544/1712485313"
    }

    /// Ads never reach a paying customer: if the tip/remove-ads product is owned, stay quiet.
    static var adsSuppressed: Bool {
        Store.isPurchased(.tipJar)
    }

    /// Call once at launch. Requests App Tracking Transparency, then starts the SDK.
    static func start() {
        guard isEnabled else { return }
        // GoogleMobileAds: request ATT (iOS 14+), then MobileAds.shared.start(...).
    }

    /// A full-screen ad shown on a natural break — every few level clears, never mid-draw.
    /// Returns whether one was shown, so the caller can sequence what comes after it.
    @discardableResult
    static func showInterstitial(from controller: UIViewController) -> Bool {
        guard isEnabled, !adsSuppressed else { return false }
        // GoogleMobileAds: present a preloaded GADInterstitialAd.
        return false
    }

    /// A rewarded ad the player opts into — e.g. "start this level with a shield". The
    /// completion carries whether the reward was earned (the ad watched to the end).
    static func showRewarded(from controller: UIViewController, reward: @escaping (Bool) -> Void) {
        guard isEnabled, !adsSuppressed else { return reward(false) }
        // GoogleMobileAds: present a GADRewardedAd; call reward(true) in its reward handler.
        reward(false)
    }

    /// A banner for the game-over screen. Returns the view to place, or nil while disabled —
    /// the scene adds nothing when nil, so the layout is unchanged until ads are live.
    static func makeGameOverBanner() -> UIView? {
        guard isEnabled, !adsSuppressed else { return nil }
        // GoogleMobileAds: return a configured GADBannerView(adSize:).
        return nil
    }
}
