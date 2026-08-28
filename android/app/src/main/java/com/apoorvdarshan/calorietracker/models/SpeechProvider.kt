package com.apoorvdarshan.calorietracker.models

import androidx.annotation.StringRes
import com.apoorvdarshan.calorietracker.R
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class SpeechProvider {
    @SerialName("Native (On-Device)") NATIVE,
    @SerialName("Gemini Audio") GEMINI,
    @SerialName("OpenAI Whisper") OPENAI,
    @SerialName("Groq (Whisper)") GROQ,
    @SerialName("Mistral Voxtral") MISTRAL,
    @SerialName("Deepgram") DEEPGRAM,
    @SerialName("AssemblyAI") ASSEMBLY_AI;

    @get:StringRes
    val displayNameRes: Int get() = when (this) {
        NATIVE -> R.string.speech_provider_native
        GEMINI -> R.string.speech_provider_gemini
        OPENAI -> R.string.speech_provider_openai
        GROQ -> R.string.speech_provider_groq
        MISTRAL -> R.string.speech_provider_mistral
        DEEPGRAM -> R.string.speech_provider_deepgram
        ASSEMBLY_AI -> R.string.speech_provider_assemblyai
    }

    val requiresApiKey: Boolean get() = this != NATIVE

    val matchingAIProvider: AIProvider? get() = when (this) {
        GEMINI -> AIProvider.GEMINI
        OPENAI -> AIProvider.OPENAI
        GROQ -> AIProvider.GROQ
        MISTRAL -> AIProvider.MISTRAL
        NATIVE, DEEPGRAM, ASSEMBLY_AI -> null
    }

    @get:StringRes
    val apiKeyPlaceholderRes: Int get() = when (this) {
        NATIVE -> R.string.speech_key_placeholder_native
        GEMINI -> R.string.speech_key_placeholder_gemini
        OPENAI -> R.string.speech_key_placeholder_openai
        GROQ -> R.string.speech_key_placeholder_groq
        MISTRAL -> R.string.speech_key_placeholder_mistral
        DEEPGRAM -> R.string.speech_key_placeholder_deepgram
        ASSEMBLY_AI -> R.string.speech_key_placeholder_assemblyai
    }

    val defaultModel: String get() = when (this) {
        NATIVE -> ""
        GEMINI -> "gemini-3.5-transcribe"
        OPENAI -> "gpt-transcribe"
        GROQ -> "whisper-large-v3"
        MISTRAL -> "voxtral-mini-2602"
        DEEPGRAM -> "nova-3"
        ASSEMBLY_AI -> "universal-3-pro"
    }

    @get:StringRes
    val descriptionRes: Int get() = when (this) {
        NATIVE -> R.string.speech_description_native
        GEMINI -> R.string.speech_description_gemini
        OPENAI -> R.string.speech_description_openai
        GROQ -> R.string.speech_description_groq
        MISTRAL -> R.string.speech_description_mistral
        DEEPGRAM -> R.string.speech_description_deepgram
        ASSEMBLY_AI -> R.string.speech_description_assemblyai
    }

    companion object {
        val remoteProviders: List<SpeechProvider>
            get() = values().filter { it.requiresApiKey }

        /** First-party STT route for a supported Primary AI provider. */
        fun matchingPrimaryAIProvider(provider: AIProvider): SpeechProvider? = when (provider) {
            AIProvider.GEMINI -> GEMINI
            AIProvider.OPENAI -> OPENAI
            AIProvider.GROQ -> GROQ
            AIProvider.MISTRAL -> MISTRAL
            else -> null
        }

        fun migratedV7Selection(
            primaryAIProvider: AIProvider,
            currentSpeechProvider: SpeechProvider
        ): SpeechProvider = if (currentSpeechProvider == NATIVE) {
            matchingPrimaryAIProvider(primaryAIProvider) ?: NATIVE
        } else {
            currentSpeechProvider
        }
    }
}
