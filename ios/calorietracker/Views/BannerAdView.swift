import SwiftUI
import GoogleMobileAds

/// An AdMob banner/rectangle wrapped for SwiftUI.
///
/// - Home uses the default 320×50 banner pinned to the bottom via
///   `.safeAreaInset(edge: .bottom) { BannerAdView().frame(height: 50) }`.
/// - The analyzing screen uses a 300×250 medium rectangle:
///   `BannerAdView(unitID: AdsConfig.analyzingUnitID, format: .mediumRectangle).frame(width: 300, height: 250)`.
struct BannerAdView: UIViewRepresentable {
    enum Format { case banner, mediumRectangle }

    var unitID: String = AdsConfig.bannerUnitID
    var format: Format = .banner

    private var adSize: AdSize {
        format == .mediumRectangle ? AdSizeMediumRectangle : AdSizeBanner
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = unitID
        banner.rootViewController = AdsManager.topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = AdsManager.topViewController()
        }
    }
}
