package com.apoorvdarshan.calorietracker.ui.settings

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.apoorvdarshan.calorietracker.FudAIApp
import com.apoorvdarshan.calorietracker.models.AIProvider
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
            assertEquals(baselineProvider, viewModel.ui.value.selectedAI)

            viewModel.refreshAiConfiguration()

            val refreshed = withTimeout(10_000) {
                viewModel.ui.first {
                    it.selectedAI == refreshedProvider &&
                        it.selectedModel == refreshedModel &&
                        it.apiKeyMasked == "issu...7890"
                }
            }
            assertEquals(refreshedProvider, refreshed.selectedAI)
            assertEquals(refreshedModel, refreshed.selectedModel)
            assertEquals("issu...7890", refreshed.apiKeyMasked)

            container.keyStore.setApiKey(refreshedProvider, null)
            viewModel.refreshAiConfiguration()
            val cleared = withTimeout(10_000) {
                viewModel.ui.first {
                    it.selectedAI == refreshedProvider && it.apiKeyMasked.isEmpty()
                }
            }
            assertTrue(cleared.apiKeyMasked.isEmpty())
        } finally {
            container.prefs.setSelectedAIProvider(originalProvider)
            container.prefs.setSelectedAIModel(originalModel)
            originalKeys.forEach { (provider, key) ->
                container.keyStore.setApiKey(provider, key)
            }
            viewModelStore.clear()
        }
    }
}
