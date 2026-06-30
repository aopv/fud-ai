import Foundation

/// Central AdMob configuration.
///
/// The **App ID** lives in Info.plist (`GADApplicationIdentifier`) — the SDK reads it from there.
/// These are the per-placement **ad unit IDs**.
///
/// Right now this uses Google's official **TEST** ad unit IDs, which always fill and never put the
/// AdMob account at risk during development. To go live: paste the real iOS unit IDs into the
/// `real…` fields and set `useTestAds = false` (and swap the Info.plist `GADApplicationIdentifier`
/// to the real iOS App ID).
enum AdsConfig {
    static let useTestAds = true

    // Google official TEST ad unit ID (iOS) — fills any banner/rectangle size.
    private static let testUnitID = "ca-app-pub-3940256099942544/2934735716"

    // TODO: real iOS ad unit IDs from AdMob (then set useTestAds = false).
    // A dedicated medium-rectangle unit for the analyzing screen is recommended in production.
    private static let realBannerUnitID = ""     // Home bottom banner (320×50)
    private static let realAnalyzingUnitID = ""  // Analyzing screen (300×250 medium rectangle)

    /// Banner pinned to the bottom of Home.
    static var bannerUnitID: String {
        (useTestAds || realBannerUnitID.isEmpty) ? testUnitID : realBannerUnitID
    }

    /// Medium rectangle shown while the AI analyzes the food.
    static var analyzingUnitID: String {
        (useTestAds || realAnalyzingUnitID.isEmpty) ? testUnitID : realAnalyzingUnitID
    }
}
