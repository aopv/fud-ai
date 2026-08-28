import Foundation

enum SpeechProvider: String, CaseIterable, Codable, Identifiable {
    case nativeIOS = "Native iOS (On-Device)"
    case gemini = "Gemini Audio"
    case openai = "OpenAI Whisper"
    case groq = "Groq (Whisper)"
    case mistral = "Mistral Voxtral"
    case deepgram = "Deepgram"
    case assemblyai = "AssemblyAI"

    var id: String { rawValue }

    static var remoteProviders: [SpeechProvider] {
        allCases.filter(\.requiresAPIKey)
    }

    /// User-facing provider name. Raw values stay stable because they are also
    /// used for persisted settings and Keychain lookup keys.
    var displayName: String {
        switch self {
        case .openai: "OpenAI GPT-Transcribe"
        default: rawValue
        }
    }

    var icon: String {
        switch self {
        case .nativeIOS: "apple.logo"
        case .gemini: "sparkle"
        case .openai: "waveform"
        case .groq: "hare.fill"
        case .mistral: "wind"
        case .deepgram: "waveform.path.ecg"
        case .assemblyai: "text.bubble.fill"
        }
    }

    var requiresAPIKey: Bool { self != .nativeIOS }

    var apiKeyPlaceholder: String {
        switch self {
        case .nativeIOS: "Not needed"
        case .gemini: "AIza..."
        case .openai: "sk-..."
        case .groq: "gsk_..."
        case .mistral: "Your Mistral API key"
        case .deepgram: "Token your-deepgram-key"
        case .assemblyai: "Your AssemblyAI key"
        }
    }

    /// Default model name for the provider's STT API. Fixed per provider — user doesn't pick.
    var defaultModel: String {
        switch self {
        case .nativeIOS: ""
        case .gemini: "gemini-3.5-transcribe"
        case .openai: "gpt-transcribe"
        case .groq: "whisper-large-v3"
        case .mistral: "voxtral-mini-2602"
        case .deepgram: "nova-3"
        case .assemblyai: "universal-3-pro"
        }
    }

    var description: String {
        switch self {
        case .nativeIOS:
            LocalizedDisplayText.text(
                "Apple's on-device speech recognition. Free, works offline on modern iPhones, real-time partial results. Recommended default.",
                polish: "Rozpoznawanie mowy Apple na urządzeniu. Bezpłatne, działa offline na nowoczesnych iPhone'ach, pokazuje częściowe wyniki w czasie rzeczywistym. Zalecane domyślnie."
            )
        case .gemini:
            LocalizedDisplayText.text(
                "Gemini 3.5 Transcribe for accurate batch transcription with automatic language detection.",
                polish: "Gemini 3.5 Transcribe do dokładnej transkrypcji wsadowej z automatycznym wykrywaniem języka."
            )
        case .openai:
            LocalizedDisplayText.text(
                "OpenAI GPT-Transcribe, the current high-accuracy model for recorded audio.",
                polish: "OpenAI GPT-Transcribe, aktualny model o wysokiej dokładności do nagranego dźwięku."
            )
        case .groq:
            LocalizedDisplayText.text(
                "Groq-hosted Whisper Large v3. Very fast inference, has a free tier.",
                polish: "Whisper Large v3 hostowany przez Groq. Bardzo szybkie wnioskowanie, dostępny darmowy limit."
            )
        case .mistral:
            LocalizedDisplayText.text(
                "Voxtral Mini Transcribe 2 for accurate multilingual batch transcription.",
                polish: "Voxtral Mini Transcribe 2 do dokładnej wielojęzycznej transkrypcji wsadowej."
            )
        case .deepgram:
            LocalizedDisplayText.text(
                "Deepgram Nova. Real-time and batch modes, fast and accurate.",
                polish: "Deepgram Nova. Tryb czasu rzeczywistego i wsadowy, szybki i dokładny."
            )
        case .assemblyai:
            LocalizedDisplayText.text(
                "AssemblyAI Universal-3 Pro with Universal-2 fallback for broader language support.",
                polish: "AssemblyAI Universal-3 Pro z modelem Universal-2 jako rezerwowym dla szerszej obsługi języków."
            )
        }
    }
}

enum SpeechLanguage: String, CaseIterable, Codable, Identifiable {
    case automatic
    case device
    case english
    case german
    case spanish
    case french
    case italian
    case portuguese
    case dutch
    case hindi
    case japanese
    case chinese
    case korean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: LocalizedDisplayText.text("Provider Auto", polish: "Auto dostawcy")
        case .device: LocalizedDisplayText.text("Use iPhone Language", polish: "Użyj języka iPhone'a")
        case .english: LocalizedDisplayText.text("English", polish: "Angielski")
        case .german: LocalizedDisplayText.text("German", polish: "Niemiecki")
        case .spanish: LocalizedDisplayText.text("Spanish", polish: "Hiszpański")
        case .french: LocalizedDisplayText.text("French", polish: "Francuski")
        case .italian: LocalizedDisplayText.text("Italian", polish: "Włoski")
        case .portuguese: LocalizedDisplayText.text("Portuguese", polish: "Portugalski")
        case .dutch: LocalizedDisplayText.text("Dutch", polish: "Niderlandzki")
        case .hindi: LocalizedDisplayText.text("Hindi", polish: "Hindi")
        case .japanese: LocalizedDisplayText.text("Japanese", polish: "Japoński")
        case .chinese: LocalizedDisplayText.text("Chinese", polish: "Chiński")
        case .korean: LocalizedDisplayText.text("Korean", polish: "Koreański")
        }
    }

    var apiLanguageCode: String? {
        switch self {
        case .automatic:
            nil
        case .device:
            Locale.autoupdatingCurrent.language.languageCode?.identifier.lowercased()
        case .english:
            "en"
        case .german:
            "de"
        case .spanish:
            "es"
        case .french:
            "fr"
        case .italian:
            "it"
        case .portuguese:
            "pt"
        case .dutch:
            "nl"
        case .hindi:
            "hi"
        case .japanese:
            "ja"
        case .chinese:
            "zh"
        case .korean:
            "ko"
        }
    }

    var preferredNativeLocale: Locale {
        switch self {
        case .automatic, .device:
            Locale.autoupdatingCurrent
        case .english:
            Locale(identifier: "en-US")
        case .german:
            Locale(identifier: "de-DE")
        case .spanish:
            Locale(identifier: "es-ES")
        case .french:
            Locale(identifier: "fr-FR")
        case .italian:
            Locale(identifier: "it-IT")
        case .portuguese:
            Locale(identifier: "pt-BR")
        case .dutch:
            Locale(identifier: "nl-NL")
        case .hindi:
            Locale(identifier: "hi-IN")
        case .japanese:
            Locale(identifier: "ja-JP")
        case .chinese:
            Locale(identifier: "zh-Hans")
        case .korean:
            Locale(identifier: "ko-KR")
        }
    }
}

// MARK: - Settings Persistence

struct SpeechSettings {
    private static let providerKey = "selectedSpeechProvider"
    private static let fallbackEnabledKey = "speechFallbackEnabled"
    private static let fallbackProviderKey = "selectedSpeechFallbackProvider"
    private static let languageKey = "selectedSpeechLanguage"
    private static let languageKeyPrefix = "selectedSpeechLanguage_"
    private static let apiKeyKeychainPrefix = "speechApiKey_"

    static var selectedProvider: SpeechProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: providerKey),
                  let provider = SpeechProvider(rawValue: raw) else { return .nativeIOS }
            return provider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }

    static var fallbackEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: fallbackEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: fallbackEnabledKey) }
    }

    static var selectedFallbackProvider: SpeechProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: fallbackProviderKey),
                  let provider = SpeechProvider(rawValue: raw),
                  provider.requiresAPIKey else {
                return .groq
            }
            return provider
        }
        set {
            let resolved = newValue.requiresAPIKey ? newValue : .groq
            UserDefaults.standard.set(resolved.rawValue, forKey: fallbackProviderKey)
        }
    }

    static var selectedLanguage: SpeechLanguage {
        get {
            selectedLanguage(for: selectedProvider)
        }
        set {
            setLanguage(newValue, for: selectedProvider)
        }
    }

    static func selectedLanguage(for provider: SpeechProvider) -> SpeechLanguage {
        let key = languageKeyPrefix + provider.rawValue
        guard let raw = UserDefaults.standard.string(forKey: key),
              let language = SpeechLanguage(rawValue: raw) else {
            return defaultLanguage(for: provider)
        }
        return language
    }

    static func setLanguage(_ language: SpeechLanguage, for provider: SpeechProvider) {
        UserDefaults.standard.set(language.rawValue, forKey: languageKeyPrefix + provider.rawValue)
    }

    static func defaultLanguage(for provider: SpeechProvider) -> SpeechLanguage {
        switch provider {
        case .nativeIOS:
            .device
        case .gemini, .openai, .groq, .mistral:
            .automatic
        case .deepgram:
            .device
        case .assemblyai:
            .automatic
        }
    }

    static func apiKey(for provider: SpeechProvider) -> String? {
        KeychainHelper.load(key: apiKeyKeychainPrefix + provider.rawValue)
    }

    static func setAPIKey(_ key: String?, for provider: SpeechProvider) {
        let keychainKey = apiKeyKeychainPrefix + provider.rawValue
        if let key, !key.isEmpty {
            KeychainHelper.save(key: keychainKey, value: key)
        } else {
            KeychainHelper.delete(key: keychainKey)
        }
    }

    static var currentAPIKey: String? {
        apiKey(for: selectedProvider)
    }

    static func deleteAllData() {
        for provider in SpeechProvider.allCases {
            setAPIKey(nil, for: provider)
        }
        UserDefaults.standard.removeObject(forKey: providerKey)
        UserDefaults.standard.removeObject(forKey: fallbackEnabledKey)
        UserDefaults.standard.removeObject(forKey: fallbackProviderKey)
        UserDefaults.standard.removeObject(forKey: languageKey)
        for provider in SpeechProvider.allCases {
            UserDefaults.standard.removeObject(forKey: languageKeyPrefix + provider.rawValue)
        }
    }
}
