import Testing
import UIKit
@testable import calorietracker

struct AIRequestConfigurationTests {
    @Test func geminiUsesCurrentModelsAndFallsBackFromRetiredChoices() {
        #expect(AIProvider.gemini.defaultModel == "gemini-3.5-flash-lite")
        #expect(AIProvider.gemini.models.contains("gemini-3.6-flash"))
        #expect(AIProvider.gemini.models.contains("gemini-3.5-flash"))
        #expect(!AIProvider.gemini.models.contains("gemini-2.5-flash"))
        #expect(!AIProvider.gemini.models.contains("gemini-2.5-pro"))
        #expect(AIProvider.gemini.supportedModelOrDefault("gemini-2.5-pro") == "gemini-3.5-flash-lite")
        #expect(AIProvider.upgradedLegacyGeminiModel("gemini-3.1-flash-lite") == "gemini-3.5-flash-lite")
        #expect(AIProvider.upgradedLegacyGeminiModel("gemini-3.1-pro-preview") == nil)
        #expect(AIProvider.upgradedLegacyGeminiModel("gemini-3.5-flash") == nil)
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

    @Test func separateTextProviderOnlyRoutesRequestsWithoutImages() {
        let originalProvider = AIProviderSettings.selectedProvider
        let originalModel = AIProviderSettings.selectedModel
        let originalEnabled = AIProviderSettings.separateTextProviderEnabled
        let originalTextProvider = AIProviderSettings.selectedTextProvider
        let originalTextModel = AIProviderSettings.selectedTextModel
        defer {
            AIProviderSettings.selectedProvider = originalProvider
            AIProviderSettings.selectedModel = originalModel
            AIProviderSettings.separateTextProviderEnabled = originalEnabled
            AIProviderSettings.selectedTextProvider = originalTextProvider
            AIProviderSettings.selectedTextModel = originalTextModel
        }

        AIProviderSettings.selectedProvider = .openai
        AIProviderSettings.selectedModel = "gpt-5.4-mini"
        AIProviderSettings.selectedTextProvider = .deepseek
        AIProviderSettings.selectedTextModel = "deepseek-v4-pro"

        AIProviderSettings.separateTextProviderEnabled = false
        #expect(AIProviderSettings.currentConfig(requiresVision: false).provider == .openai)

        AIProviderSettings.separateTextProviderEnabled = true
        let text = AIProviderSettings.currentConfig(requiresVision: false)
        let vision = AIProviderSettings.currentConfig(requiresVision: true)
        #expect(text.provider == .deepseek)
        #expect(text.model == "deepseek-v4-pro")
        #expect(vision.provider == .openai)
        #expect(vision.model == "gpt-5.4-mini")
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
