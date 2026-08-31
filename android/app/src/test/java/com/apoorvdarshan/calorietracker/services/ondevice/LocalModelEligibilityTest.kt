package com.apoorvdarshan.calorietracker.services.ondevice

import com.apoorvdarshan.calorietracker.data.executableAIModelOrDefault
import com.apoorvdarshan.calorietracker.data.executableAIProviderOrDefault
import com.apoorvdarshan.calorietracker.data.executableSpeechProviderOrDefault
import com.apoorvdarshan.calorietracker.models.AIProvider
import com.apoorvdarshan.calorietracker.models.SpeechProvider
import com.apoorvdarshan.calorietracker.ui.settings.SettingsUiState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalModelEligibilityTest {
    @Test
    fun exactPublishedArtifactsArePinned() {
        assertEquals("gemma-4-E2B-it.litertlm", LocalModelCatalog.gemma4E2b.fileName)
        assertEquals(
            "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/6b78abd019e61a1ca4cbe3b212d2c9ce8ff38a94/gemma-4-E2B-it.litertlm",
            LocalModelCatalog.gemma4E2b.downloadUrl
        )
        assertEquals(2_588_147_712L, LocalModelCatalog.gemma4E2b.expectedBytes)
        assertEquals(
            "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c",
            LocalModelCatalog.gemma4E2b.sha256
        )
        assertEquals("Apache-2.0", LocalModelCatalog.gemma4E2b.licenseName)
        assertEquals(
            "https://ai.google.dev/gemma/apache_2",
            LocalModelCatalog.gemma4E2b.licenseUrl
        )
        assertTrue(
            LocalModelCatalog.gemma4E2b.sourceUrl.contains(
                "6b78abd019e61a1ca4cbe3b212d2c9ce8ff38a94"
            )
        )
        assertEquals("ggml-base.bin", LocalModelCatalog.whisperBase.fileName)
        assertEquals(
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin",
            LocalModelCatalog.whisperBase.downloadUrl
        )
        assertEquals(147_951_465L, LocalModelCatalog.whisperBase.expectedBytes)
        assertEquals(
            "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
            LocalModelCatalog.whisperBase.sha256
        )
    }

    @Test
    fun gemmaRequiresAnEightGbClassSupportedDevice() {
        val gib = 1_073_741_824L

        assertFalse(
            LocalModelEligibility.isEligible(LocalModelCatalog.gemma4E2b, 6L * gib, listOf("arm64-v8a"))
        )
        assertTrue(
            LocalModelEligibility.isEligible(
                LocalModelCatalog.gemma4E2b,
                7L * gib + 1L,
                listOf("arm64-v8a")
            )
        )
        assertFalse(
            LocalModelEligibility.isEligible(LocalModelCatalog.gemma4E2b, 8L * gib, listOf("armeabi-v7a"))
        )
        assertEquals(
            LocalModelIneligibility.INSUFFICIENT_MEMORY,
            LocalModelEligibility.ineligibility(
                LocalModelCatalog.gemma4E2b,
                6L * gib,
                listOf("arm64-v8a"),
                isLowRamDevice = true
            )
        )
        assertEquals(
            LocalModelIneligibility.UNSUPPORTED_ABI,
            LocalModelEligibility.ineligibility(
                LocalModelCatalog.gemma4E2b,
                8L * gib,
                listOf("armeabi-v7a")
            )
        )
    }

    @Test
    fun whisperBaseIsOfferedOnArm64AcrossMemoryTiers() {
        val gib = 1_073_741_824L

        assertTrue(
            LocalModelEligibility.isEligible(LocalModelCatalog.whisperBase, 4L * gib, listOf("arm64-v8a"))
        )
        assertTrue(
            LocalModelEligibility.isEligible(LocalModelCatalog.whisperBase, 8L * gib, listOf("arm64-v8a"))
        )
        assertFalse(
            LocalModelEligibility.isEligible(LocalModelCatalog.whisperBase, 8L * gib, listOf("x86_64"))
        )
        assertTrue(
            LocalModelEligibility.isEligible(
                LocalModelCatalog.whisperBase,
                8L * gib,
                listOf("arm64-v8a"),
                isLowRamDevice = true
            )
        )
        assertEquals(
            null,
            LocalModelEligibility.ineligibility(
                LocalModelCatalog.whisperBase,
                8L * gib,
                listOf("arm64-v8a"),
                isLowRamDevice = true
            )
        )
        assertEquals(
            LocalModelIneligibility.LOW_RAM_DEVICE,
            LocalModelEligibility.ineligibility(
                LocalModelCatalog.gemma4E2b,
                8L * gib,
                listOf("arm64-v8a"),
                isLowRamDevice = true
            )
        )
    }

    @Test
    fun stalePersistedLocalRoutesResolveToSafeDefaultsBeforeReconciliationFinishes() {
        assertEquals(
            AIProvider.GEMINI,
            executableAIProviderOrDefault(AIProvider.LOCAL_GEMMA, localGemmaExecutable = false)
        )
        assertEquals(
            AIProvider.LOCAL_GEMMA,
            executableAIProviderOrDefault(AIProvider.LOCAL_GEMMA, localGemmaExecutable = true)
        )
        assertEquals(
            AIProvider.GEMINI.defaultModel,
            executableAIModelOrDefault(
                provider = AIProvider.LOCAL_GEMMA,
                model = AIProvider.LOCAL_GEMMA.defaultModel,
                localGemmaExecutable = false,
                defaultModel = AIProvider.GEMINI.defaultModel
            )
        )
        assertEquals(
            AIProvider.LOCAL_GEMMA.defaultModel,
            executableAIModelOrDefault(
                provider = AIProvider.LOCAL_GEMMA,
                model = AIProvider.LOCAL_GEMMA.defaultModel,
                localGemmaExecutable = true,
                defaultModel = AIProvider.GEMINI.defaultModel
            )
        )
        assertEquals(
            SpeechProvider.NATIVE,
            executableSpeechProviderOrDefault(
                SpeechProvider.LOCAL_WHISPER,
                localWhisperExecutable = false,
                default = SpeechProvider.NATIVE
            )
        )
        assertEquals(
            SpeechProvider.LOCAL_WHISPER,
            executableSpeechProviderOrDefault(
                SpeechProvider.LOCAL_WHISPER,
                localWhisperExecutable = true,
                default = SpeechProvider.NATIVE
            )
        )
    }

    @Test
    fun localProvidersAreHiddenUntilTheVerifiedModelIsExecutable() {
        val missing = SettingsUiState(
            localModelStates = mapOf(
                LocalModelId.GEMMA_4_E2B to LocalModelState(
                    LocalModelCatalog.gemma4E2b,
                    eligible = true,
                    status = LocalModelInstallStatus.NotInstalled
                ),
                LocalModelId.WHISPER_BASE to LocalModelState(
                    LocalModelCatalog.whisperBase,
                    eligible = true,
                    status = LocalModelInstallStatus.NotInstalled
                )
            )
        )
        assertFalse(AIProvider.LOCAL_GEMMA in missing.availableVisionProviders)
        assertFalse(AIProvider.LOCAL_GEMMA in missing.availableTextProviders)
        assertFalse(SpeechProvider.LOCAL_WHISPER in missing.availableSpeechProviders)
        assertFalse(SpeechProvider.LOCAL_WHISPER in missing.availableSpeechFallbackProviders)

        val installed = missing.copy(
            localModelStates = missing.localModelStates.mapValues { (_, state) ->
                state.copy(status = LocalModelInstallStatus.Installed)
            }
        )
        assertTrue(AIProvider.LOCAL_GEMMA in installed.availableVisionProviders)
        assertTrue(AIProvider.LOCAL_GEMMA in installed.availableTextProviders)
        assertTrue(SpeechProvider.LOCAL_WHISPER in installed.availableSpeechProviders)
        assertTrue(SpeechProvider.LOCAL_WHISPER in installed.availableSpeechFallbackProviders)

        val ineligible = installed.copy(
            localModelStates = installed.localModelStates.mapValues { (id, state) ->
                state.copy(
                    eligible = false,
                    ineligibility = if (id == LocalModelId.GEMMA_4_E2B) {
                        LocalModelIneligibility.INSUFFICIENT_MEMORY
                    } else {
                        LocalModelIneligibility.UNSUPPORTED_ABI
                    }
                )
            }
        )
        assertFalse(AIProvider.LOCAL_GEMMA in ineligible.availableVisionProviders)
        assertFalse(AIProvider.LOCAL_GEMMA in ineligible.availableTextProviders)
        assertFalse(SpeechProvider.LOCAL_WHISPER in ineligible.availableSpeechProviders)
        assertFalse(SpeechProvider.LOCAL_WHISPER in ineligible.availableSpeechFallbackProviders)
    }
}
