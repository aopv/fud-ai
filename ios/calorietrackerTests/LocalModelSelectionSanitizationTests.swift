import Foundation
import Testing
@testable import calorietracker

struct LocalModelSelectionSanitizationTests {
    @Test func deletingGemmaSanitizesEveryPrimaryAndFallbackSelection() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(AIProvider.gemma4Local.rawValue, forKey: "selectedAIProvider")
        defaults.set(AIProvider.gemma4Local.rawValue, forKey: "selectedTextAIProvider")
        defaults.set(AIProvider.gemma4Local.rawValue, forKey: "selectedFallbackAIProvider")
        defaults.set(AIProvider.gemma4Local.rawValue, forKey: "selectedTextFallbackAIProvider")
        defaults.set(true, forKey: "separateTextProviderEnabled")
        defaults.set(true, forKey: "aiFallbackEnabled")
        defaults.set(true, forKey: "textAIFallbackEnabled")

        AIProviderSettings.replaceDeletedLocalGemmaSelections(defaults: defaults)

        #expect(defaults.string(forKey: "selectedAIProvider") == AIProvider.gemini.rawValue)
        #expect(defaults.string(forKey: "selectedTextAIProvider") == AIProvider.gemini.rawValue)
        #expect(defaults.string(forKey: "selectedFallbackAIProvider") == AIProvider.gemini.rawValue)
        #expect(defaults.string(forKey: "selectedTextFallbackAIProvider") == AIProvider.gemini.rawValue)
        #expect(!defaults.bool(forKey: "separateTextProviderEnabled"))
        #expect(!defaults.bool(forKey: "aiFallbackEnabled"))
        #expect(!defaults.bool(forKey: "textAIFallbackEnabled"))
    }

    @Test func deletingWhisperSanitizesPrimaryAndFallbackSelection() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(SpeechProvider.whisperBase.rawValue, forKey: "selectedSpeechProvider")
        defaults.set(SpeechProvider.whisperBase.rawValue, forKey: "selectedSpeechFallbackProvider")
        defaults.set(true, forKey: "speechFallbackEnabled")

        SpeechSettings.replaceDeletedWhisperSelections(defaults: defaults)

        #expect(defaults.string(forKey: "selectedSpeechProvider") == SpeechProvider.nativeIOS.rawValue)
        #expect(defaults.string(forKey: "selectedSpeechFallbackProvider") == SpeechProvider.groq.rawValue)
        #expect(!defaults.bool(forKey: "speechFallbackEnabled"))
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "LocalModelSelectionSanitizationTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (defaults, suite)
    }
}
