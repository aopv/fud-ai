package com.apoorvdarshan.calorietracker.services.ai

import com.apoorvdarshan.calorietracker.models.AIProvider
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AIRequestConfigurationTest {
    @Test
    fun geminiUsesCurrentModelsAndFallsBackFromRetiredChoices() {
        assertEquals("gemini-3.5-flash-lite", AIProvider.GEMINI.defaultModel)
        assertTrue(AIProvider.GEMINI.models.contains("gemini-3.6-flash"))
        assertTrue(AIProvider.GEMINI.models.contains("gemini-3.5-flash"))
        assertFalse(AIProvider.GEMINI.models.contains("gemini-2.5-flash"))
        assertFalse(AIProvider.GEMINI.models.contains("gemini-2.5-pro"))
        assertEquals(
            "gemini-3.5-flash-lite",
            AIProvider.GEMINI.supportedModelOrDefault("gemini-2.5-pro")
        )
        assertEquals(
            "gemini-3.5-flash-lite",
            AIProvider.upgradedLegacyGeminiModel("gemini-3.1-flash-lite")
        )
        assertEquals(
            "gemini-3.6-flash",
            AIProvider.upgradedLegacyGeminiModel("gemini-3.1-pro-preview")
        )
        assertEquals(
            "gemini-3.6-flash",
            AIProvider.upgradedLegacyGeminiModel("gemini-3.5-flash")
        )
        assertEquals(null, AIProvider.upgradedLegacyGeminiModel("gemini-3.6-flash"))
    }

    @Test
    fun timeoutConfigurationClampsToSupportedRange() {
        assertEquals(30, AIProvider.normalizedRequestTimeoutSeconds(1))
        assertEquals(180, AIProvider.normalizedRequestTimeoutSeconds(180))
        assertEquals(600, AIProvider.normalizedRequestTimeoutSeconds(999))
    }

    @Test
    fun configurableTimeoutOnlyChangesLocalAndCustomClients() {
        val base = OkHttpClient.Builder()
            .readTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

        val cloud = FoodAnalysisService.clientForProvider(base, AIProvider.GEMINI, 240)
        val local = FoodAnalysisService.clientForProvider(base, AIProvider.OLLAMA, 240)

        assertSame(base, cloud)
        assertEquals(240_000, local.readTimeoutMillis)
        assertEquals(240_000, local.writeTimeoutMillis)
    }
}
