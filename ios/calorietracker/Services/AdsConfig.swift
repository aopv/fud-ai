import Foundation

/// Central AdMob configuration.
///
/// The **App ID** lives in Info.plist (`GADApplicationIdentifier`) — the SDK reads it from there.
/// This is the banner **ad unit ID** used for the bottom banner on Home and Progress.
///
/// Right now it uses Google's official **TEST** ad unit ID, which always fills and never puts the
/// AdMob account at risk during development. To go live: paste the real iOS unit ID into
/// `realBannerUnitID` and set `useTestAds = false` (and swap the Info.plist
/// `GADApplicationIdentifier` to the real iOS App ID).
enum AdsConfig {
    static let useTestAds = true

    // Google official TEST banner ad unit ID (iOS).
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    // TODO: real iOS banner ad unit ID from AdMob (then set useTestAds = false).
    private static let realBannerUnitID = ""

    /// Banner pinned to the bottom of Home and Progress.
    static var bannerUnitID: String {
        (useTestAds || realBannerUnitID.isEmpty) ? testBannerUnitID : realBannerUnitID
    }
}
