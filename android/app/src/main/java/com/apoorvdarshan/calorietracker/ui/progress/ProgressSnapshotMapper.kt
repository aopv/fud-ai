package com.apoorvdarshan.calorietracker.ui.progress

import com.apoorvdarshan.calorietracker.models.FoodEntry
import java.time.LocalDate
import java.time.ZoneId

private data class ProgressRangeSpec(val channelValue: String, val days: Int)

private fun rangeSpec(channelValue: String): ProgressRangeSpec = when (channelValue) {
    "month" -> ProgressRangeSpec("month", 30)
    "threeMonths" -> ProgressRangeSpec("threeMonths", 90)
    "sixMonths" -> ProgressRangeSpec("sixMonths", 180)
    "year" -> ProgressRangeSpec("year", 365)
    "allTime" -> ProgressRangeSpec("allTime", 3650)
    else -> ProgressRangeSpec("week", 7)
}

/** Converts native repository state into StandardMessageCodec-safe primitives. */
internal fun buildProgressSnapshot(
    rangeName: String,
    ui: ProgressUiState,
    foods: List<FoodEntry>,
    weightUnit: String,
    isDark: Boolean,
    strings: Map<String, String>,
    today: LocalDate = LocalDate.now(),
    zone: ZoneId = ZoneId.systemDefault(),
    bottomContentInset: Double = 132.0,
    safeAreaTop: Boolean = false
): Map<String, Any?> {
    val range = rangeSpec(rangeName)
    val startDate = today.minusDays((range.days - 1).toLong())
    val rangeStart = startDate.atStartOfDay(zone).toInstant()
    val rangeEnd = today.plusDays(1).atStartOfDay(zone).toInstant()
    val usesMetric = weightUnit == "kg"
    fun displayWeight(weightKg: Double): Double =
        if (usesMetric) weightKg else weightKg * 2.20462

    val foodsByDay = foods.groupBy { entry ->
        entry.timestamp.atZone(zone).toLocalDate()
    }
    val dailyCalories = (0 until range.days).mapNotNull { offset ->
        val day = today.minusDays(offset.toLong())
        val entries = foodsByDay[day].orEmpty()
        val calories = entries.sumOf(FoodEntry::calories)
        if (calories <= 0) null else mapOf(
            "timestampMs" to day.atStartOfDay(zone).toInstant().toEpochMilli(),
            "calories" to calories
        )
    }.reversed()

    var totalProtein = 0.0
    var totalCarbs = 0.0
    var totalFat = 0.0
    var loggedDayCount = 0
    repeat(range.days) { offset ->
        val day = today.minusDays(offset.toLong())
        val entries = foodsByDay[day].orEmpty()
        if (entries.isEmpty()) return@repeat
        totalProtein += entries.sumOf(FoodEntry::protein)
        totalCarbs += entries.sumOf(FoodEntry::carbs)
        totalFat += entries.sumOf(FoodEntry::fat)
        loggedDayCount += 1
    }
    val divisor = loggedDayCount.coerceAtLeast(1).toDouble()

    val filteredWeights = ui.entries
        .asSequence()
        .filter { it.date >= rangeStart && it.date < rangeEnd }
        .sortedBy { it.date }
        .map { entry ->
            mapOf(
                "timestampMs" to entry.date.toEpochMilli(),
                "value" to displayWeight(entry.weightKg)
            )
        }
        .toList()
    val filteredBodyFat = ui.bodyFatEntries
        .asSequence()
        .filter { it.date >= rangeStart && it.date < rangeEnd }
        .sortedBy { it.date }
        .map { entry ->
            mapOf(
                "timestampMs" to entry.date.toEpochMilli(),
                "value" to entry.bodyFatPercent
            )
        }
        .toList()

    val profile = ui.profile
    val snapshot = linkedMapOf<String, Any?>(
        "range" to range.channelValue,
        "weightUnit" to if (usesMetric) "kg" else "lbs",
        "weightEntries" to filteredWeights,
        "bodyFatEntries" to filteredBodyFat,
        "dailyCalories" to dailyCalories,
        "showsBodyFat" to (
            ui.bodyFatEntries.isNotEmpty() ||
                profile?.bodyFatPercentage != null ||
                profile?.goalBodyFatPercentage != null
            ),
        "weightHistoryCount" to ui.entries.size,
        "bodyFatHistoryCount" to ui.bodyFatEntries.size,
        "workoutHistoryCount" to ui.workoutBurnSessions.size,
        "calorieGoal" to (profile?.effectiveCalories ?: 2000),
        "averageProtein" to if (loggedDayCount == 0) 0.0 else totalProtein / divisor,
        "averageCarbs" to if (loggedDayCount == 0) 0.0 else totalCarbs / divisor,
        "averageFat" to if (loggedDayCount == 0) 0.0 else totalFat / divisor,
        "proteinGoal" to (profile?.effectiveProtein ?: 150),
        "carbsGoal" to (profile?.effectiveCarbs ?: 220),
        "fatGoal" to (profile?.effectiveFat ?: 70),
        "strings" to strings,
        "isDark" to isDark,
        "safeAreaTop" to safeAreaTop,
        "bottomContentInset" to bottomContentInset
    )

    ui.entries.maxByOrNull { it.date }?.let { entry ->
        snapshot["currentWeight"] = displayWeight(entry.weightKg)
    }
    profile?.goalWeightKg?.let { goal ->
        snapshot["goalWeight"] = displayWeight(goal)
    }
    (ui.bodyFatEntries.maxByOrNull { it.date }?.bodyFatFraction
        ?: profile?.bodyFatPercentage)?.let { current ->
        snapshot["currentBodyFat"] = current * 100
    }
    profile?.goalBodyFatPercentage?.let { goal ->
        snapshot["goalBodyFat"] = goal * 100
    }
    return snapshot
}
