package com.apoorvdarshan.calorietracker.ui.progress

import com.apoorvdarshan.calorietracker.models.BodyFatEntry
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.models.WeightEntry
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class ProgressSnapshotMapperTest {
    private val zone = ZoneId.of("UTC")
    private val today = LocalDate.of(2026, 8, 24)

    @Test
    fun weekSnapshotFiltersTrendsAndAveragesOnlyLoggedDays() {
        val ui = ProgressUiState(
            entries = listOf(
                WeightEntry(date = Instant.parse("2026-08-17T12:00:00Z"), weightKg = 80.0),
                WeightEntry(date = Instant.parse("2026-08-18T12:00:00Z"), weightKg = 79.0),
                WeightEntry(date = Instant.parse("2026-08-24T12:00:00Z"), weightKg = 78.0)
            ),
            bodyFatEntries = listOf(
                BodyFatEntry(
                    date = Instant.parse("2026-08-24T12:00:00Z"),
                    bodyFatFraction = 0.19
                )
            ),
            workoutBurnSessions = listOf(
                WorkoutSession(
                    diaryDateKey = "2026-08-24",
                    startedAt = Instant.parse("2026-08-24T10:00:00Z"),
                    completedAt = Instant.parse("2026-08-24T11:00:00Z"),
                    exercises = emptyList(),
                    caloriesBurned = 320
                )
            ),
            profile = UserProfile(
                goalWeightKg = 70.0,
                bodyFatPercentage = 0.20,
                goalBodyFatPercentage = 0.15,
                customCalories = 2_200,
                customProtein = 160,
                customCarbs = 240,
                customFat = 70
            )
        )
        val foods = listOf(
            food("2026-08-23T08:00:00Z", calories = 500, protein = 30.0, carbs = 50.0, fat = 20.0),
            food("2026-08-23T18:00:00Z", calories = 700, protein = 50.0, carbs = 70.0, fat = 30.0),
            food("2026-08-24T08:00:00Z", calories = 600, protein = 40.0, carbs = 80.0, fat = 10.0),
            food("2026-08-16T08:00:00Z", calories = 900, protein = 90.0, carbs = 90.0, fat = 90.0)
        )

        val snapshot = buildProgressSnapshot(
            rangeName = "week",
            ui = ui,
            foods = foods,
            weightUnit = "lbs",
            isDark = true,
            strings = mapOf("title" to "PROGRESS"),
            today = today,
            zone = zone
        )

        assertEquals("week", snapshot["range"])
        assertEquals("lbs", snapshot["weightUnit"])
        assertEquals(2, list(snapshot, "weightEntries").size)
        assertEquals(1, list(snapshot, "bodyFatEntries").size)
        assertEquals(2, list(snapshot, "dailyCalories").size)
        assertEquals(3, snapshot["weightHistoryCount"])
        assertEquals(1, snapshot["workoutHistoryCount"])
        assertEquals(2_200, snapshot["calorieGoal"])
        assertEquals(60.0, snapshot["averageProtein"] as Double, 0.0001)
        assertEquals(100.0, snapshot["averageCarbs"] as Double, 0.0001)
        assertEquals(30.0, snapshot["averageFat"] as Double, 0.0001)
        assertEquals(78.0 * 2.20462, snapshot["currentWeight"] as Double, 0.0001)
        assertEquals(70.0 * 2.20462, snapshot["goalWeight"] as Double, 0.0001)
        assertEquals(19.0, snapshot["currentBodyFat"] as Double, 0.0001)
        assertEquals(15.0, snapshot["goalBodyFat"] as Double, 0.0001)
        assertTrue(snapshot["showsBodyFat"] as Boolean)
        assertTrue(snapshot["isDark"] as Boolean)
        assertFalse(snapshot["safeAreaTop"] as Boolean)
        assertEquals(132.0, snapshot["bottomContentInset"] as Double, 0.0)
    }

    @Test
    fun unknownRangeAndMissingProfileUseSafeDefaults() {
        val snapshot = buildProgressSnapshot(
            rangeName = "unexpected",
            ui = ProgressUiState(),
            foods = emptyList(),
            weightUnit = "kg",
            isDark = false,
            strings = emptyMap(),
            today = today,
            zone = zone
        )

        assertEquals("week", snapshot["range"])
        assertEquals("kg", snapshot["weightUnit"])
        assertEquals(2_000, snapshot["calorieGoal"])
        assertEquals(150, snapshot["proteinGoal"])
        assertEquals(220, snapshot["carbsGoal"])
        assertEquals(70, snapshot["fatGoal"])
        assertFalse(snapshot.containsKey("currentWeight"))
        assertFalse(snapshot["showsBodyFat"] as Boolean)
    }

    private fun food(
        timestamp: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double
    ) = FoodEntry(
        name = "Test food",
        calories = calories,
        protein = protein,
        carbs = carbs,
        fat = fat,
        timestamp = Instant.parse(timestamp),
        source = FoodSource.MANUAL
    )

    @Suppress("UNCHECKED_CAST")
    private fun list(snapshot: Map<String, Any?>, key: String): List<Map<String, Any>> =
        snapshot[key] as List<Map<String, Any>>
}
