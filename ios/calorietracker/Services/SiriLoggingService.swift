import Foundation

@MainActor
enum SiriLoggingService {
    enum WeightInputError: LocalizedError {
        case missingNumber
        case invalidRange

        var errorDescription: String? {
            switch self {
            case .missingNumber:
                "Please say a weight, such as 75 kilograms or 165 pounds."
            case .invalidRange:
                "That does not look like a valid weight."
            }
        }
    }

    struct NutritionSummary {
        let calories: Int
        let protein: Double
        let calorieGoal: Int
    }

    struct LoggedWeight {
        let entry: WeightEntry
        let displayValue: Double
        let unitName: String
    }

    static func analyzeAndLogFood(description: String) async throws -> FoodEntry {
        let analysis = try await GeminiService.analyzeTextInput(description: description)
        let entry = foodEntry(from: analysis)

        let foodStore = FoodStore(observesExternalChanges: false)
        foodStore.addEntry(entry)

        HealthKitManager().writeNutrition(for: entry)
        publishAfterFoodChange(foodStore: foodStore)
        FoodStore.postExternalChangeNotification()

        return entry
    }

    static func todayNutritionSummary() -> NutritionSummary {
        let store = FoodStore(observesExternalChanges: false)
        let goal = UserProfile.load()?.effectiveCalories ?? 0
        return NutritionSummary(
            calories: store.todayCalories,
            protein: store.todayProtein,
            calorieGoal: goal
        )
    }

    static func logWeight(description: String) throws -> LoggedWeight {
        let parsed = try parseWeight(description)
        return logWeight(kg: parsed.kg, displayValue: parsed.displayValue, unitName: parsed.unitName)
    }

    private static func logWeight(kg: Double, displayValue: Double, unitName: String) -> LoggedWeight {
        let entry = WeightEntry(date: .now, weightKg: kg)
        let weightStore = WeightStore(observesExternalChanges: false)
        weightStore.addEntry(entry)

        HealthKitManager().writeWeight(for: entry)
        rescheduleNotificationsIfNeeded(foodStore: FoodStore(observesExternalChanges: false), weightStore: weightStore)
        WeightStore.postExternalChangeNotification()

        return LoggedWeight(entry: entry, displayValue: displayValue, unitName: unitName)
    }

    private static func parseWeight(_ description: String) throws -> (kg: Double, displayValue: Double, unitName: String) {
        let normalized = description
            .lowercased()
            .replacingOccurrences(of: ",", with: ".")

        guard let numberRange = normalized.range(
            of: #"[-+]?[0-9]*\.?[0-9]+"#,
            options: .regularExpression
        ), let value = Double(normalized[numberRange]) else {
            throw WeightInputError.missingNumber
        }

        let usesMetric = WeightUnit.current == .kg
        let unitIsPounds = normalized.contains("lb")
            || normalized.contains("lbs")
            || normalized.contains("pound")
            || normalized.contains("pounds")
        let unitIsKilograms = normalized.contains("kg")
            || normalized.contains("kgs")
            || normalized.contains("kilogram")
            || normalized.contains("kilograms")
            || normalized.contains("kilo")
            || normalized.contains("kilos")

        let usePounds = unitIsPounds || (!unitIsKilograms && !usesMetric)
        let kg = usePounds ? value / 2.20462 : value

        guard kg > 0, kg < 500 else {
            throw WeightInputError.invalidRange
        }

        return (
            kg: kg,
            displayValue: value,
            unitName: usePounds ? "pounds" : "kilograms"
        )
    }

    private static func foodEntry(from analysis: GeminiService.FoodAnalysis) -> FoodEntry {
        FoodEntry(
            name: analysis.name,
            calories: analysis.calories,
            protein: analysis.protein,
            carbs: analysis.carbs,
            fat: analysis.fat,
            timestamp: .now,
            emoji: analysis.emoji,
            source: .textInput,
            mealType: .currentMeal,
            sugar: analysis.sugar,
            addedSugar: analysis.addedSugar,
            fiber: analysis.fiber,
            saturatedFat: analysis.saturatedFat,
            monounsaturatedFat: analysis.monounsaturatedFat,
            polyunsaturatedFat: analysis.polyunsaturatedFat,
            cholesterol: analysis.cholesterol,
            sodium: analysis.sodium,
            potassium: analysis.potassium,
            transFat: analysis.transFat,
            calcium: analysis.calcium,
            iron: analysis.iron,
            magnesium: analysis.magnesium,
            zinc: analysis.zinc,
            vitaminA: analysis.vitaminA,
            vitaminC: analysis.vitaminC,
            vitaminD: analysis.vitaminD,
            vitaminB12: analysis.vitaminB12,
            vitaminE: analysis.vitaminE,
            vitaminK: analysis.vitaminK,
            folate: analysis.folate,
            omega3: analysis.omega3,
            servingSizeGrams: analysis.servingSizeGrams,
            servingUnitOptions: analysis.servingUnitOptions,
            selectedServingUnit: analysis.selectedServingUnit,
            selectedServingQuantity: analysis.selectedServingQuantity
        )
    }

    private static func publishAfterFoodChange(foodStore: FoodStore) {
        guard let profile = UserProfile.load() else { return }
        WidgetSnapshotWriter.publish(foods: foodStore.entries, profile: profile)
        rescheduleNotificationsIfNeeded(foodStore: foodStore, weightStore: WeightStore(observesExternalChanges: false))
    }

    private static func rescheduleNotificationsIfNeeded(foodStore: FoodStore, weightStore: WeightStore) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled"),
              let profile = UserProfile.load()
        else { return }

        NotificationManager().rescheduleDataDependentNotifications(
            foodStore: foodStore,
            weightStore: weightStore,
            bodyFatStore: BodyFatStore(),
            profile: profile
        )
    }
}
