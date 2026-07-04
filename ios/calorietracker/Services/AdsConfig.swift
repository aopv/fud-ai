import Foundation

/// Central AdMob configuration.
///
/// The **App ID** lives in Info.plist (`GADApplicationIdentifier`) — the SDK reads it from there.
/// This is the banner **ad unit ID** shared by the top banner strip on every tab.
///
/// Live ads are served ONLY by App Store / TestFlight builds. Anything installed locally via
/// Xcode/xcodebuild — including Release-configuration installs on a real device, which is what
/// the dev scheme produces — requests Google's official TEST banner unit instead, so build-test
/// cycles can never generate invalid traffic against the AdMob account. Local builds are
/// detected by the embedded provisioning profile, which Apple strips from App Store/TestFlight
/// distributions. Simulators are additionally test devices by SDK default.
enum AdsConfig {
    // Google official TEST banner ad unit ID (iOS) — always fills, never monetizes.
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

    // Real iOS banner unit ("Banner - all tabs").
    private static let realBannerUnitID = "ca-app-pub-1910432677832151/6618642563"

    /// Dev/ad-hoc installs carry embedded.mobileprovision; App Store and TestFlight builds don't.
    private static let isLocallyInstalledBuild =
        Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil

    /// Banner strip pinned to the top of every tab.
    static var bannerUnitID: String {
        #if DEBUG || targetEnvironment(simulator)
        return testBannerUnitID
        #else
        return isLocallyInstalledBuild ? testBannerUnitID : realBannerUnitID
        #endif
    }
}
