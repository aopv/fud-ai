package com.apoorvdarshan.calorietracker.services.speech

import com.apoorvdarshan.calorietracker.data.KeyStore
import com.apoorvdarshan.calorietracker.data.PreferencesStore
import com.apoorvdarshan.calorietracker.models.SpeechProvider
import com.apoorvdarshan.calorietracker.services.ai.FoodAnalysisService
import kotlinx.coroutines.flow.first
import okhttp3.OkHttpClient
import java.io.File

/**
 * Routes a single-shot transcription to the currently-selected remote STT provider.
 * Native on-device STT is handled separately via [NativeSpeechRecognizer] since it
 * streams partial results rather than taking a file upload.
 */
class SpeechService(
    private val prefs: PreferencesStore,
    private val keyStore: KeyStore,
    private val okHttp: OkHttpClient = FoodAnalysisService.defaultClient
) {

    /** Returns the transcript text. Throws [SttApiError] on any failure. */
    suspend fun transcribeRemote(audio: File): String {
        val provider = prefs.selectedSpeechProvider.first()
        val languageCode = prefs.selectedSpeechLanguage(provider).first().remoteLanguageCode()
        val apiKey = keyStore.speechApiKey(provider)

        if (provider.requiresApiKey && apiKey.isNullOrEmpty()) throw SttApiError.NoApiKey

        return when (provider) {
            SpeechProvider.GEMINI -> GeminiAudioClient.transcribe(
                client = okHttp,
                apiKey = apiKey!!,
                model = provider.defaultModel,
                audio = audio,
                languageCode = languageCode
            )
            SpeechProvider.OPENAI -> WhisperClient.transcribe(
                client = okHttp,
                baseUrl = "https://api.openai.com/v1",
                apiKey = apiKey!!,
                model = provider.defaultModel,
                audio = audio,
                languageCode = languageCode
            )
            SpeechProvider.GROQ -> WhisperClient.transcribe(
                client = okHttp,
                baseUrl = "https://api.groq.com/openai/v1",
                apiKey = apiKey!!,
                model = provider.defaultModel,
                audio = audio,
                languageCode = languageCode
            )
            SpeechProvider.DEEPGRAM -> DeepgramClient.transcribe(
                client = okHttp,
                apiKey = apiKey!!,
                model = provider.defaultModel,
                audio = audio,
                languageCode = languageCode
            )
            SpeechProvider.ASSEMBLY_AI -> AssemblyAIClient.transcribe(
                client = okHttp,
                apiKey = apiKey!!,
                speechModels = listOf(provider.defaultModel, "universal-2"),
                audio = audio,
                languageCode = languageCode
            )
            SpeechProvider.NATIVE ->
                error("NATIVE speech should use NativeSpeechRecognizer, not transcribeRemote().")
        }
    }
}
