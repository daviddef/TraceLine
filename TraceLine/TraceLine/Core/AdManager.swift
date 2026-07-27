import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// AdMob, non-personalized. The real SDK calls are guarded by `canImport(GoogleMobileAds)`,
/// so this file compiles with or without the package: without it (as in CI that can't fetch
/// the SDK) every method is inert and the game shows no ads; with it (a normal Xcode build
/// once the SwiftPM package is added) ads are live. `isEnabled` follows `canImport`, so
/// adding the package *is* the switch — there is no flag to forget, and a build without the
/// SDK can never show an empty ad break.
///
/// Non-personalized: every request carries `npa=1`, so no advertising identifier is used for
/// tracking. That is why there is no App Tracking Transparency prompt and the privacy
/// declaration needs no "used to track you" — matched by PrivacyInfo.xcprivacy.
///
/// SDK API targets Google Mobile Ads v11/v12 (the no-"GAD"-prefix Swift naming). If the
/// version SwiftPM resolves differs, the symbols below are where to adjust.
enum AdManager {

    /// Live only when the SDK is linked. Adding the SwiftPM package turns ads on.
    static var isEnabled: Bool {
        #if canImport(GoogleMobileAds)
        return true
        #else
        return false
        #endif
    }

    /// From App Store Connect. Also goes in Info.plist as `GADApplicationIdentifier`.
    static let applicationID = "ca-app-pub-4156851882993001~8627606652"

    /// Ad-unit ids. DEBUG builds use Google's public *test* ids so development never serves
    /// (or clicks) a live ad; release builds use the real TraceLine units.
    enum Unit {
        #if DEBUG
        static let banner   = "ca-app-pub-3940256099942544/2934735716"   // Google test
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"   // Google test
        #else
        static let banner   = "ca-app-pub-4156851882993001/4757478552"   // TraceLine banner
        static let rewarded = "ca-app-pub-4156851882993001/3444396883"   // TraceLine rewarded
        #endif
    }

    /// Ads never reach a paying customer: if the tip/remove-ads product is owned, stay quiet.
    static var adsSuppressed: Bool { Store.isPurchased(.tipJar) }

    /// Game-over ad cadence: most fails restart instantly; every Nth is an ad break with a
    /// banner. Counting survives the per-level scene rebuilds, and returns false whenever ads
    /// are off — so the instant auto-restart is unchanged until the SDK is live.
    static let adBreakEvery = 5
    private static var failsSinceBreak = 0

    static func shouldBreakForAd() -> Bool {
        guard isEnabled, !adsSuppressed else { return false }
        failsSinceBreak += 1
        if failsSinceBreak >= adBreakEvery {
            failsSinceBreak = 0
            return true
        }
        return false
    }

    /// Call once at launch. Non-personalized, so no ATT request is needed first.
    static func start() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        #endif
    }

    /// A rewarded ad the player opts into — e.g. "start this level with a shield". The
    /// completion carries whether the reward was earned. (A player who dismisses the ad
    /// early simply is not rewarded; the caller should assume no reward until told otherwise.)
    static func showRewarded(from controller: UIViewController, reward: @escaping (Bool) -> Void) {
        #if canImport(GoogleMobileAds)
        guard !adsSuppressed else { return reward(false) }
        RewardedAd.load(with: Unit.rewarded, request: nonPersonalizedRequest()) { ad, error in
            guard let ad, error == nil else { return reward(false) }
            loadedRewarded = ad          // retain it while it is on screen
            ad.present(from: controller) {
                reward(true)
                loadedRewarded = nil
            }
        }
        #else
        reward(false)
        #endif
    }

    /// A banner for the game-over break. Returns the view to place, or nil while disabled —
    /// the scene adds nothing when nil, so the layout is unchanged until ads are live.
    static func makeGameOverBanner() -> UIView? {
        #if canImport(GoogleMobileAds)
        guard !adsSuppressed else { return nil }
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = Unit.banner
        banner.rootViewController = topViewController()
        banner.load(nonPersonalizedRequest())
        return banner
        #else
        return nil
        #endif
    }

    #if canImport(GoogleMobileAds)
    /// Holds the rewarded ad while it is presented, so it is not deallocated mid-play.
    private static var loadedRewarded: RewardedAd?

    /// Every request opts out of personalization (`npa=1`) — no identifier used for tracking.
    private static func nonPersonalizedRequest() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    /// The frontmost view controller, for presenting/rooting ads.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif
}
