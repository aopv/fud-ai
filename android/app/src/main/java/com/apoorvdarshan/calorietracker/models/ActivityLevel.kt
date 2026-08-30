package com.apoorvdarshan.calorietracker.models

import androidx.annotation.StringRes
import com.apoorvdarshan.calorietracker.R
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class ActivityLevel {
    @SerialName("sedentary") SEDENTARY,
    @SerialName("light") LIGHT,
    @SerialName("moderate") MODERATE,
    @SerialName("active") ACTIVE,
    @SerialName("veryActive") VERY_ACTIVE,
    @SerialName("extraActive") EXTRA_ACTIVE;

    @get:StringRes
    val displayNameRes: Int get() = when (this) {
        SEDENTARY -> R.string.activity_sedentary
        LIGHT -> R.string.activity_light
        MODERATE -> R.string.activity_moderate
        ACTIVE -> R.string.activity_active
        VERY_ACTIVE -> R.string.activity_very_active
        EXTRA_ACTIVE -> R.string.activity_extra_active
    }

    @get:StringRes
    val subtitleRes: Int get() = when (this) {
        SEDENTARY -> R.string.activity_sedentary_subtitle
        LIGHT -> R.string.activity_light_subtitle
        MODERATE -> R.string.activity_moderate_subtitle
        ACTIVE -> R.string.activity_active_subtitle
        VERY_ACTIVE -> R.string.activity_very_active_subtitle
        EXTRA_ACTIVE -> R.string.activity_extra_active_subtitle
    }

    val multiplier: Double get() = when (this) {
        SEDENTARY -> 1.2
        LIGHT -> 1.375
        MODERATE -> 1.465
        ACTIVE -> 1.55
        VERY_ACTIVE -> 1.725
        EXTRA_ACTIVE -> 1.9
    }

    /** g protein per kg bodyweight per activity level (ISSN 2017 / Morton et al 2018 aligned). */
    val proteinPerKg: Double get() = when (this) {
        SEDENTARY -> 0.8
        LIGHT -> 1.2
        MODERATE -> 1.6
        ACTIVE -> 1.8
        VERY_ACTIVE -> 2.0
        EXTRA_ACTIVE -> 2.2
    }

    /** Full-bodyweight protein target in grams per kilogram. The published activity rates above
     *  are already bodyweight equivalents; body-fat data must not silently reinterpret them as
     *  lean-mass rates. */
    fun proteinRequirementPerKg(extra: Double = 0.0): Double = proteinPerKg + extra
}
