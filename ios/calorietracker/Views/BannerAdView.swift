import SwiftUI
import GoogleMobileAds

/// A standard (320×50) AdMob banner wrapped for SwiftUI. Pin it to the bottom of a screen via
/// `.safeAreaInset(edge: .bottom) { BannerAdView().frame(height: 50) }`.
struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdsConfig.bannerUnitID
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
