package com.apoorvdarshan.calorietracker.models

import com.apoorvdarshan.calorietracker.R
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.Locale
import java.util.UUID
import kotlin.math.log10

/**
 * One set of tape-measure circumferences logged at a point in time. Every site is optional — the
 * user logs only what they want. Stored internally in centimetres (display converts to inches when
 * the app is in imperial mode), mirroring how WeightEntry stores kg regardless of display unit.
 *
 * The derived metrics (waist-to-hip, waist-to-height, US-Navy body-fat %, wrist frame size) are
 * computed on the fly from this entry plus the profile's height + gender. Nothing here is written
 * back to UserProfile — these are purely extra signal for the AI goal calc and the Coach.
 */
@Serializable
data class BodyMeasurement(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    @Serializable(with = InstantSerializer::class)
    val date: Instant = Instant.now(),
    val neckCm: Double? = null,
    val waistCm: Double? = null,
    val hipsCm: Double? = null,
    val chestCm: Double? = null,
    val upperArmCm: Double? = null,
    val thighCm: Double? = null,
    val calfCm: Double? = null,
    val wristCm: Double? = null
) {
    /** True when at least one circumference is present — an empty entry is meaningless. */
    val hasAnyValue: Boolean
        get() = listOf(neckCm, waistCm, hipsCm, chestCm, upperArmCm, thighCm, calfCm, wristCm)
            .any { it != null }

    /** Waist ÷ hips. WHO cardiometabolic-risk marker. Needs waist + hips. */
    val waistToHipRatio: Double?
        get() {
            val waist = waistCm ?: return null
            val hips = hipsCm ?: return null
            if (hips <= 0) return null
            return waist / hips
        }

    /** Waist ÷ height. "Keep your waist under half your height." Needs waist + a height. */
    fun waistToHeightRatio(heightCm: Double): Double? {
        val waist = waistCm ?: return null
        if (heightCm <= 0) return null
        return waist / heightCm
    }

    /**
     * U.S. Navy body-fat % estimate (metric coefficients, inputs in cm). Men use neck + waist;
     * women use neck + waist + hips. Returns null when required sites are missing or the logarithm
     * domain is invalid, and rejects obviously-bad outputs.
     */
    fun usNavyBodyFatPercent(gender: Gender, heightCm: Double): Double? {
        if (heightCm <= 0) return null
        val neck = neckCm ?: return null
        val waist = waistCm ?: return null
        val result: Double = when (gender) {
            Gender.FEMALE -> {
                val hips = hipsCm ?: return null
                val inner = waist + hips - neck
                if (inner <= 0) return null
                495.0 / (1.29579 - 0.35004 * log10(inner) + 0.22100 * log10(heightCm)) - 450.0
            }
            else -> {
                val inner = waist - neck
                if (inner <= 0) return null
                495.0 / (1.0324 - 0.19077 * log10(inner) + 0.15456 * log10(heightCm)) - 450.0
            }
        }
        if (!result.isFinite() || result < 2 || result > 65) return null
        return result
    }

    /** Bone-frame size from height ÷ wrist circumference (gender-specific cut-offs). Needs wrist. */
    fun wristFrame(gender: Gender, heightCm: Double): FrameSize? {
        val wrist = wristCm ?: return null
        if (wrist <= 0 || heightCm <= 0) return null
        val ratio = heightCm / wrist
        return when (gender) {
            Gender.FEMALE -> when {
                ratio > 11.0 -> FrameSize.SMALL
                ratio >= 10.1 -> FrameSize.MEDIUM
                else -> FrameSize.LARGE
            }
            else -> when {
                ratio > 10.4 -> FrameSize.SMALL
                ratio >= 9.6 -> FrameSize.MEDIUM
                else -> FrameSize.LARGE
            }
        }
    }

    /**
     * Compact AI-prompt summary of the logged sites + derived metrics, always in cm for a single
     * consistent unit. Returns null when nothing is logged so callers can omit the section entirely.
     */
    fun promptSummary(gender: Gender, heightCm: Double): String? {
        if (!hasAnyValue) return null
        val sites = mutableListOf<String>()
        fun site(label: String, value: Double?) {
            if (value != null) sites.add("$label ${String.format(Locale.US, "%.1f", value)} cm")
        }
        site("neck", neckCm)
        site("waist", waistCm)
        site("hips", hipsCm)
        site("chest", chestCm)
        site("upper arm", upperArmCm)
        site("thigh", thighCm)
        site("calf", calfCm)
        site("wrist", wristCm)

        val metrics = mutableListOf<String>()
        waistToHipRatio?.let { metrics.add("waist-to-hip ${String.format(Locale.US, "%.2f", it)}") }
        waistToHeightRatio(heightCm)?.let { metrics.add("waist-to-height ${String.format(Locale.US, "%.2f", it)}") }
        usNavyBodyFatPercent(gender, heightCm)?.let { metrics.add("US-Navy body fat ~${String.format(Locale.US, "%.0f", it)}%") }
        wristFrame(gender, heightCm)?.let { metrics.add("frame ${it.label.lowercase()}") }

        var summary = sites.joinToString(", ")
        if (metrics.isNotEmpty()) summary += " | derived: " + metrics.joinToString(", ")
        return summary
    }

    enum class FrameSize(val label: String, val labelRes: Int) {
        SMALL("Small", R.string.frame_small),
        MEDIUM("Medium", R.string.frame_medium),
        LARGE("Large", R.string.frame_large)
    }

    /** The eight circumference sites, in display order. Used to render the per-site editor rows. */
    enum class Site(val label: String, val labelRes: Int) {
        NECK("Neck", R.string.measure_neck), WAIST("Waist", R.string.measure_waist),
        HIPS("Hips", R.string.measure_hips), CHEST("Chest", R.string.measure_chest),
        UPPER_ARM("Upper Arm", R.string.measure_upper_arm), THIGH("Thigh", R.string.measure_thigh),
        CALF("Calf", R.string.measure_calf), WRIST("Wrist", R.string.measure_wrist)
    }

    fun value(site: Site): Double? = when (site) {
        Site.NECK -> neckCm
        Site.WAIST -> waistCm
        Site.HIPS -> hipsCm
        Site.CHEST -> chestCm
        Site.UPPER_ARM -> upperArmCm
        Site.THIGH -> thighCm
        Site.CALF -> calfCm
        Site.WRIST -> wristCm
    }

    /** A copy with one site changed (same id + date — used for in-place daily updates). */
    fun setting(site: Site, cm: Double?): BodyMeasurement = when (site) {
        Site.NECK -> copy(neckCm = cm)
        Site.WAIST -> copy(waistCm = cm)
        Site.HIPS -> copy(hipsCm = cm)
        Site.CHEST -> copy(chestCm = cm)
        Site.UPPER_ARM -> copy(upperArmCm = cm)
        Site.THIGH -> copy(thighCm = cm)
        Site.CALF -> copy(calfCm = cm)
        Site.WRIST -> copy(wristCm = cm)
    }
}
