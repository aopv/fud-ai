package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.Serializable
import java.text.DecimalFormatSymbols
import java.util.Locale

@Serializable
data class ServingUnitOption(
    val unit: String,
    val gramsPerUnit: Double,
    val quantity: Double? = null
) {
    val id: String get() = normalizedUnit

    val normalizedUnit: String
        get() = unit.trim().lowercase(Locale.US)

    val isGramUnit: Boolean
        get() = normalizedUnit in setOf("g", "gram", "grams")

    val isValid: Boolean
        get() = normalizedUnit.isNotEmpty() && gramsPerUnit > 0

    fun quantityFor(totalGrams: Double): Double {
        quantity?.takeIf { it > 0 }?.let { return it }
        return if (gramsPerUnit > 0) totalGrams / gramsPerUnit else totalGrams
    }

    fun displayUnit(quantity: Double?): String {
        if (quantity == null || kotlin.math.abs(quantity - 1.0) <= 0.0001) return unit
        return when (normalizedUnit) {
            "g", "gram", "grams", "kg", "mg", "ml", "l", "oz", "fl oz", "tbsp", "tsp" -> unit
            "piece" -> "pieces"
            else -> if (unit.endsWith("s")) unit else "${unit}s"
        }
    }

    companion object {
        val grams = ServingUnitOption(unit = "g", gramsPerUnit = 1.0)

        /**
         * Internal unit for a system-health restore whose nutrition totals are
         * known but whose original food mass is not. Its numeric basis is a
         * serving count, never a gram measurement.
         */
        fun loggedServing(quantity: Double = 1.0) =
            ServingUnitOption(unit = "serving", gramsPerUnit = 1.0, quantity = quantity)

        fun normalizedOptions(options: List<ServingUnitOption>, totalGrams: Double): List<ServingUnitOption> {
            val seen = mutableSetOf<String>()
            val normalized = mutableListOf<ServingUnitOption>()
            for (raw in options) {
                val option = if (raw.quantity == null && raw.gramsPerUnit > 0) {
                    raw.copy(quantity = totalGrams / raw.gramsPerUnit)
                } else {
                    raw
                }
                if (!option.isValid || option.isGramUnit || option.id in seen) continue
                seen.add(option.id)
                normalized.add(option)
            }
            return normalized.take(4)
        }

        fun pickerOptions(options: List<ServingUnitOption>): List<ServingUnitOption> {
            val seen = mutableSetOf(grams.id)
            val nonGram = options.filter { option ->
                option.isValid && !option.isGramUnit && seen.add(option.id)
            }
            return listOf(grams) + nonGram
        }

        fun optionMatching(id: String, options: List<ServingUnitOption>): ServingUnitOption =
            pickerOptions(options).firstOrNull { it.id == id } ?: grams

        fun initialUnitId(
            preferredUnit: String?,
            options: List<ServingUnitOption>
        ): String {
            val pickerOptions = pickerOptions(options)
            val preferredId = preferredUnit?.trim()?.lowercase(Locale.US)
            if (preferredId != null && pickerOptions.any { it.id == preferredId }) return preferredId
            return options.firstOrNull()?.id ?: grams.id
        }

        fun initialQuantityText(
            totalGrams: Double,
            selectedUnitId: String,
            selectedQuantity: Double?,
            options: List<ServingUnitOption>
        ): String {
            val option = optionMatching(selectedUnitId, options)
            if (selectedQuantity != null && selectedQuantity > 0 && !option.isGramUnit) {
                return formatQuantity(selectedQuantity)
            }
            val quantity = if (option.gramsPerUnit > 0) totalGrams / option.gramsPerUnit else totalGrams
            return formatQuantity(quantity)
        }

        fun formatQuantity(value: Double): String {
            if (value == value.toInt().toDouble()) return value.toInt().toString()
            val formatted = if (kotlin.math.abs(value) < 10) {
                String.format(Locale.US, "%.2f", value)
            } else {
                String.format(Locale.US, "%.1f", value)
            }
            return formatted.trimEnd('0').trimEnd('.')
        }

        fun parseQuantity(value: String, locale: Locale = Locale.getDefault()): Double? {
            val trimmed = value.trim()
            if (trimmed.isEmpty()) return null
            trimmed.toDoubleOrNull()?.let { return it }

            if (trimmed.contains(',') && !trimmed.contains('.')) {
                trimmed.replace(',', '.').toDoubleOrNull()?.let { return it }
            }

            val symbols = DecimalFormatSymbols.getInstance(locale)
            val decimal = symbols.decimalSeparator
            if (decimal == '.' || !trimmed.contains(decimal)) return null

            var normalized = trimmed
            val grouping = symbols.groupingSeparator
            if (grouping != decimal) {
                normalized = normalized.replace(grouping.toString(), "")
            }
            normalized = normalized.replace(decimal, '.')
            return normalized.toDoubleOrNull()
        }
    }
}
