import AppIntents
import Foundation

/// "Hey Siri, log 100g chicken breast in Fud AI"
struct LogFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Food"
    static var description = IntentDescription(
        "Log a food entry in Fud AI by describing what you ate.",
        categoryName: "Nutrition"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Food",
        description: "What you ate — e.g. '100g chicken breast' or 'large banana'",
        requestValueDialog: "What did you eat?"
    )
    var foodDescription: String

    /// Siri shows this summary in the confirmation UI and uses it as the
    /// follow-up question when the parameter is missing from the utterance.
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$foodDescription)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Try on-device model first (iOS 26+, Apple Intelligence)
        var analysis: GeminiService.FoodAnalysis?
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            analysis = await OnDeviceAIService.analyzeText(foodDescription)
        }
        #endif

        // 2. Fall back to Gemini / network AI
        if analysis == nil {
            analysis = try await GeminiService.analyzeTextInput(description: foodDescription)
        }

        guard let result = analysis else {
            return .result(dialog: "Sorry, I couldn't identify that food. Please try again.")
        }

        // 3. Persist — write directly to the same UserDefaults key FoodStore uses
        let entry = FoodEntry(
            name: result.name,
            calories: result.calories,
            protein: result.protein,
            carbs: result.carbs,
            fat: result.fat,
            timestamp: .now,
            emoji: result.emoji,
            source: .textInput,
            mealType: .currentMeal,
            sugar: result.sugar,
            fiber: result.fiber,
            saturatedFat: result.saturatedFat,
            sodium: result.sodium,
            servingSizeGrams: result.servingSizeGrams,
            servingUnitOptions: result.servingUnitOptions,
            selectedServingUnit: result.selectedServingUnit,
            selectedServingQuantity: result.selectedServingQuantity
        )
        FoodEntryStorage.append(entry)

        let proteinStr = String(format: "%.0f", result.protein)
        return .result(
            dialog: "Logged \(result.name) — \(result.calories) kcal, \(proteinStr)g protein."
        )
    }
}

/// Shared read/write access to the FoodStore's UserDefaults key.
/// Used by App Intents which can't access the SwiftUI environment.
enum FoodEntryStorage {
    private static let key = "foodEntries"

    /// Darwin notification posted after a Siri/Shortcut write so a running
    /// FoodStore (possibly in another process) reloads from disk instead of
    /// later overwriting this entry with its now-stale in-memory array.
    static let didChangeNotification = "ai.fud.foodEntriesDidChange"

    static func loadAll() -> [FoodEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([FoodEntry].self, from: data)
        else { return [] }
        return decoded
    }

    static func append(_ entry: FoodEntry) {
        var all = loadAll()
        all.append(entry)
        if let encoded = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
        // Make the entry searchable even if the app never launches.
        SpotlightIndexer.index(entry)
        // Wake any running FoodStore so it reloads before its next save.
        postDidChange()
    }

    /// Cross-process signal that `foodEntries` changed outside the main app.
    static func postDidChange() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(didChangeNotification as CFString),
            nil, nil, true
        )
    }

    static func todayCalories() -> Int {
        let calendar = Calendar.current
        return loadAll()
            .filter { calendar.isDateInToday($0.timestamp) }
            .reduce(0) { $0 + $1.calories }
    }

    static func todayProtein() -> Double {
        let calendar = Calendar.current
        return loadAll()
            .filter { calendar.isDateInToday($0.timestamp) }
            .reduce(0) { $0 + $1.protein }
    }
}
