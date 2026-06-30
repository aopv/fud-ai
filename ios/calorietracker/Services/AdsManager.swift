import UIKit
import GoogleMobileAds
import AppTrackingTransparency

extension Notification.Name {
    /// Posted by FoodStore whenever the user logs a meal, so the ad manager can decide whether
    /// to surface an interstitial (frequency-capped). Decoupled so the data layer never imports ads.
    static let fudMealLogged = Notification.Name("fudMealLogged")
}

/// Owns the Google Mobile Ads (AdMob) lifecycle: SDK start, ATT prompt, interstitial loading and
/// frequency-capped presentation. Banner ads are handled separately by `BannerAdView`.
@MainActor
final class AdsManager: NSObject {
    static let shared = AdsManager()

    private var interstitial: InterstitialAd?
    private var loggedSinceLastAd = 0
    private var started = false

    private let shownDateKey = "adsInterstitialShownDate"
    private let shownCountKey = "adsInterstitialShownCount"

    /// Call once after onboarding completes (from the main ContentView).
    func start() {
        guard !started else { return }
        started = true
        MobileAds.shared.start(completionHandler: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleMealLogged), name: .fudMealLogged, object: nil
        )
        loadInterstitial()
        requestTrackingIfNeeded()
    }

    /// Apple App Tracking Transparency. Only prompts once (when status is undetermined); a short
    /// delay lets the UI settle first, which Apple requires (app must be active).
    private func requestTrackingIfNeeded() {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }

    private func loadInterstitial() {
        InterstitialAd.load(with: AdsConfig.interstitialUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            guard let ad else { return }
            ad.fullScreenContentDelegate = self
            self.interstitial = ad
        }
    }

    @objc private func handleMealLogged() {
        // Only when the user is actively in the app — never from Siri / widget / background logging.
        guard UIApplication.shared.applicationState == .active else { return }
        loggedSinceLastAd += 1
        guard loggedSinceLastAd >= AdsConfig.interstitialEveryNLogs else { return }
        guard remainingToday() > 0,
              let ad = interstitial,
              let vc = Self.topViewController() else { return }
        loggedSinceLastAd = 0
        recordShown()
        ad.present(from: vc)
    }

    // MARK: - Daily cap (persisted so it survives relaunches within the day)

    private func remainingToday() -> Int {
        let count = (UserDefaults.standard.string(forKey: shownDateKey) == Self.todayString())
            ? UserDefaults.standard.integer(forKey: shownCountKey) : 0
        return max(0, AdsConfig.interstitialMaxPerDay - count)
    }

    private func recordShown() {
        let today = Self.todayString()
        let count = (UserDefaults.standard.string(forKey: shownDateKey) == today)
            ? UserDefaults.standard.integer(forKey: shownCountKey) : 0
        UserDefaults.standard.set(today, forKey: shownDateKey)
        UserDefaults.standard.set(count + 1, forKey: shownCountKey)
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// The frontmost view controller to present full-screen ads from.
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension AdsManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitial = nil
        loadInterstitial()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
        loadInterstitial()
    }
}
