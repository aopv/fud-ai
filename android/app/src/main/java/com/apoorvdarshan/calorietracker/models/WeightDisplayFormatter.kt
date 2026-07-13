package com.apoorvdarshan.calorietracker.models

import java.util.Locale

object WeightDisplayFormatter {
    private const val POUNDS_PER_KILOGRAM = 2.20462

    fun weeklyChangeValue(kilograms: Double, useMetric: Boolean): String {
        val value = if (useMetric) kilograms else kilograms * POUNDS_PER_KILOGRAM
        return String.format(Locale.US, "%.2f", value).trimEnd('0').trimEnd('.')
    }

    fun weeklyChange(kilograms: Double, useMetric: Boolean, period: String = "wk"): String {
        val unit = if (useMetric) "kg" else "lbs"
        return "${weeklyChangeValue(kilograms, useMetric)} $unit/$period"
    }
}
