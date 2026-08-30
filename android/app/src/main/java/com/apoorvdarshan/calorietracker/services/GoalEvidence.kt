package com.apoorvdarshan.calorietracker.services

import com.apoorvdarshan.calorietracker.models.BodyFatEntry
import com.apoorvdarshan.calorietracker.models.BodyMeasurement
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.models.WeightEntry
import com.apoorvdarshan.calorietracker.models.WorkoutDate
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import kotlin.math.roundToInt

enum class NutritionDayCompleteness(val promptValue: String) {
    MISSING("missing"),
    LIKELY_PARTIAL("likely_partial"),
    LIKELY_COMPLETE("likely_complete")
}

data class DailyNutritionEvidence(
    val date: LocalDate,
    val calories: Int,
    val proteinGrams: Double,
    val carbsGrams: Double,
    val fatGrams: Double,
    val fiberGrams: Double?,
    val fiberLogCount: Int,
    val logCount: Int,
    val completeness: NutritionDayCompleteness
)

data class NutritionPeriodEvidence(
    val periodDays: Int,
    val calendarDays: Int,
    val loggedDays: Int,
    val likelyCompleteDays: Int,
    val logCount: Int,
    val averageLoggedCalories: Int?,
    val averageCompleteCalories: Int?,
    val averageLoggedProteinGrams: Double?,
    val averageLoggedCarbsGrams: Double?,
    val averageLoggedFatGrams: Double?,
    val averageKnownFiberGrams: Double?
) {
    val completeCoveragePercent: Int
        get() = if (calendarDays == 0) 0 else likelyCompleteDays * 100 / calendarDays
}

data class SignalPeriodEvidence(
    val periodDays: Int,
    val weightReadings: Int,
    val weightSpanDays: Long?,
    val weightChangeKg: Double?,
    val bodyFatReadings: Int,
    val workoutSessions: Int,
    val workoutMinutes: Int,
    val healthEnergyDays: Int,
    val averageExternalActiveCalories: Int?,
    val averageTotalCalories: Int?
)

data class DatedWeightEvidence(val date: LocalDate, val weightKg: Double)
data class DatedBodyFatEvidence(val date: LocalDate, val percent: Double)

/** Workout evidence deliberately has no calorie-burn field. Fud AI's workout calories are an
 *  estimate and feeding them back into the target calculator would create a circular signal. */
data class DailyWorkoutEvidence(
    val date: LocalDate,
    val sessions: Int,
    val durationMinutes: Int,
    val exerciseCount: Int,
    val performedSetCount: Int,
    val repCount: Int
)

data class DatedBodyMeasurementEvidence(
    val date: LocalDate,
    val measurement: BodyMeasurement
)

/** Active calories have already had this app's Health Connect data origin removed. */
data class DailyHealthEnergyEvidence(
    val date: LocalDate,
    val externalActiveCalories: Int,
    val totalCalories: Int?
)

data class GoalEvidence(
    val startDate: LocalDate,
    val endDate: LocalDate,
    val nutritionDays: List<DailyNutritionEvidence>,
    val nutritionPeriods: List<NutritionPeriodEvidence>,
    val signalPeriods: List<SignalPeriodEvidence>,
    val weights: List<DatedWeightEvidence>,
    val bodyFatReadings: List<DatedBodyFatEvidence>,
    val bodyMeasurements: List<DatedBodyMeasurementEvidence>,
    val workoutDays: List<DailyWorkoutEvidence>,
    val healthEnergyDays: List<DailyHealthEnergyEvidence>,
    val confidenceScore: Int,
    val confidenceLabel: String,
    val confidenceReasons: List<String>
) {
    /** A numeric-only, privacy-safe prompt section. Food names, notes, photos, ingredients and
     *  exercise names never enter this model, so they cannot accidentally reach a provider. */
    fun promptSection(profile: UserProfile): String = buildString {
        appendLine("GOAL EVIDENCE PACK — privacy-safe numeric daily aggregates for completed nutrition days $startDate through $endDate; point-in-time measurements and completed workouts may also include today")
        appendLine("- No food names, notes, photos, ingredients, meal descriptions, or exercise names are included.")
        appendLine("- Overall evidence confidence: $confidenceLabel ($confidenceScore/100). ${confidenceReasons.joinToString("; ")}")
        appendLine("- A likely_partial day may reflect incomplete logging; never treat it as true low intake. A missing day is not a zero-calorie day.")
        appendLine("- likely_complete is a heuristic: at least 85% of the current calorie target, or at least 2 logs and at least 65% (minimum 800 kcal).")

        appendLine("PERIOD SUMMARIES")
        nutritionPeriods.forEach { period ->
            append("- ${period.periodDays}d: logged ${period.loggedDays}/${period.calendarDays} days, ")
            append("likely-complete ${period.likelyCompleteDays}/${period.calendarDays} (${period.completeCoveragePercent}% coverage), ")
            append("${period.logCount} logs, avg_logged=${period.averageLoggedCalories ?: "n/a"} kcal")
            period.averageCompleteCalories?.let { append(", avg_complete=$it kcal") }
            period.averageLoggedProteinGrams?.let { append(", P=${oneDecimal(it)}g") }
            period.averageLoggedCarbsGrams?.let { append(", C=${oneDecimal(it)}g") }
            period.averageLoggedFatGrams?.let { append(", F=${oneDecimal(it)}g") }
            period.averageKnownFiberGrams?.let { append(", fiber=${oneDecimal(it)}g when recorded") }
            appendLine()
        }

        appendLine("OTHER SIGNAL PERIOD SUMMARIES")
        signalPeriods.forEach { period ->
            append("- ${period.periodDays}d: weigh-ins=${period.weightReadings}")
            period.weightSpanDays?.let { append(", weight span=$it days") }
            period.weightChangeKg?.let { append(", weight change=${String.format(Locale.US, "%+.2f", it)} kg") }
            append(", body-fat readings=${period.bodyFatReadings}, ")
            append("workouts=${period.workoutSessions} (${period.workoutMinutes} min), measured-energy days=${period.healthEnergyDays}")
            period.averageExternalActiveCalories?.let { append(", avg external active=$it kcal") }
            period.averageTotalCalories?.let { append(", avg corrected total=$it kcal") }
            appendLine()
        }

        appendLine("DAILY NUTRITION AGGREGATES (logged completed days only; omitted dates are missing/unlogged and have unknown intake, NOT zero intake)")
        val loggedNutrition = nutritionDays.filter { it.completeness != NutritionDayCompleteness.MISSING }
        val nutritionDetail = loggedNutrition.takeLast(45)
        if (loggedNutrition.size > nutritionDetail.size) {
            appendLine("- ${loggedNutrition.size - nutritionDetail.size} older logged-day rows omitted; the 90-day summaries above still include them.")
        }
        nutritionDetail.forEach { day ->
            append("- ${day.date}: ${day.calories} kcal, P=${oneDecimal(day.proteinGrams)}g, C=${oneDecimal(day.carbsGrams)}g, F=${oneDecimal(day.fatGrams)}g, ")
            append("fiber=${day.fiberGrams?.let(::oneDecimal)?.plus("g (known in ${day.fiberLogCount}/${day.logCount} logs)") ?: "unknown"}, logs=${day.logCount}, completeness=${day.completeness.promptValue}")
            appendLine()
        }

        appendLine("DATED WEIGHT HISTORY")
        if (weights.isEmpty()) appendLine("- none")
        else {
            val detail = weights.takeLast(30)
            if (weights.size > detail.size) appendLine("- ${weights.size - detail.size} older daily values omitted")
            detail.forEach { appendLine("- ${it.date}: ${oneDecimal(it.weightKg)} kg") }
        }

        appendLine("DATED BODY-FAT HISTORY")
        if (bodyFatReadings.isEmpty()) appendLine("- none")
        else {
            val detail = bodyFatReadings.takeLast(30)
            if (bodyFatReadings.size > detail.size) appendLine("- ${bodyFatReadings.size - detail.size} older daily values omitted")
            detail.forEach { appendLine("- ${it.date}: ${oneDecimal(it.percent)}%") }
        }

        appendLine("RECENT BODY-MEASUREMENT SNAPSHOTS (each row is a full carried-forward snapshot; do not sum rows)")
        if (bodyMeasurements.isEmpty()) appendLine("- none")
        else bodyMeasurements.forEach { item ->
            item.measurement.promptSummary(profile.gender, profile.heightCm)?.let {
                appendLine("- ${item.date}: $it")
            }
        }

        appendLine("WORKOUT ACTIVITY HISTORY (activity only; estimated burn calories deliberately excluded)")
        if (workoutDays.isEmpty()) appendLine("- none")
        else {
            val detail = workoutDays.takeLast(30)
            if (workoutDays.size > detail.size) {
                appendLine("- ${workoutDays.size - detail.size} older workout-day rows omitted; period summaries above still include them.")
            }
            detail.forEach {
                appendLine("- ${it.date}: sessions=${it.sessions}, duration=${it.durationMinutes} min, exercises=${it.exerciseCount}, sets=${it.performedSetCount}, reps=${it.repCount}")
            }
        }

        appendLine("HEALTH CONNECT DAILY ENERGY")
        if (healthEnergyDays.isEmpty()) {
            appendLine("- unavailable or Energy Burn disabled")
        } else {
            appendLine("- Active energy excludes Fud AI's app-owned estimated workout records; total energy is included only when Health Connect reports it.")
            healthEnergyDays.forEach {
                appendLine("- ${it.date}: external_active=${it.externalActiveCalories} kcal, total=${it.totalCalories?.let { value -> "$value kcal" } ?: "unavailable"}")
            }
        }
    }.trimEnd()

    private fun oneDecimal(value: Double): String = String.format(Locale.US, "%.1f", value)
}

object GoalEvidenceBuilder {
    const val MAX_LOOKBACK_DAYS = 90
    private val SUMMARY_PERIODS = listOf(7, 14, 28, 90)

    fun build(
        profile: UserProfile,
        foods: List<FoodEntry>,
        weights: List<WeightEntry>,
        bodyFatEntries: List<BodyFatEntry>,
        workouts: List<WorkoutSession>,
        measurements: List<BodyMeasurement>,
        healthEnergyDays: List<DailyHealthEnergyEvidence> = emptyList(),
        today: LocalDate = LocalDate.now(),
        zone: ZoneId = ZoneId.systemDefault()
    ): GoalEvidence {
        val endDate = today.minusDays(1)
        val startDate = endDate.minusDays((MAX_LOOKBACK_DAYS - 1).toLong())
        val foodsByDate = foods.asSequence()
            .map { it.timestamp.atZone(zone).toLocalDate() to it }
            .filter { (date, _) -> date in startDate..endDate }
            .groupBy({ it.first }, { it.second })

        val nutritionDays = (0 until MAX_LOOKBACK_DAYS).map { offset ->
            val date = startDate.plusDays(offset.toLong())
            val entries = foodsByDate[date].orEmpty()
            val calories = entries.sumOf { it.calories }
            val completeness = when {
                entries.isEmpty() -> NutritionDayCompleteness.MISSING
                isLikelyComplete(entries.size, calories, profile.effectiveCalories) -> NutritionDayCompleteness.LIKELY_COMPLETE
                else -> NutritionDayCompleteness.LIKELY_PARTIAL
            }
            val knownFiber = entries.mapNotNull { it.fiber }
            DailyNutritionEvidence(
                date = date,
                calories = calories,
                proteinGrams = entries.sumOf { it.protein },
                carbsGrams = entries.sumOf { it.carbs },
                fatGrams = entries.sumOf { it.fat },
                fiberGrams = knownFiber.takeIf { it.isNotEmpty() }?.sum(),
                fiberLogCount = knownFiber.size,
                logCount = entries.size,
                completeness = completeness
            )
        }

        val periodSummaries = SUMMARY_PERIODS.map { period ->
            summarizePeriod(nutritionDays.takeLast(period.coerceAtMost(nutritionDays.size)), period)
        }

        fun dateInMeasurementWindow(date: LocalDate) = date in startDate..today
        val weightEvidence = weights.sortedBy { it.date }.mapNotNull {
            val date = it.date.atZone(zone).toLocalDate()
            date.takeIf(::dateInMeasurementWindow)?.let { included -> DatedWeightEvidence(included, it.weightKg) }
        }.associateBy { it.date }.values.sortedBy { it.date }
        val bodyFatEvidence = bodyFatEntries.sortedBy { it.date }.mapNotNull {
            val date = it.date.atZone(zone).toLocalDate()
            date.takeIf(::dateInMeasurementWindow)?.let { included -> DatedBodyFatEvidence(included, it.bodyFatPercent) }
        }.associateBy { it.date }.values.sortedBy { it.date }
        val measurementEvidence = measurements.mapNotNull {
            val date = it.date.atZone(zone).toLocalDate()
            date.takeIf(::dateInMeasurementWindow)?.let { included -> DatedBodyMeasurementEvidence(included, it) }
        }.sortedBy { it.date }.takeLast(12)

        fun workoutDate(session: WorkoutSession): LocalDate =
            WorkoutDate.parse(session.diaryDateKey)
                ?: session.completedAt.atZone(zone).toLocalDate()
        val effectiveWorkouts = workouts
            .groupBy(::workoutDate)
            .values
            .flatMap { sessions ->
                val completed = sessions.filter { it.caloriesBurned == null }
                // A calculated-burn row is a whole-day sync snapshot, not another timed session.
                // Prefer the real completed sessions whenever they exist so duration and session
                // count stay truthful. The newest snapshot is only a fallback for days that have
                // no timer/manual completion row.
                if (completed.isNotEmpty()) return@flatMap completed
                val calculated = sessions.filter { it.caloriesBurned != null }
                if (calculated.isEmpty()) {
                    sessions
                } else {
                    listOf(
                        calculated.maxWithOrNull(
                            compareBy<WorkoutSession> { it.healthSyncVersion ?: 0 }
                                .thenBy { it.completedAt }
                        )!!
                    )
                }
            }
        val workoutEvidence = effectiveWorkouts.asSequence()
            // Health-restored burn-only shells contain no real activity detail and are excluded.
            .filter { it.durationSeconds > 0 || it.exercises.isNotEmpty() }
            .mapNotNull { session ->
                val date = workoutDate(session)
                date.takeIf(::dateInMeasurementWindow)?.let { it to session }
            }
            .groupBy({ it.first }, { it.second })
            .map { (date, sessions) ->
                DailyWorkoutEvidence(
                    date = date,
                    sessions = sessions.size,
                    durationMinutes = sessions.sumOf { it.durationMinutes },
                    exerciseCount = sessions.sumOf { it.exerciseCount },
                    performedSetCount = sessions.sumOf { it.performedSetCount },
                    repCount = sessions.sumOf { it.repCount }
                )
            }
            .sortedBy { it.date }

        val safeHealthEnergy = healthEnergyDays
            .filter { it.date in startDate..endDate }
            .distinctBy { it.date }
            .sortedBy { it.date }

        val signalPeriods = SUMMARY_PERIODS.map { period ->
            val periodStart = today.minusDays(period.toLong())
            val periodEnd = today.minusDays(1)
            // Summaries cover exactly N completed calendar days. Today's point-in-time
            // measurements/workouts remain in the dated detail sections.
            val periodWeights = weightEvidence.filter { it.date in periodStart..periodEnd }
            val periodBodyFat = bodyFatEvidence.filter { it.date in periodStart..periodEnd }
            val periodWorkouts = workoutEvidence.filter { it.date in periodStart..periodEnd }
            val periodEnergy = safeHealthEnergy.filter { it.date in periodStart..periodEnd }
            SignalPeriodEvidence(
                periodDays = period,
                weightReadings = periodWeights.size,
                weightSpanDays = periodWeights.takeIf { it.size >= 2 }
                    ?.let { java.time.temporal.ChronoUnit.DAYS.between(it.first().date, it.last().date) },
                weightChangeKg = periodWeights.takeIf { it.size >= 2 }
                    ?.let { it.last().weightKg - it.first().weightKg },
                bodyFatReadings = periodBodyFat.size,
                workoutSessions = periodWorkouts.sumOf { it.sessions },
                workoutMinutes = periodWorkouts.sumOf { it.durationMinutes },
                healthEnergyDays = periodEnergy.size,
                averageExternalActiveCalories = periodEnergy.takeIf { it.isNotEmpty() }
                    ?.map { it.externalActiveCalories }
                    ?.average()
                    ?.roundToInt(),
                averageTotalCalories = periodEnergy.mapNotNull { it.totalCalories }
                    .takeIf { it.size >= 3 }
                    ?.average()
                    ?.roundToInt()
            )
        }

        val confidence = confidence(periodSummaries, weightEvidence, safeHealthEnergy)
        return GoalEvidence(
            startDate = startDate,
            endDate = endDate,
            nutritionDays = nutritionDays,
            nutritionPeriods = periodSummaries,
            signalPeriods = signalPeriods,
            weights = weightEvidence,
            bodyFatReadings = bodyFatEvidence,
            bodyMeasurements = measurementEvidence,
            workoutDays = workoutEvidence,
            healthEnergyDays = safeHealthEnergy,
            confidenceScore = confidence.first,
            confidenceLabel = confidence.second,
            confidenceReasons = confidence.third
        )
    }

    private fun isLikelyComplete(logCount: Int, calories: Int, calorieGoal: Int): Boolean {
        val goal = calorieGoal.coerceAtLeast(800)
        return calories >= (goal * 0.85).roundToInt() ||
            (logCount >= 2 && calories >= maxOf(800, (goal * 0.65).roundToInt()))
    }

    private fun summarizePeriod(days: List<DailyNutritionEvidence>, requestedPeriod: Int): NutritionPeriodEvidence {
        val logged = days.filter { it.completeness != NutritionDayCompleteness.MISSING }
        val complete = logged.filter { it.completeness == NutritionDayCompleteness.LIKELY_COMPLETE }
        fun average(values: List<Double>): Double? = values.takeIf { it.isNotEmpty() }?.average()
        return NutritionPeriodEvidence(
            periodDays = requestedPeriod,
            calendarDays = days.size,
            loggedDays = logged.size,
            likelyCompleteDays = complete.size,
            logCount = logged.sumOf { it.logCount },
            averageLoggedCalories = logged.takeIf { it.isNotEmpty() }?.map { it.calories }?.average()?.roundToInt(),
            averageCompleteCalories = complete.takeIf { it.isNotEmpty() }?.map { it.calories }?.average()?.roundToInt(),
            averageLoggedProteinGrams = average(logged.map { it.proteinGrams }),
            averageLoggedCarbsGrams = average(logged.map { it.carbsGrams }),
            averageLoggedFatGrams = average(logged.map { it.fatGrams }),
            averageKnownFiberGrams = average(logged.mapNotNull { it.fiberGrams })
        )
    }

    private fun confidence(
        summaries: List<NutritionPeriodEvidence>,
        weights: List<DatedWeightEvidence>,
        energy: List<DailyHealthEnergyEvidence>
    ): Triple<Int, String, List<String>> {
        val recent = summaries.firstOrNull { it.periodDays == 28 } ?: summaries.last()
        val nutritionScore = (recent.likelyCompleteDays.toDouble() / recent.calendarDays.coerceAtLeast(1) * 55.0)
            .roundToInt().coerceIn(0, 55)
        val weightSpan = if (weights.size >= 2) {
            java.time.temporal.ChronoUnit.DAYS.between(weights.first().date, weights.last().date)
        } else 0
        val weightScore = when {
            weights.size >= 6 && weightSpan >= 28 -> 25
            weights.size >= 3 && weightSpan >= 14 -> 18
            weights.size >= 2 -> 10
            else -> 0
        }
        val energyScore = when {
            energy.size >= 10 -> 20
            energy.size >= 5 -> 12
            energy.size >= 3 -> 7
            else -> 0
        }
        val score = (nutritionScore + weightScore + energyScore).coerceIn(0, 100)
        val label = when {
            score >= 70 -> "high"
            score >= 40 -> "medium"
            else -> "low"
        }
        val reasons = listOf(
            "${recent.likelyCompleteDays}/${recent.calendarDays} likely-complete nutrition days in the recent 28-day window",
            "${weights.size} weigh-ins spanning $weightSpan days",
            "${energy.size} measured Health Connect energy days"
        )
        return Triple(score, label, reasons)
    }
}
