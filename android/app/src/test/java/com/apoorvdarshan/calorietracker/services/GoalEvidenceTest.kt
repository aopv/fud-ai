package com.apoorvdarshan.calorietracker.services

import com.apoorvdarshan.calorietracker.models.BodyFatEntry
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.MealIngredient
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.models.WeightEntry
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import java.time.LocalDate
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalEvidenceTest {
    private val today = LocalDate.of(2026, 8, 31)

    @Test
    fun buildsNinetyCompletedCalendarDaysWithMissingAndPartialSignals() {
        val yesterday = today.minusDays(1)
        val completeDay = today.minusDays(2)
        val foods = listOf(
            food(yesterday, 400, "private yesterday"),
            food(completeDay, 1_000, "private breakfast"),
            food(completeDay, 900, "private dinner"),
            food(today, 700, "in-progress today"),
            food(today.minusDays(91), 900, "too old")
        )

        val evidence = GoalEvidenceBuilder.build(
            profile = UserProfile(customCalories = 2_000),
            foods = foods,
            weights = emptyList(),
            bodyFatEntries = emptyList(),
            workouts = emptyList(),
            measurements = emptyList(),
            today = today,
            zone = ZoneOffset.UTC
        )

        assertEquals(90, evidence.nutritionDays.size)
        assertEquals(today.minusDays(90), evidence.startDate)
        assertEquals(yesterday, evidence.endDate)
        assertFalse(evidence.nutritionDays.any { it.date == today })
        assertEquals(NutritionDayCompleteness.LIKELY_PARTIAL, evidence.nutritionDays.last().completeness)
        assertEquals(NutritionDayCompleteness.LIKELY_COMPLETE, evidence.nutritionDays[evidence.nutritionDays.lastIndex - 1].completeness)
        assertTrue(evidence.nutritionDays.any { it.completeness == NutritionDayCompleteness.MISSING })

        val week = evidence.nutritionPeriods.single { it.periodDays == 7 }
        assertEquals(2, week.loggedDays)
        assertEquals(1, week.likelyCompleteDays)
        assertEquals(3, week.logCount)
    }

    @Test
    fun promptContainsOnlyAggregateEvidenceAndExcludesPrivateFoodAndWorkoutContent() {
        val yesterday = today.minusDays(1)
        val privateFoodName = "SECRET FOOD NAME"
        val privateNote = "SECRET NOTE"
        val privateIngredient = "SECRET INGREDIENT"
        val foods = listOf(
            food(yesterday, 1_900, privateFoodName).copy(
                customNote = privateNote,
                imageFilename = "secret-photo.jpg",
                ingredients = listOf(MealIngredient(privateIngredient, 100.0, 100, 1.0, 2.0, 3.0))
            )
        )
        val workout = WorkoutSession(
            diaryDateKey = yesterday.toString(),
            startedAt = instant(yesterday),
            completedAt = instant(yesterday).plusSeconds(1_800),
            durationSeconds = 1_800,
            exercises = emptyList(),
            caloriesBurned = 999
        )
        val evidence = GoalEvidenceBuilder.build(
            profile = UserProfile(customCalories = 2_000),
            foods = foods,
            weights = listOf(WeightEntry(date = instant(yesterday), weightKg = 71.2)),
            bodyFatEntries = listOf(BodyFatEntry(date = instant(yesterday), bodyFatFraction = 0.18)),
            workouts = listOf(workout),
            measurements = emptyList(),
            healthEnergyDays = listOf(DailyHealthEnergyEvidence(yesterday, 420, 2_120)),
            today = today,
            zone = ZoneOffset.UTC
        )

        val prompt = evidence.promptSection(UserProfile())
        assertFalse(prompt.contains(privateFoodName))
        assertFalse(prompt.contains(privateNote))
        assertFalse(prompt.contains(privateIngredient))
        assertFalse(prompt.contains("secret-photo.jpg"))
        assertFalse(prompt.contains("999"))
        assertTrue(prompt.contains("2026-08-30: 1900 kcal"))
        assertTrue(prompt.contains("external_active=420 kcal, total=2120 kcal"))
        assertTrue(prompt.contains("estimated burn calories deliberately excluded"))
    }

    @Test
    fun genuineTimerRowsTakePrecedenceAndTodayIsIncluded() {
        val timerRow = WorkoutSession(
            diaryDateKey = today.toString(),
            startedAt = instant(today),
            completedAt = instant(today).plusSeconds(600),
            durationSeconds = 600,
            exercises = emptyList()
        )
        val calculatedSnapshot = timerRow.copy(
            completedAt = instant(today).plusSeconds(1_800),
            durationSeconds = 0,
            caloriesBurned = 500,
            healthSyncVersion = 2
        )

        val evidence = GoalEvidenceBuilder.build(
            profile = UserProfile(),
            foods = emptyList(),
            weights = emptyList(),
            bodyFatEntries = emptyList(),
            workouts = listOf(timerRow, calculatedSnapshot),
            measurements = emptyList(),
            today = today,
            zone = ZoneOffset.UTC
        )

        assertEquals(1, evidence.workoutDays.size)
        assertEquals(today, evidence.workoutDays.single().date)
        assertEquals(1, evidence.workoutDays.single().sessions)
        assertEquals(10, evidence.workoutDays.single().durationMinutes)
    }

    @Test
    fun totalEnergySignalNeedsThreeTotalDays() {
        val evidence = GoalEvidenceBuilder.build(
            profile = UserProfile(),
            foods = emptyList(),
            weights = emptyList(),
            bodyFatEntries = emptyList(),
            workouts = emptyList(),
            measurements = emptyList(),
            healthEnergyDays = listOf(
                DailyHealthEnergyEvidence(today.minusDays(1), 410, 2_010),
                DailyHealthEnergyEvidence(today.minusDays(2), 420, null),
                DailyHealthEnergyEvidence(today.minusDays(3), 430, null)
            ),
            today = today,
            zone = ZoneOffset.UTC
        )

        val week = evidence.signalPeriods.single { it.periodDays == 7 }
        assertEquals(3, week.healthEnergyDays)
        assertEquals(420, week.averageExternalActiveCalories)
        assertEquals(null, week.averageTotalCalories)
    }

    private fun food(date: LocalDate, calories: Int, name: String) = FoodEntry(
        name = name,
        calories = calories,
        protein = calories / 20.0,
        carbs = calories / 10.0,
        fat = calories / 50.0,
        fiber = 8.0,
        timestamp = instant(date),
        source = FoodSource.MANUAL
    )

    private fun instant(date: LocalDate) = date.atStartOfDay(ZoneOffset.UTC).plusHours(12).toInstant()
}
