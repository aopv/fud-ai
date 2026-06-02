import Foundation

nonisolated struct WidgetNutrientValue: Codable, Equatable, Identifiable {
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
    var displayCurrentWithUnit: String { "\(displayValue)\(unit)" }
    var displayGoalWithUnit: String { "\(displayGoal)\(unit)" }
    var displayPair: String { "\(displayCurrentWithUnit) / \(displayGoalWithUnit)" }
    var displayRemaining: String { "\(Self.format(max(0, goal - value)))\(unit) left" }

    func zeroedForToday() -> WidgetNutrientValue {
        WidgetNutrientValue(
            id: id,
            label: label,
            shortLabel: shortLabel,
            unit: unit,
            iconName: iconName,
            value: 0,
            goal: goal
        )
    }

    private static func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }
}

/// Small Codable snapshot of today's totals + goals that the widget extension
/// reads out of the shared App Group container. The main app writes it on
/// every FoodStore change; the widget re-reads on its timeline refresh.
///
/// The widget target has its own copy of this file (FudAIWidgets/WidgetSnapshot.swift).
/// Keep the two in sync or decoding will fail silently.
nonisolated struct WidgetSnapshot: Codable, Equatable {
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
    let homeNutrients: [WidgetNutrientValue]?

    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
            ?? "group.com.apoorvdarshan.calorietracker"
    }
    private static let key = "widget_snapshot_v1"
    static let watchPayloadKey = "widget_snapshot_data_v1"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func read() -> WidgetSnapshot? {
        guard let data = sharedDefaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        sharedDefaults?.set(data, forKey: key)
    }

    var payloadData: Data? {
        try? JSONEncoder().encode(self)
    }

    static func decodePayload(_ data: Data) -> WidgetSnapshot? {
        try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Wipes the shared snapshot. Called from Delete All Data so widgets don't keep
    /// showing the previous profile's numbers after a reset.
    static func clear() {
        sharedDefaults?.removeObject(forKey: key)
    }

    static var placeholder: WidgetSnapshot {
        let now = Date()
        return WidgetSnapshot(
            date: now,
            dayStart: Calendar.current.startOfDay(for: now),
            calories: 1247, calorieGoal: 2000,
            protein: 84, proteinGoal: 150,
            carbs: 132, carbsGoal: 220,
            fat: 42, fatGoal: 70,
            homeNutrients: [
                WidgetNutrientValue(id: "protein", label: "Protein", shortLabel: "P", unit: "g", iconName: "fork.knife", value: 84, goal: 150),
                WidgetNutrientValue(id: "carbs", label: "Carbs", shortLabel: "C", unit: "g", iconName: "leaf", value: 132, goal: 220),
                WidgetNutrientValue(id: "fat", label: "Fat", shortLabel: "F", unit: "g", iconName: "drop.fill", value: 42, goal: 70),
            ]
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
            fat: 0, fatGoal: 70,
            homeNutrients: [
                WidgetNutrientValue(id: "protein", label: "Protein", shortLabel: "P", unit: "g", iconName: "fork.knife", value: 0, goal: 150),
                WidgetNutrientValue(id: "carbs", label: "Carbs", shortLabel: "C", unit: "g", iconName: "leaf", value: 0, goal: 220),
                WidgetNutrientValue(id: "fat", label: "Fat", shortLabel: "F", unit: "g", iconName: "drop.fill", value: 0, goal: 70),
            ]
        )
    }

    var displayedHomeNutrients: [WidgetNutrientValue] {
        let selected = homeNutrients?.filter { !$0.id.isEmpty } ?? []
        var merged: [WidgetNutrientValue] = []
        for nutrient in selected + defaultHomeNutrients {
            guard !merged.contains(where: { $0.id == nutrient.id }) else { continue }
            merged.append(nutrient)
            if merged.count == 3 { break }
        }
        return merged
    }

    var primaryHomeNutrient: WidgetNutrientValue {
        displayedHomeNutrients.first ?? defaultHomeNutrients[0]
    }

    var homeNutrientsSummary: String {
        displayedHomeNutrients
            .map { "\($0.summaryLabel)\($0.displayValue)" }
            .joined(separator: " · ")
    }

    func emptyForToday(_ now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(
            date: now,
            dayStart: Calendar.current.startOfDay(for: now),
            calories: 0,
            calorieGoal: calorieGoal,
            protein: 0,
            proteinGoal: proteinGoal,
            carbs: 0,
            carbsGoal: carbsGoal,
            fat: 0,
            fatGoal: fatGoal,
            homeNutrients: displayedHomeNutrients.map { $0.zeroedForToday() }
        )
    }

    var caloriesRemaining: Int { max(0, calorieGoal - calories) }
    var proteinRemaining: Double { max(0, Double(proteinGoal) - protein) }
    var carbsRemaining: Double { max(0, Double(carbsGoal) - carbs) }
    var fatRemaining: Double { max(0, Double(fatGoal) - fat) }
    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(1.0, Double(calories) / Double(calorieGoal))
    }
    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(1.0, protein / Double(proteinGoal))
    }
    var carbsProgress: Double {
        guard carbsGoal > 0 else { return 0 }
        return min(1.0, carbs / Double(carbsGoal))
    }
    var fatProgress: Double {
        guard fatGoal > 0 else { return 0 }
        return min(1.0, fat / Double(fatGoal))
    }

    private var defaultHomeNutrients: [WidgetNutrientValue] {
        [
            WidgetNutrientValue(id: "protein", label: "Protein", shortLabel: "P", unit: "g", iconName: "fork.knife", value: protein, goal: Double(proteinGoal)),
            WidgetNutrientValue(id: "carbs", label: "Carbs", shortLabel: "C", unit: "g", iconName: "leaf", value: carbs, goal: Double(carbsGoal)),
            WidgetNutrientValue(id: "fat", label: "Fat", shortLabel: "F", unit: "g", iconName: "drop.fill", value: fat, goal: Double(fatGoal)),
        ]
    }
}

private extension WidgetNutrientValue {
    nonisolated var summaryLabel: String {
        String(label.prefix(1)).uppercased()
    }
}
