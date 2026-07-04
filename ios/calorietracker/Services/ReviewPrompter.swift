import UIKit
import StoreKit

/// Fires the native rate-limited review prompt once, right after the first
/// successful food log — the highest-intent moment — instead of during
/// onboarding, where the user hasn't experienced the app yet. (The onboarding
/// rating screen deep-links to the App Store write-review page instead.)
enum ReviewPrompter {
    private static let promptedKey = "didPromptReviewAfterFirstLog"

    static func foodWasLogged() {
        guard !UserDefaults.standard.bool(forKey: promptedKey) else { return }
        UserDefaults.standard.set(true, forKey: promptedKey)
        // Small delay so the log-success UI settles before the sheet appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        }
    }
}
