package com.apoorvdarshan.calorietracker.models

import androidx.annotation.StringRes
import com.apoorvdarshan.calorietracker.R
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class AIProvider {
    @SerialName("Google Gemini") GEMINI,
    @SerialName("OpenAI") OPENAI,
    @SerialName("Anthropic Claude") ANTHROPIC,
    @SerialName("xAI Grok") XAI,
    @SerialName("OpenRouter") OPENROUTER,
    @SerialName("Together AI") TOGETHER_AI,
    @SerialName("Groq") GROQ,
    @SerialName("Hugging Face") HUGGING_FACE,
    @SerialName("Fireworks AI") FIREWORKS,
    @SerialName("DeepInfra") DEEP_INFRA,
    @SerialName("Mistral") MISTRAL,
    @SerialName("Ollama (Local)") OLLAMA,
    @SerialName("Custom (OpenAI-compatible)") CUSTOM_OPENAI;

    @get:StringRes
    val displayNameRes: Int get() = when (this) {
        GEMINI -> R.string.ai_provider_gemini
        OPENAI -> R.string.ai_provider_openai
        ANTHROPIC -> R.string.ai_provider_anthropic
        XAI -> R.string.ai_provider_xai
        OPENROUTER -> R.string.ai_provider_openrouter
        TOGETHER_AI -> R.string.ai_provider_together
        GROQ -> R.string.ai_provider_groq
        HUGGING_FACE -> R.string.ai_provider_huggingface
        FIREWORKS -> R.string.ai_provider_fireworks
        DEEP_INFRA -> R.string.ai_provider_deepinfra
        MISTRAL -> R.string.ai_provider_mistral
        OLLAMA -> R.string.ai_provider_ollama
        CUSTOM_OPENAI -> R.string.ai_provider_custom
    }

    val baseUrl: String get() = when (this) {
        GEMINI -> "https://generativelanguage.googleapis.com/v1beta"
        OPENAI -> "https://api.openai.com/v1"
        ANTHROPIC -> "https://api.anthropic.com/v1"
        XAI -> "https://api.x.ai/v1"
        OPENROUTER -> "https://openrouter.ai/api/v1"
        TOGETHER_AI -> "https://api.together.xyz/v1"
        GROQ -> "https://api.groq.com/openai/v1"
        HUGGING_FACE -> "https://router.huggingface.co/v1"
        FIREWORKS -> "https://api.fireworks.ai/inference/v1"
        DEEP_INFRA -> "https://api.deepinfra.com/v1/openai"
        MISTRAL -> "https://api.mistral.ai/v1"
        OLLAMA -> "http://localhost:11434/v1"
        CUSTOM_OPENAI -> ""
    }

    /**
     * Only models that are currently in service AND accept image input + return structured text.
     * Lineups verified against provider docs on 2026-07-21. Mirrors iOS AIProvider.swift.
     */
    val models: List<String> get() = when (this) {
        GEMINI -> listOf(
            "gemini-3.5-flash-lite",
            "gemini-3.6-flash",
            "gemini-3.5-flash",
            "gemini-3.1-flash-lite",
            "gemini-3.1-pro-preview"
        )
        OPENAI -> listOf(
            "gpt-5.4-mini",
            "gpt-5.5",
            "gpt-5.4-nano",
            "gpt-4.1",
            "gpt-4.1-mini",
            "gpt-4o-mini"
        )
        ANTHROPIC -> listOf(
            "claude-sonnet-5",
            "claude-opus-4-8",
            "claude-haiku-4-5",
            "claude-sonnet-4-6",
            "claude-opus-4-7"
        )
        XAI -> listOf(
            "grok-4.3"
        )
        OPENROUTER -> listOf(
            "openrouter/free",
            "google/gemini-3.1-flash-lite",
            "openai/gpt-5-mini",
            "anthropic/claude-sonnet-5",
            "qwen/qwen3-vl-8b-instruct"
        )
        TOGETHER_AI -> listOf(
            "Qwen/Qwen3.5-9B",
            "google/gemma-4-31B-it",
            "MiniMaxAI/MiniMax-M3"
        )
        GROQ -> listOf(
            "qwen/qwen3.6-27b"
        )
        HUGGING_FACE -> listOf(
            "google/gemma-4-31B-it",
            "google/gemma-3-27b-it",
            "Qwen/Qwen3.5-9B",
            "Qwen/Qwen2.5-VL-72B-Instruct"
        )
        FIREWORKS -> listOf(
            "accounts/fireworks/models/qwen3p7-plus",
            "accounts/fireworks/models/minimax-m3",
            "accounts/fireworks/models/kimi-k2p6"
        )
        DEEP_INFRA -> listOf(
            "google/gemma-3-27b-it",
            "google/gemma-4-31B-it",
            "google/gemma-4-26B-A4B-it"
        )
        MISTRAL -> listOf(
            "mistral-small-2603",
            "mistral-medium-2604",
            "ministral-14b-2512"
        )
        OLLAMA -> listOf(
            "qwen3-vl",
            "gemma4",
            "llama3.2-vision",
            "llava",
            "moondream"
        )
        CUSTOM_OPENAI -> emptyList()
    }

    val defaultModel: String get() = models.firstOrNull() ?: ""

    fun supportedModelOrDefault(model: String?): String {
        val normalized = model?.let(::normalizeModelId)
        return when {
            normalized.isNullOrBlank() -> defaultModel
            supportsCustomModelName -> normalized
            models.contains(normalized) -> normalized
            else -> defaultModel
        }
    }

    val requiresApiKey: Boolean get() = this != OLLAMA
    val requiresCustomEndpoint: Boolean get() = this == CUSTOM_OPENAI
    val requiresCustomModelName: Boolean get() = this == CUSTOM_OPENAI
    val usesConfigurableRequestTimeout: Boolean get() = this == OLLAMA || this == CUSTOM_OPENAI
    val supportsCustomModelName: Boolean
        get() = this == OPENROUTER || this == HUGGING_FACE || this == CUSTOM_OPENAI

    val apiFormat: ApiFormat get() = when (this) {
        GEMINI -> ApiFormat.GEMINI
        ANTHROPIC -> ApiFormat.ANTHROPIC
        OPENAI, XAI, OPENROUTER, TOGETHER_AI, GROQ, HUGGING_FACE,
        FIREWORKS, DEEP_INFRA, MISTRAL, OLLAMA, CUSTOM_OPENAI -> ApiFormat.OPENAI_COMPATIBLE
    }

    @get:StringRes
    val apiKeyPlaceholderRes: Int get() = when (this) {
        GEMINI -> R.string.ai_key_placeholder_gemini
        OPENAI -> R.string.ai_key_placeholder_openai
        ANTHROPIC -> R.string.ai_key_placeholder_anthropic
        XAI -> R.string.ai_key_placeholder_xai
        OPENROUTER -> R.string.ai_key_placeholder_openrouter
        TOGETHER_AI -> R.string.ai_key_placeholder_together
        GROQ -> R.string.ai_key_placeholder_groq
        HUGGING_FACE -> R.string.ai_key_placeholder_huggingface
        FIREWORKS -> R.string.ai_key_placeholder_fireworks
        DEEP_INFRA -> R.string.ai_key_placeholder_deepinfra
        MISTRAL -> R.string.ai_key_placeholder_mistral
        OLLAMA -> R.string.ai_key_placeholder_ollama
        CUSTOM_OPENAI -> R.string.ai_key_placeholder_custom
    }

    enum class ApiFormat { GEMINI, OPENAI_COMPATIBLE, ANTHROPIC }

    companion object {
        const val DEFAULT_REQUEST_TIMEOUT_SECONDS = 180

        fun normalizedRequestTimeoutSeconds(value: Int): Int = value.coerceIn(30, 600)

        fun normalizeModelId(model: String): String =
            when (model.trim()) {
                "gemini-3.1-flash-lite-preview" -> "gemini-3.1-flash-lite"
                else -> model
            }

        /**
         * One-time upgrade path for older Gemini presets. Kept separate from
         * normalization so users may still manually select supported older models.
         */
        fun upgradedLegacyGeminiModel(model: String?): String? =
            when (model?.let(::normalizeModelId)) {
                "gemini-2.5-flash", "gemini-2.5-pro", "gemini-3.1-flash-lite" ->
                    "gemini-3.5-flash-lite"
                "gemini-3.1-pro-preview", "gemini-3.5-flash" -> "gemini-3.6-flash"
                else -> null
            }
    }
}
