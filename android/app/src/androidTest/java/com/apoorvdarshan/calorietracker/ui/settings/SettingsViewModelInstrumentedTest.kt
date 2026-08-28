package com.apoorvdarshan.calorietracker.ui.settings

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.apoorvdarshan.calorietracker.FudAIApp
import com.apoorvdarshan.calorietracker.models.AIProvider
import com.apoorvdarshan.calorietracker.models.SpeechProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SettingsViewModelInstrumentedTest {

    @Test
    fun matchingSpeechProviderReusesAiKeyUnlessItHasAnOverride() {
        val app = InstrumentationRegistry.getInstrumentation()
            .targetContext.applicationContext as FudAIApp
        val keyStore = app.container.keyStore
        val aiProvider = AIProvider.GEMINI
        val speechProvider = SpeechProvider.GEMINI
        val speechStorageKey = "speechApiKey_${speechProvider.name}"
        val originalAIKey = keyStore.apiKey(aiProvider)
        val originalSpeechOverride = keyStore.load(speechStorageKey)

        try {
            keyStore.setSpeechApiKey(speechProvider, null)
            keyStore.setApiKey(aiProvider, "shared-gemini-key")
            assertEquals("shared-gemini-key", keyStore.speechApiKey(speechProvider))

            keyStore.setSpeechApiKey(speechProvider, "speech-only-key")
            assertEquals("speech-only-key", keyStore.speechApiKey(speechProvider))
        } finally {
            keyStore.setApiKey(aiProvider, originalAIKey)
            keyStore.setSpeechApiKey(speechProvider, originalSpeechOverride)
        }
    }

    @Test
    fun refreshAiConfigurationReflectsValuesSavedAfterViewModelCreation() = runBlocking {
        val app = InstrumentationRegistry.getInstrumentation()
            .targetContext.applicationContext as FudAIApp
        val container = app.container
        val baselineProvider = AIProvider.ANTHROPIC
        val refreshedProvider = AIProvider.OPENAI
        val refreshedModel = refreshedProvider.models.last()
        val testKey = "issue170-test-key-1234567890"

        val originalProvider = container.prefs.selectedAIProvider.first()
        val originalModel = originalProvider.supportedModelOrDefault(
            container.prefs.selectedAIModel.first()
        )
        val originalSpeechProvider = container.prefs.selectedSpeechProvider.first()
        val originalSpeechFallbackProvider = container.prefs.selectedSpeechFallbackProvider.first()
        val originalKeys = listOf(baselineProvider, refreshedProvider)
            .associateWith(container.keyStore::apiKey)
        val viewModelStore = ViewModelStore()

        try {
            container.prefs.setSelectedAIProvider(baselineProvider)
            container.prefs.setSelectedAIModel(baselineProvider.defaultModel)
            container.keyStore.setApiKey(baselineProvider, null)

            val viewModel = ViewModelProvider(
                viewModelStore,
                SettingsViewModel.Factory(container)
            )[SettingsViewModel::class.java]

            withTimeout(10_000) {
                viewModel.ui.first {
                    it.selectedAI == baselineProvider &&
                        it.selectedModel == baselineProvider.defaultModel &&
                        it.apiKeyMasked.isEmpty()
                }
            }

            // Mirror onboarding writing a new provider/model/key after Settings was warmed.
            container.prefs.setSelectedAIProvider(refreshedProvider)
            container.prefs.setSelectedAIModel(refreshedModel)
            container.keyStore.setApiKey(refreshedProvider, testKey)
            container.prefs.setInitialSpeechProviderForAIProvider(refreshedProvider)
            assertEquals(baselineProvider, viewModel.ui.value.selectedAI)

            viewModel.refreshAiConfiguration()

            val refreshed = withTimeout(10_000) {
                viewModel.ui.first {
                        it.selectedAI == refreshedProvider &&
                        it.selectedModel == refreshedModel &&
                        it.apiKeyMasked == "issu...7890" &&
                        it.selectedSpeech == SpeechProvider.OPENAI &&
                        it.speechApiKeyMasked == "issu...7890"
                }
            }
            assertEquals(refreshedProvider, refreshed.selectedAI)
            assertEquals(refreshedModel, refreshed.selectedModel)
            assertEquals("issu...7890", refreshed.apiKeyMasked)
            assertEquals(SpeechProvider.OPENAI, refreshed.selectedSpeech)
            assertEquals("issu...7890", refreshed.speechApiKeyMasked)

            container.keyStore.setApiKey(refreshedProvider, null)
            viewModel.refreshAiConfiguration()
            val cleared = withTimeout(10_000) {
                viewModel.ui.first {
                    it.selectedAI == refreshedProvider &&
                        it.apiKeyMasked.isEmpty() &&
                        it.speechApiKeyMasked.isEmpty()
                }
            }
            assertTrue(cleared.apiKeyMasked.isEmpty())
            assertTrue(cleared.speechApiKeyMasked.isEmpty())
        } finally {
            container.prefs.setSelectedAIProvider(originalProvider)
            container.prefs.setSelectedAIModel(originalModel)
            container.prefs.setSelectedSpeechProvider(originalSpeechProvider)
            container.prefs.setSelectedSpeechFallbackProvider(originalSpeechFallbackProvider)
            originalKeys.forEach { (provider, key) ->
                container.keyStore.setApiKey(provider, key)
            }
            viewModelStore.clear()
        }
    }
}
