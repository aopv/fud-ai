import AppIntents
import Foundation

/// Shared UserDefaults key for the Focus-filter "mute meal reminders" toggle.
/// Written by `FudAIFocusFilter`, read by `NotificationManager`.
enum FocusFilterKeys {
    static let muteReminders = "focusMuteReminders"
}

/// Lets users configure Fud AI behaviour when a specific Focus mode is active.
/// Appears in Settings → Focus → [Focus Name] → App Behaviour → Fud AI.
@available(iOS 16, *)
struct FudAIFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Fud AI"
    static var description: LocalizedStringResource? = "Control Fud AI notifications while this Focus is active."

    @Parameter(
        title: "Mute Meal Reminders",
        description: "Suppress meal and goal reminder notifications while this Focus is active.",
        default: false
    )
    var muteReminders: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Fud AI",
            subtitle: muteReminders ? "Meal reminders muted" : "All notifications on"
        )
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(muteReminders, forKey: FocusFilterKeys.muteReminders)
        return .result()
    }
}
