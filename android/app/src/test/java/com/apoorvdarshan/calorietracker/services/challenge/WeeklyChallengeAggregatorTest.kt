package com.apoorvdarshan.calorietracker.services.challenge

import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.WaterEntry
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Test

class WeeklyChallengeAggregatorTest {
    private val utc: ZoneId = ZoneOffset.UTC
    private val monday = LocalDate.of(2026, 8, 24)

    @Test
    fun aggregatesOnlyQualifyingElapsedDaysAndCapsDailyActivity() {
        val result = WeeklyChallengeAggregator.aggregate(
            WeeklyChallengeAggregationInput(
                foods = listOf(
                    food(monday, 2_000),
                    food(monday.plusDays(1), 1_000),
                    food(monday.plusDays(3), 2_000)
                ),
                water = listOf(
                    water(monday, 2_000),
                    water(monday.plusDays(1), 1_000),
                    water(monday.plusDays(3), 2_000)
                ),
                workoutBurns = listOf(
                    workout(monday, 1_500),
                    workout(monday, 1_000),
                    workout(monday.plusDays(1), 500),
                    workout(monday.plusDays(1), 0),
                    workout(monday.plusDays(3), 900)
                ),
                calorieGoal = 2_000,
                waterTrackingEnabled = true,
                waterGoalMl = 2_000,
                weekStart = monday,
                today = monday.plusDays(2),
                zoneId = utc
            )
        )

        assertEquals("2026-08-24", result.weekStart)
        assertEquals(2, result.activityDays)
        assertEquals(1, result.nutritionDays)
        assertEquals(2, result.consistencyDays)
        assertEquals(1, result.hydrationDays)
        assertEquals(2_500, result.activityKcal)
        assertEquals(6, result.overallPoints)
    }

    @Test
    fun appliesWeeklyMaximumAndDisablesHydrationWhenTrackingIsOff() {
        val allWeek = (0L..6L).toList()
        val result = WeeklyChallengeAggregator.aggregate(
            WeeklyChallengeAggregationInput(
                foods = allWeek.map { food(monday.plusDays(it), 1_700) },
                water = allWeek.map { water(monday.plusDays(it), 3_000) },
                workoutBurns = allWeek.map { workout(monday.plusDays(it), 3_000) },
                calorieGoal = 2_000,
                waterTrackingEnabled = false,
                waterGoalMl = 2_000,
                weekStart = monday,
                today = monday.plusDays(6),
                zoneId = utc
            )
        )

        assertEquals(7, result.activityDays)
        assertEquals(7, result.nutritionDays)
        assertEquals(7, result.consistencyDays)
        assertEquals(0, result.hydrationDays)
        assertEquals(14_000, result.activityKcal)
        assertEquals(21, result.overallPoints)
    }

    private fun food(date: LocalDate, calories: Int) = FoodEntry(
        name = "private food name",
        calories = calories,
        protein = 0.0,
        carbs = 0.0,
        fat = 0.0,
        timestamp = instant(date),
        source = FoodSource.MANUAL
    )

    private fun water(date: LocalDate, milliliters: Int) = WaterEntry(
        date = instant(date),
        milliliters = milliliters
    )

    private fun workout(date: LocalDate, calories: Int) = WorkoutSession(
        diaryDateKey = date.toString(),
        startedAt = instant(date),
        completedAt = instant(date).plusSeconds(1_800),
        exercises = emptyList(),
        caloriesBurned = calories
    )

    private fun instant(date: LocalDate): Instant =
        date.atTime(12, 0).toInstant(ZoneOffset.UTC)
}
