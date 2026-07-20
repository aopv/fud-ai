package com.apoorvdarshan.calorietracker.models

import java.text.NumberFormat
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

enum class WaterUnit(val storageValue: String, val symbol: String) {
    MILLILITERS("ml", "ml"),
    FLUID_OUNCES("floz", "fl oz");

    fun displayValue(milliliters: Int): String {
        if (this == MILLILITERS) return NumberFormat.getIntegerInstance().format(milliliters)
        val ounces = milliliters / MILLILITERS_PER_FLUID_OUNCE
        return if (abs(ounces - ounces.roundToInt()) < 0.05) {
            NumberFormat.getIntegerInstance().format(ounces.roundToInt())
        } else {
            String.format(Locale.getDefault(), "%.1f", ounces)
        }
    }

    fun format(milliliters: Int): String = "${displayValue(milliliters)} $symbol"

    fun toMilliliters(displayValue: Double): Int {
        val converted = if (this == MILLILITERS) displayValue else displayValue * MILLILITERS_PER_FLUID_OUNCE
        return converted.roundToInt().coerceAtLeast(1)
    }

    companion object {
        const val MILLILITERS_PER_FLUID_OUNCE = 29.5735295625
        val Default = MILLILITERS
        fun fromStorage(value: String?): WaterUnit = entries.firstOrNull { it.storageValue == value } ?: Default
    }
}
