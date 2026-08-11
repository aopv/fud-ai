import Testing
import UIKit
@testable import calorietracker

// Serialized: several tests save/mutate/restore shared UserDefaults-backed settings.
@Suite(.serialized)
struct AIRequestConfigurationTests {
    @Test func geminiUsesCurrentModelsAndFallsBackFromRetiredChoices() {
        #expect(AIProvider.gemini.defaultModel == "gemini-3.5-flash-lite")
        #expect(AIProvider.gemini.models.contains("gemini-3.6-flash"))
        #expect(AIProvider.gemini.models.contains("gemini-3.5-flash"))
        #expect(!AIProvider.gemini.models.contains("gemini-2.5-flash"))
        #expect(!AIProvider.gemini.models.contains("gemini-2.5-pro"))
        #expect(AIProvider.gemini.supportedModelOrDefault("gemini-2.5-pro") == "gemini-3.5-flash-lite")
        #expect(AIProvider.upgradedLegacyGeminiModel("gemini-3.1-flash-lite") == "gemini-3.5-flash-lite")
        #expect(AIProvider.upgradedLegacyGeminiModel("gemini-3.1-pro-preview") == "gemini-3.6-flash")
        #expect(AIProvider.upgradedLegacyGeminiModel("gemini-3.5-flash") == "gemini-3.6-flash")
        #expect(AIProvider.upgradedLegacyGeminiModel("gemini-3.6-flash") == nil)
    }

    @Test func localRequestTimeoutDefaultsAndClamps() {
        let original = AIProviderSettings.requestTimeoutSeconds
        defer { AIProviderSettings.requestTimeoutSeconds = original }

        AIProviderSettings.requestTimeoutSeconds = 10
        #expect(AIProviderSettings.requestTimeoutSeconds == 30)
        AIProviderSettings.requestTimeoutSeconds = 900
        #expect(AIProviderSettings.requestTimeoutSeconds == 600)
        #expect(AIProviderSettings.requestTimeout(for: .ollama) == 600)
        #expect(AIProviderSettings.requestTimeout(for: .customOpenAI) == 600)
        #expect(AIProviderSettings.requestTimeout(for: .gemini) == nil)
    }

    @Test func fallbackBaseURLIsStoredSeparatelyFromPrimary() {
        let provider = AIProvider.ollama
        let defaults = UserDefaults.standard
        let originalShared = AIProviderSettings.customBaseURL(for: provider)
        let originalFallback = AIProviderSettings.fallbackCustomBaseURL(for: provider)
        let originalEnabled = AIProviderSettings.fallbackEnabled
        let originalFallbackProvider = defaults.string(forKey: "selectedFallbackAIProvider")
        let originalFallbackModel = defaults.string(forKey: "selectedFallbackAIModel")
        defer {
            AIProviderSettings.setCustomBaseURL(originalShared, for: provider)
            AIProviderSettings.setFallbackCustomBaseURL(originalFallback, for: provider)
            AIProviderSettings.fallbackEnabled = originalEnabled
            if let originalFallbackProvider {
                defaults.set(originalFallbackProvider, forKey: "selectedFallbackAIProvider")
            } else {
                defaults.removeObject(forKey: "selectedFallbackAIProvider")
            }
            if let originalFallbackModel {
                defaults.set(originalFallbackModel, forKey: "selectedFallbackAIModel")
            } else {
                defaults.removeObject(forKey: "selectedFallbackAIModel")
            }
        }

        AIProviderSettings.setCustomBaseURL("http://primary.local:8080/v1", for: provider)
        AIProviderSettings.setFallbackCustomBaseURL("http://fallback.local:9090/v1", for: provider)
        #expect(AIProviderSettings.customBaseURL(for: provider) == "http://primary.local:8080/v1")
        #expect(AIProviderSettings.fallbackCustomBaseURL(for: provider) == "http://fallback.local:9090/v1")

        // The resolved fallback config must use the fallback-scoped URL, not the primary's.
        AIProviderSettings.fallbackEnabled = true
        AIProviderSettings.selectedFallbackProvider = provider
        AIProviderSettings.selectedFallbackModel = "llava"
        let config = AIProviderSettings.currentFallbackConfig(excludingPrimary: .gemini)
        #expect(config?.baseURL == "http://fallback.local:9090/v1")
    }

    @Test func fallbackBaseURLMigrationSeedsSharedValueExactlyOnce() {
        let provider = AIProvider.customOpenAI
        let defaults = UserDefaults.standard
        let markerKey = "fallbackBaseURLMigrationVersion"
        let originalShared = AIProviderSettings.customBaseURL(for: provider)
        let originalFallback = AIProviderSettings.fallbackCustomBaseURL(for: provider)
        let originalMarker = defaults.object(forKey: markerKey)
        defer {
            AIProviderSettings.setCustomBaseURL(originalShared, for: provider)
            AIProviderSettings.setFallbackCustomBaseURL(originalFallback, for: provider)
            if let originalMarker {
                defaults.set(originalMarker, forKey: markerKey)
            } else {
                defaults.removeObject(forKey: markerKey)
            }
        }

        defaults.removeObject(forKey: markerKey)
        AIProviderSettings.setFallbackCustomBaseURL(nil, for: provider)
        AIProviderSettings.setCustomBaseURL("http://shared.local:1234/v1", for: provider)

        AIProviderSettings.migrateFallbackBaseURLsIfNeeded()
        #expect(AIProviderSettings.fallbackCustomBaseURL(for: provider) == "http://shared.local:1234/v1")

        // A deliberate clear after migration must survive the next launch: the marker
        // prevents the shared value from being re-seeded.
        AIProviderSettings.setFallbackCustomBaseURL(nil, for: provider)
        AIProviderSettings.migrateFallbackBaseURLsIfNeeded()
        #expect(AIProviderSettings.fallbackCustomBaseURL(for: provider) == nil)
    }

    @Test func foodPhotosAreDownscaledWithoutUpscaling() throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let large = UIGraphicsImageRenderer(size: CGSize(width: 3_200, height: 1_200), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_200, height: 1_200))
        }
        let largeData = try GeminiService.encodedJPEGData(for: large)
        let resized = try #require(UIImage(data: largeData))
        #expect(resized.size.width == 1_600)
        #expect(resized.size.height == 600)

        let small = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 400))
        }
        let smallData = try GeminiService.encodedJPEGData(for: small)
        let preserved = try #require(UIImage(data: smallData))
        #expect(preserved.size.width == 800)
        #expect(preserved.size.height == 400)
    }
}
