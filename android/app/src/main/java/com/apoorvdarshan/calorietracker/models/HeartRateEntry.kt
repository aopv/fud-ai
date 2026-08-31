package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable
enum class HeartRateSource {
    CAMERA,
    MANUAL
}

/** A single local wellness heart-rate spot check. Camera frames and waveforms are never stored. */
@Serializable
data class HeartRateEntry(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    @Serializable(with = InstantSerializer::class)
    val date: Instant = Instant.now(),
    val bpm: Int,
    val source: HeartRateSource,
    /** Normalized 0–1 camera signal confidence. Manual entries intentionally leave this null. */
    val quality: Double? = null
) {
    val isValid: Boolean
        get() = bpm in MIN_PLAUSIBLE_BPM..MAX_PLAUSIBLE_BPM &&
            (quality == null || (quality.isFinite() && quality in 0.0..1.0))

    companion object {
        const val MIN_PLAUSIBLE_BPM = 30
        const val MAX_PLAUSIBLE_BPM = 250
    }
}
