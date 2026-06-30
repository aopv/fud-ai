import Foundation

/// Central AdMob configuration.
///
/// The **App ID** lives in Info.plist (`GADApplicationIdentifier`) — the SDK reads it from there.
/// These are the per-placement **ad unit IDs** plus the interstitial frequency tuning.
///
/// Right now this uses Google's official **TEST** ad unit IDs, which always fill and never put the
/// AdMob account at risk during development. To go live: paste the real iOS unit IDs into
/// `realBannerUnitID` / `realInterstitialUnitID` and set `useTestAds = false` (and swap the
/// Info.plist `GADApplicationIdentifier` to the real iOS App ID).
enum AdsConfig {
    static let useTestAds = true

    // Google official TEST ad unit IDs (iOS).
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"
    private static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    // TODO: real iOS ad unit IDs from AdMob (then set useTestAds = false).
    private static let realBannerUnitID = ""
    private static let realInterstitialUnitID = ""

    static var bannerUnitID: String {
        (useTestAds || realBannerUnitID.isEmpty) ? testBannerUnitID : realBannerUnitID
    }
    static var interstitialUnitID: String {
        (useTestAds || realInterstitialUnitID.isEmpty) ? testInterstitialUnitID : realInterstitialUnitID
    }

    /// Show an interstitial after every Nth logged meal, capped per calendar day, so logging
    /// stays fast and we don't trip AdMob's "ad overload" policy.
    static let interstitialEveryNLogs = 3
    static let interstitialMaxPerDay = 2
}
