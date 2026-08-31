package com.apoorvdarshan.calorietracker.services.challenge

import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.WaterEntry
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeAggregate
import com.apoorvdarshan.calorietracker.models.WeeklyChallengeWeek
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

data class WeeklyChallengeAggregationInput(
    val foods: List<FoodEntry>,
    val water: List<WaterEntry>,
    val workoutBurns: List<WorkoutSession>,
    val calorieGoal: Int,
    val waterTrackingEnabled: Boolean,
    val waterGoalMl: Int,
    val weekStart: LocalDate,
    val today: LocalDate,
    val zoneId: ZoneId
)

/** Pure, deterministic conversion from local diary data to the public aggregate contract. */
object WeeklyChallengeAggregator {
    private const val DAILY_ACTIVITY_KCAL_CAP = 2_000

    fun aggregate(input: WeeklyChallengeAggregationInput): WeeklyChallengeAggregate {
        val weekEnd = WeeklyChallengeWeek.endFor(input.weekStart)
        val effectiveEnd = minOf(weekEnd, input.today)
        if (effectiveEnd.isBefore(input.weekStart)) return WeeklyChallengeAggregate.empty(input.weekStart)
        val dayCount = ChronoUnit.DAYS.between(input.weekStart, effectiveEnd).toInt()
        val validDates = (0..dayCount).map { input.weekStart.plusDays(it.toLong()) }.toSet()

        val foodsByDay = input.foods.groupBy {
            it.timestamp.atZone(input.zoneId).toLocalDate()
        }.filterKeys { it in validDates }
        val consistencyDays = foodsByDay.keys.size.coerceIn(0, 7)
        val nutritionDays = if (input.calorieGoal > 0) {
            val lower = input.calorieGoal * 0.85
            val upper = input.calorieGoal * 1.15
            foodsByDay.values.count { entries ->
                entries.sumOf { it.calories.toLong() }.toDouble() in lower..upper
            }.coerceIn(0, 7)
        } else {
            0
        }

        val hydrationDays = if (input.waterTrackingEnabled && input.waterGoalMl > 0) {
            input.water
                .groupBy { it.date.atZone(input.zoneId).toLocalDate() }
                .filterKeys { it in validDates }
                .count { (_, entries) ->
                    entries.sumOf { it.milliliters.toLong() } >= input.waterGoalMl.toLong()
                }
                .coerceIn(0, 7)
        } else {
            0
        }

        val burnByDay = input.workoutBurns
            .mapNotNull { session ->
                val date = runCatching { LocalDate.parse(session.diaryDateKey) }.getOrNull()
                    ?: return@mapNotNull null
                val calories = session.caloriesBurned?.takeIf { it > 0 } ?: return@mapNotNull null
                if (date !in validDates) null else date to calories
            }
            .groupBy({ it.first }, { it.second })
        val activityDays = burnByDay.keys.size.coerceIn(0, 7)
        val activityKcal = burnByDay.values.sumOf { dayCalories ->
            dayCalories.sumOf { it.toLong() }
                .coerceAtMost(DAILY_ACTIVITY_KCAL_CAP.toLong())
        }.coerceIn(0, 14_000)

        val overall = (activityDays + nutritionDays + consistencyDays + hydrationDays).coerceIn(0, 28)
        return WeeklyChallengeAggregate(
            weekStart = input.weekStart.toString(),
            overallPoints = overall,
            activityDays = activityDays,
            nutritionDays = nutritionDays,
            consistencyDays = consistencyDays,
            hydrationDays = hydrationDays,
            activityKcal = activityKcal.toInt()
        )
    }
}
