import Foundation

enum LocalModelStrings {
    nonisolated static func text(_ key: String, defaultValue: String) -> String {
        Bundle.main.localizedString(
            forKey: key,
            value: defaultValue,
            table: "LocalModels"
        )
    }

    nonisolated static func format(
        _ key: String,
        defaultValue: String,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, defaultValue: defaultValue),
            locale: Locale.autoupdatingCurrent,
            arguments: arguments
        )
    }
}
