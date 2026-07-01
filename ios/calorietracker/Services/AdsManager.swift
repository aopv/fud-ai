import UIKit
import GoogleMobileAds
import AppTrackingTransparency

/// Owns the Google Mobile Ads (AdMob) lifecycle: SDK start and the App Tracking Transparency
/// prompt. Ads themselves are inline banners/rectangles rendered by `BannerAdView`.
@MainActor
final class AdsManager {
    static let shared = AdsManager()

    private var started = false

    /// Call once after onboarding completes (from the main ContentView).
    func start() {
        guard !started else { return }
        started = true
        MobileAds.shared.start(completionHandler: nil)
        requestTrackingIfNeeded()
    }

    /// Apple App Tracking Transparency. Only prompts once (when status is undetermined); a short
    /// delay lets the UI settle first, which Apple requires (the app must be active).
    private func requestTrackingIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }

    /// The frontmost view controller, used as the banner's `rootViewController`.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
