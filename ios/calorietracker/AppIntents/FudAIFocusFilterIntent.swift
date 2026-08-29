import AppIntents
import Foundation

enum FudAIFocusFilterCriteria {
    static let mealReminder = "meal-reminder"
}

struct MealReminderFocusFilterIntent: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Meal Reminder Filter"
    static let description = IntentDescription(
        "Hide Fud AI meal reminders while a Focus is active.",
        categoryName: "Notifications"
    )

    @Parameter(
        title: "Mute Meal Reminders",
        description: "Hide breakfast, lunch, and dinner reminders while this Focus is active.",
        default: true
    )
    var muteMealReminders: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Mute meal reminders: \(\.$muteMealReminders)")
    }

    var displayRepresentation: DisplayRepresentation {
        if muteMealReminders {
            return DisplayRepresentation(title: "Mute Meal Reminders")
        }
        return DisplayRepresentation(title: "Allow Meal Reminders")
    }

    var appContext: FocusFilterAppContext {
        guard muteMealReminders else {
            return FocusFilterAppContext(notificationFilterPredicate: nil)
        }

        let predicate = NSPredicate(
            format: "SELF == nil OR SELF != %@",
            FudAIFocusFilterCriteria.mealReminder
        )
        return FocusFilterAppContext(notificationFilterPredicate: predicate)
    }

    func perform() async throws -> some IntentResult {
        .result()
    }

    static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) async -> [MealReminderFocusFilterIntent] {
        [MealReminderFocusFilterIntent()]
    }
}
