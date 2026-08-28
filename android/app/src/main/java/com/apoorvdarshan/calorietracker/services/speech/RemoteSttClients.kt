package com.apoorvdarshan.calorietracker.services.speech

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.Base64

sealed class SttApiError(message: String) : Exception(message) {
    object NoApiKey : SttApiError("No STT API key configured.")
    class Network(cause: Throwable) : SttApiError("Network error: ${cause.localizedMessage}")
    class Api(msg: String) : SttApiError(msg)
    object InvalidResponse : SttApiError("Could not understand the transcription response.")
    object Timeout : SttApiError("Transcription timed out.")
}

/**
 * OpenAI Whisper + Groq share /v1/audio/transcriptions (multipart).
 */
object WhisperClient {
    suspend fun transcribe(
        client: OkHttpClient,
        baseUrl: String,
        apiKey: String,
        model: String,
        audio: File,
        languageCode: String? = null
    ): String = withContext(Dispatchers.IO) {
        val bodyBuilder = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("model", model)
            .addFormDataPart("file", audio.name, audio.asRequestBody("audio/m4a".toMediaType()))
        if (!languageCode.isNullOrBlank()) {
            bodyBuilder.addFormDataPart("language", languageCode)
        }
        val body = bodyBuilder.build()
        val req = Request.Builder()
            .url("$baseUrl/audio/transcriptions")
            .addHeader("Authorization", "Bearer $apiKey")
            .post(body)
            .build()
        runRequest(client, req)
    }
}

/**
 * Gemini API audio understanding via generateContent. This is batch audio
 * transcription, not Google Cloud Speech-to-Text's dedicated real-time STT API.
 */
object GeminiAudioClient {
    suspend fun transcribe(
        client: OkHttpClient,
        apiKey: String,
        model: String,
        audio: File,
        languageCode: String? = null
    ): String = withContext(Dispatchers.IO) {
        val languageInstruction = if (!languageCode.isNullOrBlank()) {
            " Prefer language code $languageCode when interpreting speech, but preserve the spoken language if it is clearly different."
        } else {
            ""
        }
        val prompt = """
            Transcribe this audio to text for a food logging app.$languageInstruction
            Return only the transcript text. Do not add summaries, labels, markdown, timestamps, or quotes.
        """.trimIndent()

        val parts = JSONArray()
            .put(
                JSONObject().put(
                    "inlineData",
                    JSONObject()
                        .put("mimeType", "audio/m4a")
                        .put("data", Base64.getEncoder().encodeToString(audio.readBytes()))
                )
            )
            .put(JSONObject().put("text", prompt))

        val body = JSONObject()
            .put("contents", JSONArray().put(JSONObject().put("parts", parts)))
            .toString()
            .toRequestBody("application/json; charset=utf-8".toMediaType())

        val req = Request.Builder()
            .url("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent")
            .addHeader("Content-Type", "application/json")
            .addHeader("X-goog-api-key", apiKey)
            .post(body)
            .build()

        val responseBody = runRequestRaw(client, req)
        runCatching {
            val partsJson = JSONObject(responseBody)
                .getJSONArray("candidates")
                .getJSONObject(0)
                .getJSONObject("content")
                .getJSONArray("parts")
            (0 until partsJson.length()).firstNotNullOfOrNull { index ->
                partsJson.getJSONObject(index).optString("text").takeIf { it.isNotBlank() }
            }?.trim()
        }.getOrNull()?.takeIf { it.isNotBlank() } ?: throw SttApiError.InvalidResponse
    }
}

/**
 * Deepgram: raw audio body, Token auth.
 */
object DeepgramClient {
    suspend fun transcribe(
        client: OkHttpClient,
        apiKey: String,
        model: String,
        audio: File,
        languageCode: String? = null
    ): String = withContext(Dispatchers.IO) {
        val languageQuery = if (!languageCode.isNullOrBlank()) "&language=$languageCode" else ""
        val req = Request.Builder()
            .url("https://api.deepgram.com/v1/listen?model=$model&punctuate=true&smart_format=true$languageQuery")
            .addHeader("Authorization", "Token $apiKey")
            .addHeader("Content-Type", "audio/m4a")
            .post(audio.asRequestBody("audio/m4a".toMediaType()))
            .build()
        val body = runRequestRaw(client, req)
        runCatching {
            JSONObject(body)
                .getJSONObject("results")
                .getJSONArray("channels")
                .getJSONObject(0)
                .getJSONArray("alternatives")
                .getJSONObject(0)
                .getString("transcript")
        }.getOrNull() ?: throw SttApiError.InvalidResponse
    }
}

/**
 * AssemblyAI: 3-step upload -> submit -> poll every 1s up to 60s.
 */
object AssemblyAIClient {
    suspend fun transcribe(
        client: OkHttpClient,
        apiKey: String,
        speechModels: List<String>,
        audio: File,
        languageCode: String? = null
    ): String = withContext(Dispatchers.IO) {
        // 1. Upload
        val uploadReq = Request.Builder()
            .url("https://api.assemblyai.com/v2/upload")
            .addHeader("authorization", apiKey)
            .post(audio.asRequestBody("audio/m4a".toMediaType()))
            .build()
        val uploadJson = JSONObject(runRequestRaw(client, uploadReq))
        val audioUrl = uploadJson.optString("upload_url").takeIf { it.isNotEmpty() }
            ?: throw SttApiError.InvalidResponse

        // 2. Submit
        val submitPayload = JSONObject()
            .put("audio_url", audioUrl)
            .put("speech_models", JSONArray(speechModels))
        if (!languageCode.isNullOrBlank()) {
            submitPayload.put("language_code", languageCode)
        } else {
            submitPayload.put("language_detection", true)
        }
        val submitBody = submitPayload.toString().toRequestBody("application/json".toMediaType())
        val submitReq = Request.Builder()
            .url("https://api.assemblyai.com/v2/transcript")
            .addHeader("authorization", apiKey)
            .post(submitBody)
            .build()
        val submitJson = JSONObject(runRequestRaw(client, submitReq))
        val transcriptId = submitJson.optString("id").takeIf { it.isNotEmpty() }
            ?: throw SttApiError.InvalidResponse

        // 3. Poll
        repeat(60) {
            delay(1_000)
            val pollReq = Request.Builder()
                .url("https://api.assemblyai.com/v2/transcript/$transcriptId")
                .addHeader("authorization", apiKey)
                .get()
                .build()
            val pollJson = JSONObject(runRequestRaw(client, pollReq))
            when (pollJson.optString("status")) {
                "completed" -> return@withContext pollJson.optString("text").orEmpty()
                "error" -> throw SttApiError.Api(pollJson.optString("error", "AssemblyAI error"))
            }
        }
        throw SttApiError.Timeout
    }
}

// Shared helpers -------------------------------------------------------

private suspend fun runRequest(client: OkHttpClient, req: Request): String {
    val body = runRequestRaw(client, req)
    return runCatching {
        JSONObject(body).optString("text").takeIf { it.isNotEmpty() }
    }.getOrNull() ?: throw SttApiError.InvalidResponse
}

private suspend fun runRequestRaw(client: OkHttpClient, req: Request): String = withContext(Dispatchers.IO) {
    try {
        client.newCall(req).execute().use { resp ->
            val str = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw SttApiError.Api("STT HTTP ${resp.code}: ${str.take(200)}")
            str
        }
    } catch (io: IOException) {
        throw SttApiError.Network(io)
    }
}
