import Foundation
import WidgetKit

/// Writes a WidgetSnapshot into the shared App Group container and asks
/// WidgetKit to refresh all timelines. Widgets can't read the main app's
/// private UserDefaults, so any data the widget needs has to go through here.
enum WidgetSnapshotWriter {
    /// Recomputes today's totals from the current FoodStore + ProfileStore and
    /// publishes them to the widget.
    static func publish(foods: [FoodEntry], profile: UserProfile) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        // Must be same-day — `timestamp >= startOfDay` alone would fold future-logged
        // entries (meals planned on tomorrow via the week strip) into today's totals.
        let today = foods.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }

        let cal = today.reduce(0) { $0 + $1.calories }
        let p = today.reduce(0) { $0 + $1.protein }
        let c = today.reduce(0) { $0 + $1.carbs }
        let f = today.reduce(0) { $0 + $1.fat }
        let selectedHomeNutrients = HomeTopNutrient.selection(
            from: UserDefaults.standard.string(forKey: HomeTopNutrient.storageKey)
                ?? HomeTopNutrient.storageValue(for: HomeTopNutrient.defaultSelection)
        )
        let optionalGoals = OptionalNutrientGoals.current
        let theme = AppThemeColor(
            rawValue: UserDefaults.standard.string(forKey: AppThemeColor.storageKey) ?? ""
        ) ?? .defaultColor
        let waterEntries: [WaterEntry] = UserDefaults.standard.data(forKey: WaterSettings.entriesKey)
            .flatMap { try? JSONDecoder().decode([WaterEntry].self, from: $0) } ?? []
        let waterCurrentMl = waterEntries
            .filter { calendar.isDate($0.date, inSameDayAs: Date()) }
            .reduce(0) { $0 + $1.milliliters }
        let storedWaterGoal = UserDefaults.standard.integer(forKey: WaterSettings.dailyGoalKey)
        let waterGoalMl = storedWaterGoal > 0 ? storedWaterGoal : WaterSettings.defaultDailyGoalMl

        let snapshot = WidgetSnapshot(
            date: Date(),
            dayStart: startOfDay,
            calories: cal,
            calorieGoal: profile.effectiveCalories,
            protein: p,
            proteinGoal: profile.effectiveProtein,
            carbs: c,
            carbsGoal: profile.effectiveCarbs,
            fat: f,
            fatGoal: profile.effectiveFat,
            homeNutrients: selectedHomeNutrients.map {
                homeNutrientValue(for: $0, foods: today, profile: profile, optionalGoals: optionalGoals)
            },
            waterTrackingEnabled: UserDefaults.standard.bool(forKey: WaterSettings.enabledKey),
            waterCurrentMl: waterCurrentMl,
            waterGoalMl: waterGoalMl,
            waterUnitRaw: UserDefaults.standard.string(forKey: WaterSettings.unitKey) ?? WaterUnit.defaultUnit.rawValue,
            themeStartHex: theme.startHex,
            themeEndHex: theme.endHex
        )

        if WidgetSnapshot.read() != snapshot {
            WidgetSnapshot.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        }
        WatchSnapshotSync.shared.send(snapshot)
    }

    private static func homeNutrientValue(
        for nutrient: HomeTopNutrient,
        foods: [FoodEntry],
        profile: UserProfile,
        optionalGoals: OptionalNutrientGoals
    ) -> WidgetNutrientValue {
        WidgetNutrientValue(
            id: nutrient.rawValue,
            label: nutrient.displayName,
            shortLabel: shortLabel(for: nutrient),
            unit: nutrient.unit,
            iconName: nutrient.iconName,
            value: currentValue(for: nutrient, foods: foods),
            goal: nutrient.goal(for: profile, optionalGoals: optionalGoals)
        )
    }

    private static func currentValue(for nutrient: HomeTopNutrient, foods: [FoodEntry]) -> Double {
        switch nutrient {
        case .protein:
            return Double(foods.reduce(0) { $0 + $1.protein })
        case .carbs:
            return Double(foods.reduce(0) { $0 + $1.carbs })
        case .fat:
            return Double(foods.reduce(0) { $0 + $1.fat })
        case .fiber:
            return sum(foods, \.fiber)
        case .sugar:
            return sum(foods, \.sugar)
        case .addedSugar:
            return sum(foods, \.addedSugar)
        case .saturatedFat:
            return sum(foods, \.saturatedFat)
        case .cholesterol:
            return sum(foods, \.cholesterol)
        case .sodium:
            return sum(foods, \.sodium)
        case .potassium:
            return sum(foods, \.potassium)
        case .transFat:
            return sum(foods, \.transFat)
        case .calcium:
            return sum(foods, \.calcium)
        case .iron:
            return sum(foods, \.iron)
        case .magnesium:
            return sum(foods, \.magnesium)
        case .zinc:
            return sum(foods, \.zinc)
        case .vitaminA:
            return sum(foods, \.vitaminA)
        case .vitaminC:
            return sum(foods, \.vitaminC)
        case .vitaminD:
            return sum(foods, \.vitaminD)
        case .vitaminB12:
            return sum(foods, \.vitaminB12)
        case .vitaminE:
            return sum(foods, \.vitaminE)
        case .vitaminK:
            return sum(foods, \.vitaminK)
        case .folate:
            return sum(foods, \.folate)
        case .omega3:
            return sum(foods, \.omega3)
        }
    }

    private static func sum(_ foods: [FoodEntry], _ keyPath: KeyPath<FoodEntry, Double?>) -> Double {
        foods.reduce(0) { $0 + ($1[keyPath: keyPath] ?? 0) }
    }

    private static func shortLabel(for nutrient: HomeTopNutrient) -> String {
        String(nutrient.displayName.prefix(1)).uppercased()
    }
}
