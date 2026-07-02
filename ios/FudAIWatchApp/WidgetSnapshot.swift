import Foundation

/// One user-selected Home nutrient (protein/carbs/fat/fiber by default, editable
/// in the iPhone app). Mirror of the phone's WidgetNutrientValue — keep in sync.
struct WidgetNutrientValue: Codable, Equatable, Identifiable {
    let id: String
    let label: String
    let shortLabel: String
    let unit: String
    let iconName: String
    let value: Double
    let goal: Double

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, value / goal)
    }

    var displayValue: String { Self.format(value) }
    var displayGoal: String { Self.format(goal) }

    func zeroedForToday() -> WidgetNutrientValue {
        WidgetNutrientValue(
            id: id, label: label, shortLabel: shortLabel, unit: unit,
            iconName: iconName, value: 0, goal: goal
        )
    }

    private static func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }
}

struct WidgetSnapshot: Codable, Equatable {
    let date: Date
    let dayStart: Date
    let calories: Int
    let calorieGoal: Int
    let protein: Double
    let proteinGoal: Int
    let carbs: Double
    let carbsGoal: Int
    let fat: Double
    let fatGoal: Int
    /// The user's 4 selected Home nutrients. Optional — snapshots from older
    /// iPhone builds lack it; fall back to the legacy protein/carbs/fat fields.
    var homeNutrients: [WidgetNutrientValue]?
    /// User's theme gradient as raw hex (e.g. 0xFF375F). Fud Pink when absent.
    var themeStartHex: UInt?
    var themeEndHex: UInt?

    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.com.apoorvdarshan.calorietracker"
    }

    static let watchPayloadKey = "widget_snapshot_data_v1"
    private static let key = "widget_snapshot_v1"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func read() -> WidgetSnapshot? {
        guard let data = sharedDefaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }

        return snapshot.normalizedForToday()
    }

    func normalizedForToday(_ now: Date = Date()) -> WidgetSnapshot {
        let today = Calendar.current.startOfDay(for: now)
        guard Calendar.current.isDate(dayStart, inSameDayAs: today) else {
            return zeroedForToday(now)
        }
        return self
    }

    private func zeroedForToday(_ now: Date) -> WidgetSnapshot {
        let today = Calendar.current.startOfDay(for: now)
        // New day: reset progress to zero but keep the user's goals, nutrient
        // selection, and theme so the Watch doesn't fall back to defaults.
        return WidgetSnapshot(
            date: now,
            dayStart: today,
            calories: 0, calorieGoal: calorieGoal,
            protein: 0, proteinGoal: proteinGoal,
            carbs: 0, carbsGoal: carbsGoal,
            fat: 0, fatGoal: fatGoal,
            homeNutrients: homeNutrients?.map { $0.zeroedForToday() },
            themeStartHex: themeStartHex,
            themeEndHex: themeEndHex
        )
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: key)
    }

    static func decodePayload(_ data: Data) -> WidgetSnapshot? {
        try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static var placeholder: WidgetSnapshot {
        let now = Date()
        return WidgetSnapshot(
            date: now,
            dayStart: Calendar.current.startOfDay(for: now),
            calories: 1247, calorieGoal: 2000,
            protein: 84, proteinGoal: 150,
            carbs: 132, carbsGoal: 220,
            fat: 42, fatGoal: 70
        )
    }

    static var empty: WidgetSnapshot {
        let now = Date()
        return WidgetSnapshot(
            date: now,
            dayStart: Calendar.current.startOfDay(for: now),
            calories: 0, calorieGoal: 2000,
            protein: 0, proteinGoal: 150,
            carbs: 0, carbsGoal: 220,
            fat: 0, fatGoal: 70
        )
    }

    /// The 4 nutrient cards to render, matching the iPhone Home selection.
    /// Legacy snapshots (no homeNutrients) yield the classic protein/carbs/fat.
    var displayedHomeNutrients: [WidgetNutrientValue] {
        if let homeNutrients, !homeNutrients.isEmpty {
            return Array(homeNutrients.prefix(4))
        }
        return [
            WidgetNutrientValue(id: "protein", label: "Protein", shortLabel: "P", unit: "g", iconName: "fork.knife", value: protein, goal: Double(proteinGoal)),
            WidgetNutrientValue(id: "carbs", label: "Carbs", shortLabel: "C", unit: "g", iconName: "leaf", value: carbs, goal: Double(carbsGoal)),
            WidgetNutrientValue(id: "fat", label: "Fat", shortLabel: "F", unit: "g", iconName: "drop.fill", value: fat, goal: Double(fatGoal)),
        ]
    }

    var caloriesRemaining: Int { max(0, calorieGoal - calories) }
    var proteinRemaining: Double { max(0, Double(proteinGoal) - protein) }
    var carbsRemaining: Double { max(0, Double(carbsGoal) - carbs) }
    var fatRemaining: Double { max(0, Double(fatGoal) - fat) }

    var calorieProgress: Double {
        progress(value: Double(calories), goal: calorieGoal)
    }

    var proteinProgress: Double {
        progress(value: protein, goal: proteinGoal)
    }

    var carbsProgress: Double {
        progress(value: carbs, goal: carbsGoal)
    }

    var fatProgress: Double {
        progress(value: fat, goal: fatGoal)
    }

    private func progress(value: Double, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1.0, value / Double(goal))
    }
}
