import AppIntents
import Foundation

struct LogFoodIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Food"
    static let description = IntentDescription(
        "Log a food entry in Fud AI by describing what you ate.",
        categoryName: "Nutrition"
    )
    static let openAppWhenRun = false

    @Parameter(
        title: "Food",
        description: "What you ate, for example 100g chicken breast or two eggs and toast.",
        requestValueDialog: "What did you eat?"
    )
    var foodDescription: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$foodDescription)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let entry = try await SiriLoggingService.analyzeAndLogFood(description: foodDescription)
            let protein = MacroValueFormatter.string(entry.protein)
            return .result(dialog: "Logged \(entry.name): \(entry.calories) calories and \(protein) grams protein.")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .result(dialog: "I could not log that food. \(message)")
        }
    }
}

struct CalorieSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Calories"
    static let description = IntentDescription(
        "Get your calorie and protein total for today.",
        categoryName: "Nutrition"
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = SiriLoggingService.todayNutritionSummary()
        let protein = MacroValueFormatter.string(summary.protein)

        if summary.calorieGoal > 0 {
            let remaining = max(0, summary.calorieGoal - summary.calories)
            return .result(
                dialog: "Today you have logged \(summary.calories) of \(summary.calorieGoal) calories. \(remaining) calories remaining. Protein: \(protein) grams."
            )
        } else {
            return .result(
                dialog: "Today you have logged \(summary.calories) calories and \(protein) grams protein."
            )
        }
    }
}

struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Weight"
    static let description = IntentDescription(
        "Log your current weight in Fud AI.",
        categoryName: "Body Metrics"
    )
    static let openAppWhenRun = false

    @Parameter(
        title: "Weight",
        description: "Your weight, for example 75 kilograms or 165 pounds.",
        requestValueDialog: "What is your weight?"
    )
    var weightDescription: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log weight \(\.$weightDescription)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let logged = try SiriLoggingService.logWeight(description: weightDescription)
            let formatted = String(format: "%.1f", logged.displayValue)
            return .result(dialog: "Logged \(formatted) \(logged.unitName).")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }
}

@MainActor
private func performQuickAction(slot: Int) -> some IntentResult {
    QuickActionCoordinator.request(QuickActionSettings.action(for: slot))
    return .result()
}

struct QuickActionOneIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Action 1"
    static let description = IntentDescription("Open your first configurable Fud AI quick action.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { performQuickAction(slot: 0) }
}

struct QuickActionTwoIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Action 2"
    static let description = IntentDescription("Open your second configurable Fud AI quick action.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { performQuickAction(slot: 1) }
}

struct QuickActionThreeIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Action 3"
    static let description = IntentDescription("Open your third configurable Fud AI quick action.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { performQuickAction(slot: 2) }
}

struct FudAIShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFoodIntent(),
            phrases: [
                "Log food in \(.applicationName)",
                "Add food in \(.applicationName)",
                "Track food in \(.applicationName)",
            ],
            shortTitle: "Log Food",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: CalorieSummaryIntent(),
            phrases: [
                "Calories today in \(.applicationName)",
                "How many calories in \(.applicationName)",
                "Today's nutrition in \(.applicationName)",
            ],
            shortTitle: "Today's Calories",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: LogWeightIntent(),
            phrases: [
                "Log my weight in \(.applicationName)",
                "Record weight in \(.applicationName)",
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass.fill"
        )

        AppShortcut(
            intent: QuickActionOneIntent(),
            phrases: ["Quick action one in \(.applicationName)"],
            shortTitle: "Quick Action 1",
            systemImageName: "1.circle.fill"
        )

        AppShortcut(
            intent: QuickActionTwoIntent(),
            phrases: ["Quick action two in \(.applicationName)"],
            shortTitle: "Quick Action 2",
            systemImageName: "2.circle.fill"
        )

        AppShortcut(
            intent: QuickActionThreeIntent(),
            phrases: ["Quick action three in \(.applicationName)"],
            shortTitle: "Quick Action 3",
            systemImageName: "3.circle.fill"
        )
    }
}
