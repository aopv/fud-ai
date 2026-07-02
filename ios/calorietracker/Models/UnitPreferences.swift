import Foundation

// MARK: - Unit Preferences

/// Length display unit. Governs height + body-measurement display/input and the
/// AI prompt height lines. Stored values stay canonical metric (cm) everywhere.
enum HeightUnit: String {
    case cm
    case ftin

    nonisolated static let storageKey = "heightUnit"

    /// Current preference for non-view code (services, app-level calls).
    /// Views should bind `@AppStorage("heightUnit")` directly.
    nonisolated static var current: HeightUnit {
        HeightUnit(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .ftin
    }
}

/// Mass display unit. Governs weight/goal-weight display/input, the weight chart,
/// AI prompt weight/rate lines, and the Siri unit-less fallback. Stored values
/// stay canonical metric (kg) everywhere.
enum WeightUnit: String {
    case kg
    case lbs

    nonisolated static let storageKey = "weightUnit"

    /// Current preference for non-view code (services, app-level calls).
    /// Views should bind `@AppStorage("weightUnit")` directly.
    nonisolated static var current: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .lbs
    }
}

enum UnitPreferenceMigration {
    /// One-time migration from the legacy single `useMetric` flag to the split
    /// height/weight unit preferences. Runs before any view reads the new keys,
    /// so existing users see zero change (metric -> cm + kg, imperial -> ftin + lbs).
    /// The legacy key is left in storage untouched.
    nonisolated static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: HeightUnit.storageKey) == nil else { return }
        let useMetric = defaults.bool(forKey: "useMetric")
        defaults.set((useMetric ? HeightUnit.cm : HeightUnit.ftin).rawValue, forKey: HeightUnit.storageKey)
        defaults.set((useMetric ? WeightUnit.kg : WeightUnit.lbs).rawValue, forKey: WeightUnit.storageKey)
    }
}
