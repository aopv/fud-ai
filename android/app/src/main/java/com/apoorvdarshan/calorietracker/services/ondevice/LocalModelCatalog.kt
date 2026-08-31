package com.apoorvdarshan.calorietracker.services.ondevice

import kotlin.math.ceil

enum class LocalModelId {
    GEMMA_4_E2B,
    WHISPER_BASE
}

data class LocalModelDescriptor(
    val id: LocalModelId,
    val displayName: String,
    val fileName: String,
    val downloadUrl: String,
    val expectedBytes: Long,
    val sha256: String,
    val licenseName: String,
    val licenseUrl: String,
    val sourceUrl: String,
    val minimumMemoryClassGb: Int?,
    val supportedAbis: Set<String>
)

enum class LocalModelIneligibility {
    LOW_RAM_DEVICE,
    UNSUPPORTED_ABI,
    INSUFFICIENT_MEMORY
}

object LocalModelCatalog {
    val gemma4E2b = LocalModelDescriptor(
        id = LocalModelId.GEMMA_4_E2B,
        displayName = "Gemma 4 E2B",
        fileName = "gemma-4-E2B-it.litertlm",
        downloadUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/6b78abd019e61a1ca4cbe3b212d2c9ce8ff38a94/gemma-4-E2B-it.litertlm",
        expectedBytes = 2_588_147_712L,
        sha256 = "181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c",
        licenseName = "Apache-2.0",
        licenseUrl = "https://ai.google.dev/gemma/apache_2",
        sourceUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/tree/6b78abd019e61a1ca4cbe3b212d2c9ce8ff38a94",
        minimumMemoryClassGb = 8,
        supportedAbis = setOf("arm64-v8a", "x86_64")
    )

    val whisperBase = LocalModelDescriptor(
        id = LocalModelId.WHISPER_BASE,
        displayName = "Whisper Base",
        fileName = "ggml-base.bin",
        downloadUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin",
        expectedBytes = 147_951_465L,
        sha256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        licenseName = "MIT",
        licenseUrl = "https://github.com/ggml-org/whisper.cpp/blob/master/LICENSE",
        sourceUrl = "https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1",
        minimumMemoryClassGb = null,
        supportedAbis = setOf("arm64-v8a")
    )

    val all: List<LocalModelDescriptor> = listOf(gemma4E2b, whisperBase)

    fun descriptor(id: LocalModelId): LocalModelDescriptor = all.first { it.id == id }
}

/**
 * Android reserves some physical RAM before reporting [android.app.ActivityManager.MemoryInfo.totalMem].
 * Rounding the reported GiB upward maps common 5.5 GiB and 7.4 GiB readings back to their marketed
 * 6 GB and 8 GB device classes without relying on the much smaller per-app heap limit.
 */
object LocalModelEligibility {
    private const val GIB = 1_073_741_824.0

    fun memoryClassGb(totalMemoryBytes: Long): Int =
        ceil(totalMemoryBytes.coerceAtLeast(0L) / GIB).toInt()

    fun isEligible(
        descriptor: LocalModelDescriptor,
        totalMemoryBytes: Long,
        supportedAbis: Collection<String>,
        isLowRamDevice: Boolean = false
    ): Boolean = ineligibility(
        descriptor,
        totalMemoryBytes,
        supportedAbis,
        isLowRamDevice
    ) == null

    fun ineligibility(
        descriptor: LocalModelDescriptor,
        totalMemoryBytes: Long,
        supportedAbis: Collection<String>,
        isLowRamDevice: Boolean = false
    ): LocalModelIneligibility? = when {
        descriptor.minimumMemoryClassGb?.let { memoryClassGb(totalMemoryBytes) < it } == true ->
            LocalModelIneligibility.INSUFFICIENT_MEMORY
        isLowRamDevice && descriptor.minimumMemoryClassGb != null ->
            LocalModelIneligibility.LOW_RAM_DEVICE
        descriptor.supportedAbis.none(supportedAbis::contains) ->
            LocalModelIneligibility.UNSUPPORTED_ABI
        else -> null
    }
}
