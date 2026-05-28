import AppIntents
import Foundation

/// "Hey Siri, how many calories today in Fud AI?"
struct CalorieSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Calories"
    static var description = IntentDescription(
        "Get your calorie and protein total for today.",
        categoryName: "Nutrition"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let calories = FoodEntryStorage.todayCalories()
        let protein = FoodEntryStorage.todayProtein()
        let goal = UserProfile.load()?.effectiveCalories ?? 0

        let proteinStr = String(format: "%.0f", protein)
        let dialog: String
        if goal > 0 {
            let remaining = max(0, goal - calories)
            dialog = "Today you've had \(calories) of your \(goal) calorie goal — \(remaining) remaining. Protein: \(proteinStr)g."
        } else {
            dialog = "Today you've had \(calories) calories and \(proteinStr)g of protein."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

/// "Hey Siri, log 75 kilograms in Fud AI"
struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Weight"
    static var description = IntentDescription(
        "Log your current weight in Fud AI.",
        categoryName: "Body Metrics"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Weight in kg", description: "Your weight in kilograms, e.g. 75.5")
    var weightKg: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard weightKg > 0, weightKg < 500 else {
            return .result(dialog: "That doesn't look like a valid weight. Please try again.")
        }
        let entry = WeightEntry(date: .now, weightKg: weightKg)
        WeightEntryStorage.append(entry)

        let formatted = String(format: "%.1f", weightKg)
        return .result(dialog: "Logged \(formatted) kg.")
    }
}

/// Shared read/write for WeightStore's UserDefaults key.
enum WeightEntryStorage {
    private static let key = "weightEntries"

    /// Darwin notification posted after a Siri/Shortcut write so a running
    /// WeightStore reloads from disk instead of overwriting this entry.
    static let didChangeNotification = "ai.fud.weightEntriesDidChange"

    static func append(_ entry: WeightEntry) {
        var all: [WeightEntry] = []
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([WeightEntry].self, from: data) {
            all = decoded
        }
        all.append(entry)
        if let encoded = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
        // Wake any running WeightStore so it reloads before its next save.
        postDidChange()
    }

    /// Cross-process signal that `weightEntries` changed outside the main app.
    static func postDidChange() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(didChangeNotification as CFString),
            nil, nil, true
        )
    }
}
