import Foundation
import SwiftUI

/// Shared, observable wrapper around `UserProfile` so every view sees the same instance.
/// Listens for `.userProfileDidChange` (posted by `UserProfile.save()`) so external writers
/// — Settings @State, Onboarding, HealthKit observers, WeightStore — propagate to all observing views.
@MainActor
@Observable
class ProfileStore {
    var profile: UserProfile

    init() {
        self.profile = UserProfile.load() ?? .default
        NotificationCenter.default.addObserver(
            forName: .userProfileDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromDisk()
        }
    }

    /// Reload from disk (e.g., after `--reset-onboarding` wipes UserDefaults).
    func reloadFromDisk() {
        profile = UserProfile.load() ?? .default
    }
}
