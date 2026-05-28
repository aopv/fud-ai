import AppIntents

/// Registers suggested Siri shortcuts for Fud AI.
/// Siri learns these phrases and can trigger the intents without "Add to Siri" step.
struct FudAIShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFoodIntent(),
            phrases: [
                "Log food in \(.applicationName)",
                "Add food to \(.applicationName)",
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
    }
}
