import SwiftUI
import GoogleMobileAds

/// The 50pt ad strip pinned above each tab's content via
/// `.safeAreaInset(edge: .top) { AdBannerStrip() }`.
///
/// Opaque all the way up through the status bar, so scrolled content never
/// peeks out above the ad; shows a subtle placeholder until the first ad
/// arrives, so a late fill doesn't pop into an empty-looking gap.
struct AdBannerStrip: View {
    @State private var isLoaded = false

    var body: some View {
        ZStack {
            if !isLoaded {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.secondary.opacity(0.08))
                    .overlay {
                        Text("Ad")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary.opacity(0.55))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 3)
            }
            BannerAdView(isLoaded: $isLoaded)
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(AppColors.appBackground.ignoresSafeArea(edges: .top))
    }
}

/// A standard (320×50) AdMob banner wrapped for SwiftUI. Reports the first
/// successful fill through `isLoaded` so the strip can drop its placeholder.
struct BannerAdView: UIViewRepresentable {
    @Binding var isLoaded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdsConfig.bannerUnitID
        banner.delegate = context.coordinator
        // Defer the load until the banner is in the hierarchy and a root view controller is
        // available — otherwise (e.g. inside a toolbar) the ad never renders.
        DispatchQueue.main.async {
            banner.rootViewController = AdsManager.topViewController()
            banner.load(Request())
        }
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = AdsManager.topViewController()
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let parent: BannerAdView

        init(_ parent: BannerAdView) {
            self.parent = parent
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            parent.isLoaded = true
        }
    }
}
