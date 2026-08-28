import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case gemini = "Google Gemini"
    case openai = "OpenAI"
    case anthropic = "Anthropic Claude"
    case xai = "xAI Grok"
    case openrouter = "OpenRouter"
    case togetherai = "Together AI"
    case groq = "Groq"
    case huggingface = "Hugging Face"
    case fireworks = "Fireworks AI"
    case deepinfra = "DeepInfra"
    case mistral = "Mistral"
    case ollama = "Ollama (Local)"
    case customOpenAI = "Custom (OpenAI-compatible)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gemini: "sparkle"
        case .openai: "brain.head.profile"
        case .anthropic: "text.bubble"
        case .xai: "bolt.fill"
        case .openrouter: "arrow.triangle.branch"
        case .togetherai: "square.stack.3d.up"
        case .groq: "hare.fill"
        case .huggingface: "face.smiling.inverse"
        case .fireworks: "flame.fill"
        case .deepinfra: "server.rack"
        case .mistral: "wind"
        case .ollama: "desktopcomputer"
        case .customOpenAI: "wrench.and.screwdriver.fill"
        }
    }

    var baseURL: String {
        switch self {
        case .gemini: "https://generativelanguage.googleapis.com/v1beta"
        case .openai: "https://api.openai.com/v1"
        case .anthropic: "https://api.anthropic.com/v1"
        case .xai: "https://api.x.ai/v1"
        case .openrouter: "https://openrouter.ai/api/v1"
        case .togetherai: "https://api.together.xyz/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .huggingface: "https://router.huggingface.co/v1"
        case .fireworks: "https://api.fireworks.ai/inference/v1"
        case .deepinfra: "https://api.deepinfra.com/v1/openai"
        case .mistral: "https://api.mistral.ai/v1"
        case .ollama: "http://localhost:11434/v1"
        case .customOpenAI: ""  // user must supply
        }
    }

    var defaultModel: String {
        models.first ?? ""
    }

    static func normalizedModelID(_ model: String) -> String {
        switch model.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "gemini-3.1-flash-lite-preview":
            return "gemini-3.1-flash-lite"
        default:
            return model
        }
    }

    /// One-time upgrade path for older Gemini presets. This intentionally stays
    /// separate from normalization so users may still select supported older
    /// models after the migration has run.
    static func upgradedLegacyGeminiModel(_ model: String?) -> String? {
        guard let model else { return nil }
        switch normalizedModelID(model) {
        case "gemini-2.5-flash", "gemini-2.5-pro", "gemini-3.1-flash-lite":
            return "gemini-3.5-flash-lite"
        case "gemini-3.1-pro-preview", "gemini-3.5-flash":
            return "gemini-3.6-flash"
        default:
            return nil
        }
    }

    func supportedModelOrDefault(_ model: String?) -> String {
        guard let model else { return defaultModel }
        let normalized = Self.normalizedModelID(model)
        if supportsCustomModelName {
            return normalized
        }
        return models.contains(normalized) ? normalized : defaultModel
    }

    /// Only models that are currently in service AND accept image input + return structured text.
    /// Text-only and deprecated models are excluded since this app needs vision for food photos.
    /// Lineups verified against provider docs on 2026-07-21.
    var models: [String] {
        switch self {
        case .gemini: [
            "gemini-3.5-flash-lite",         // vision, cheapest current stable model (default)
            "gemini-3.6-flash",              // vision, latest stable Flash model
            "gemini-3.5-flash",              // vision, stable Flash model
            "gemini-3.1-flash-lite",         // vision, supported Flash-Lite model
            "gemini-3.1-pro-preview",        // vision, current flagship (preview)
        ]
        case .openai: [
            "gpt-5.4-mini",              // vision, best price/perf
            "gpt-5.5",                   // vision, current flagship
            "gpt-5.4-nano",              // vision, cheapest
            "gpt-4.1",                   // vision, legacy
            "gpt-4.1-mini",              // vision, legacy cheap
            "gpt-4o-mini",               // vision, legacy cheap
        ]
        case .anthropic: [
            "claude-sonnet-5",             // vision, current Sonnet (default)
            "claude-opus-4-8",             // vision, current flagship
            "claude-haiku-4-5",            // vision, current Haiku, fastest
            "claude-sonnet-4-6",           // vision, prior Sonnet
            "claude-opus-4-7",             // vision, prior Opus
        ]
        case .xai: [
            "grok-4.3",                  // vision, current (grok-4 and grok-2-vision retired)
        ]
        case .openrouter: [
            "openrouter/free",           // free tier, vision, no credits required
            "google/gemini-3.1-flash-lite",
            "openai/gpt-5-mini",
            "anthropic/claude-sonnet-5",
            "qwen/qwen3-vl-8b-instruct",
        ]
        case .togetherai: [
            "Qwen/Qwen3.5-9B",                                    // vision
            "google/gemma-4-31B-it",                              // vision
            "MiniMaxAI/MiniMax-M3",                               // vision
        ]
        case .groq: [
            "qwen/qwen3.6-27b",                                   // vision (llama-4-scout shutdown 2026-07-17)
        ]
        case .huggingface: [
            "google/gemma-4-31B-it",                              // vision, widest provider coverage
            "google/gemma-3-27b-it",                              // vision, open-weight Gemma 3
            "Qwen/Qwen3.5-9B",                                    // vision, open-weight Qwen
            "Qwen/Qwen2.5-VL-72B-Instruct",                       // vision, open-weight Qwen VL
        ]
        case .fireworks: [
            "accounts/fireworks/models/qwen3p7-plus",             // vision, serverless
            "accounts/fireworks/models/minimax-m3",               // vision, serverless
            "accounts/fireworks/models/kimi-k2p6",                // vision, serverless
        ]
        case .deepinfra: [
            "google/gemma-3-27b-it",                              // vision, cheapest
            "google/gemma-4-31B-it",                              // vision
            "google/gemma-4-26B-A4B-it",                          // vision
        ]
        case .mistral: [
            "mistral-small-2603",                                 // vision, best value (Pixtral line retired)
            "mistral-medium-2604",                                // vision, frontier
            "ministral-14b-2512",                                 // vision, small
        ]
        case .ollama: [
            "qwen3-vl",
            "gemma4",
            "llama3.2-vision",
            "llava",
            "moondream",
        ]
        case .customOpenAI: []  // user types model name in Settings
        }
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }

    /// True for providers where the user supplies the base URL and model name themselves.
    var requiresCustomEndpoint: Bool {
        self == .customOpenAI
    }

    /// True for providers where the user types a free-form model name (no preset list).
    var requiresCustomModelName: Bool {
        self == .customOpenAI
    }

    /// Local and user-hosted endpoints often need substantially longer than the
    /// platform's default 60-second request timeout, especially for vision models.
    var usesConfigurableRequestTimeout: Bool {
        self == .ollama || self == .customOpenAI
    }

    /// True for providers where free-form input is allowed in addition to the preset list
    /// (e.g., OpenRouter / Hugging Face — user can pick a preset OR type any model ID).
    var supportsCustomModelName: Bool {
        self == .openrouter || self == .huggingface || self == .customOpenAI
    }

    /// API format grouping
    enum APIFormat {
        case gemini
        case openaiCompatible
        case anthropic
    }

    var apiFormat: APIFormat {
        switch self {
        case .gemini: .gemini
        case .anthropic: .anthropic
        case .openai, .xai, .openrouter, .togetherai, .groq, .huggingface, .fireworks, .deepinfra, .mistral, .ollama, .customOpenAI: .openaiCompatible
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .gemini: "AIza..."
        case .openai: "sk-..."
        case .anthropic: "sk-ant-..."
        case .xai: "xai-..."
        case .openrouter: "sk-or-..."
        case .togetherai: "..."
        case .groq: "gsk_..."
        case .huggingface: "hf_..."
        case .fireworks: "fw_..."
        case .deepinfra: "..."
        case .mistral: "..."
        case .ollama: "No key needed"
        case .customOpenAI: "API key (or anything if endpoint doesn't need one)"
        }
    }
}

extension AIProvider {
    func openAICompatibleTokenLimitKey(for model: String) -> String {
        if self == .openai || (self == .customOpenAI && Self.usesOpenAICompletionTokenLimit(model: model)) {
            return "max_completion_tokens"
        }
        return "max_tokens"
    }

    private static func usesOpenAICompletionTokenLimit(model: String) -> Bool {
        let normalized = model
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(separator: "/")
            .last
            .map(String.init) ?? model.lowercased()

        return normalized.hasPrefix("gpt-5")
            || normalized.hasPrefix("o1")
            || normalized.hasPrefix("o3")
            || normalized.hasPrefix("o4")
    }
}

// MARK: - Settings Persistence

struct AIProviderSettings {
    private static let providerKey = "selectedAIProvider"
    private static let modelKey = "selectedAIModel"
    private static let apiKeyKeychainPrefix = "apikey_"
    private static let baseURLKey = "customBaseURL_"
    private static let userContextKey = "aiUserContext"
    private static let fallbackEnabledKey = "aiFallbackEnabled"
    private static let fallbackProviderKey = "selectedFallbackAIProvider"
    private static let fallbackModelKey = "selectedFallbackAIModel"
    private static let geminiModelMigrationVersionKey = "geminiModelMigrationVersion"
    private static let maxResponseTokensKey = "aiMaxResponseTokens"
    private static let requestTimeoutSecondsKey = "aiRequestTimeoutSeconds"

    /// The AI output-token cap sent with every request (`max_tokens` /
    /// `max_completion_tokens` / Gemini `maxOutputTokens`). Default 1024; raise it for
    /// local models whose replies get truncated.
    static var maxResponseTokens: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: maxResponseTokensKey)
            return v > 0 ? v : 1024 // 0 == unset -> default
        }
        set { UserDefaults.standard.set(max(1, newValue), forKey: maxResponseTokensKey) }
    }

    /// Timeout used by local/custom AI endpoints. Cloud providers retain the
    /// standard URLSession timeout. Default 180 seconds; configurable in Settings.
    static var requestTimeoutSeconds: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: requestTimeoutSecondsKey)
            return value > 0 ? min(max(value, 30), 600) : 180
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 30), 600), forKey: requestTimeoutSecondsKey)
        }
    }

    static func requestTimeout(for provider: AIProvider) -> TimeInterval? {
        provider.usesConfigurableRequestTimeout ? TimeInterval(requestTimeoutSeconds) : nil
    }

    static var selectedProvider: AIProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: providerKey),
                  let provider = AIProvider(rawValue: raw) else { return .gemini }
            return provider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }

    /// Upgrades legacy Gemini choices exactly once, including the fallback.
    /// A marker prevents a later manual choice of a still-supported older model
    /// from being overwritten on every launch.
    static func migrateLegacyGeminiModelsIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: geminiModelMigrationVersionKey) < 1 else { return }

        if selectedProvider == .gemini,
           let upgraded = AIProvider.upgradedLegacyGeminiModel(defaults.string(forKey: modelKey)) {
            defaults.set(upgraded, forKey: modelKey)
        }

        if selectedFallbackProvider == .gemini,
           let upgraded = AIProvider.upgradedLegacyGeminiModel(defaults.string(forKey: fallbackModelKey)) {
            defaults.set(upgraded, forKey: fallbackModelKey)
        }

        defaults.set(1, forKey: geminiModelMigrationVersionKey)
    }

    static var selectedModel: String {
        get {
            let saved = UserDefaults.standard.string(forKey: modelKey)
            // Validate against the provider's supported list and fall back to default
            // if the saved one was removed (e.g., a deprecated model we no longer expose).
            let resolved = selectedProvider.supportedModelOrDefault(saved)
            if let saved, AIProvider.normalizedModelID(saved) != resolved {
                UserDefaults.standard.set(resolved, forKey: modelKey)
            }
            return resolved
        }
        set {
            UserDefaults.standard.set(AIProvider.normalizedModelID(newValue), forKey: modelKey)
        }
    }

    static func apiKey(for provider: AIProvider) -> String? {
        KeychainHelper.load(key: apiKeyKeychainPrefix + provider.rawValue)
    }

    static func setAPIKey(_ key: String?, for provider: AIProvider) {
        let keychainKey = apiKeyKeychainPrefix + provider.rawValue
        if let key, !key.isEmpty {
            KeychainHelper.save(key: keychainKey, value: key)
        } else {
            KeychainHelper.delete(key: keychainKey)
        }
    }

    static func customBaseURL(for provider: AIProvider) -> String? {
        UserDefaults.standard.string(forKey: baseURLKey + provider.rawValue)
    }

    static func setCustomBaseURL(_ url: String?, for provider: AIProvider) {
        if let url, !url.isEmpty {
            UserDefaults.standard.set(url, forKey: baseURLKey + provider.rawValue)
        } else {
            UserDefaults.standard.removeObject(forKey: baseURLKey + provider.rawValue)
        }
    }

    static var currentAPIKey: String? {
        apiKey(for: selectedProvider)
    }

    static var currentBaseURL: String {
        customBaseURL(for: selectedProvider) ?? selectedProvider.baseURL
    }

    /// Optional user-supplied context (region, diet, athletic goals, etc.)
    /// prepended as a system instruction to every AI request when non-empty.
    /// Empty string ⇒ nothing injected, request shape unchanged.
    static var userContext: String {
        get { UserDefaults.standard.string(forKey: userContextKey) ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: userContextKey)
            } else {
                UserDefaults.standard.set(newValue, forKey: userContextKey)
            }
        }
    }

    static var currentUserContext: String? {
        let ctx = userContext.trimmingCharacters(in: .whitespacesAndNewlines)
        return ctx.isEmpty ? nil : ctx
    }

    // MARK: - Fallback Provider

    /// Master toggle for fallback. When true and primary call fails, the app retries
    /// once on the configured fallback provider before surfacing the error.
    static var fallbackEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: fallbackEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: fallbackEnabledKey) }
    }

    static var selectedFallbackProvider: AIProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: fallbackProviderKey),
                  let provider = AIProvider(rawValue: raw) else {
                return providersWithSavedKeys(excluding: selectedProvider).first ?? .gemini
            }
            return provider
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: fallbackProviderKey) }
    }

    static var selectedFallbackModel: String {
        get {
            let provider = selectedFallbackProvider
            let saved = UserDefaults.standard.string(forKey: fallbackModelKey)
            let resolved = provider.supportedModelOrDefault(saved)
            if let saved, AIProvider.normalizedModelID(saved) != resolved {
                UserDefaults.standard.set(resolved, forKey: fallbackModelKey)
            }
            return resolved
        }
        set { UserDefaults.standard.set(AIProvider.normalizedModelID(newValue), forKey: fallbackModelKey) }
    }

    /// Providers that have a saved API key (or don't require one, e.g. Ollama),
    /// optionally excluding the primary so the fallback picker doesn't list it.
    static func providersWithSavedKeys(excluding: AIProvider? = nil) -> [AIProvider] {
        AIProvider.allCases.filter { provider in
            if let excluding, provider == excluding { return false }
            if !provider.requiresAPIKey { return true }
            return apiKey(for: provider) != nil
        }
    }

    struct FallbackConfig {
        let provider: AIProvider
        let model: String
        let baseURL: String
        let apiKey: String?
    }

    /// Returns the resolved fallback config when (a) fallback is enabled, (b) the fallback
    /// provider has a usable key (or doesn't require one), and (c) the fallback config
    /// isn't byte-for-byte identical to the primary (same provider + model = pointless retry).
    /// Same provider with a *different* model IS allowed — common pattern is e.g. Gemini Pro
    /// primary with Gemini Flash fallback for capacity-pool diversity within one provider.
    static func currentFallbackConfig(excludingPrimary primary: AIProvider) -> FallbackConfig? {
        guard fallbackEnabled else { return nil }
        let provider = selectedFallbackProvider
        let model = selectedFallbackModel
        if provider == primary, model == selectedModel { return nil }
        if provider.requiresAPIKey, apiKey(for: provider) == nil { return nil }
        return FallbackConfig(
            provider: provider,
            model: model,
            baseURL: customBaseURL(for: provider) ?? provider.baseURL,
            apiKey: apiKey(for: provider)
        )
    }

    static func deleteAllData() {
        for provider in AIProvider.allCases {
            setAPIKey(nil, for: provider)
            setCustomBaseURL(nil, for: provider)
        }
        UserDefaults.standard.removeObject(forKey: providerKey)
        UserDefaults.standard.removeObject(forKey: modelKey)
        UserDefaults.standard.removeObject(forKey: userContextKey)
        UserDefaults.standard.removeObject(forKey: fallbackEnabledKey)
        UserDefaults.standard.removeObject(forKey: fallbackProviderKey)
        UserDefaults.standard.removeObject(forKey: fallbackModelKey)
        UserDefaults.standard.removeObject(forKey: requestTimeoutSecondsKey)
    }
}
