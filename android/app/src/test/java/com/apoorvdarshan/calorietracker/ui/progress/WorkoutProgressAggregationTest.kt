package com.apoorvdarshan.calorietracker.ui.progress

import com.apoorvdarshan.calorietracker.models.WorkoutSession
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

class WorkoutProgressAggregationTest {
    @Test
    fun duplicateDayUsesHigherVersionThenLaterCompletionWithoutSumming() {
        val olderVersion = burn(
            date = "2026-08-30",
            calories = 300,
            version = 1,
            completedAt = "2026-08-30T12:00:00Z"
        )
        val newerVersion = burn(
            date = "2026-08-30",
            calories = 450,
            version = 2,
            completedAt = "2026-08-30T10:00:00Z"
        )
        val laterNewerVersion = burn(
            date = "2026-08-30",
            calories = 475,
            version = 2,
            completedAt = "2026-08-30T11:00:00Z"
        )
        val otherDay = burn(
            date = "2026-08-31",
            calories = 520,
            version = null,
            completedAt = "2026-08-31T11:00:00Z"
        )

        assertEquals(
            listOf(
                LocalDate.parse("2026-08-30") to 475,
                LocalDate.parse("2026-08-31") to 520
            ),
            preferredDailyWorkoutBurns(
                listOf(olderVersion, newerVersion, laterNewerVersion, otherDay)
            )
        )
    }

    @Test
    fun malformedOrImplausibleBurnsAreExcluded() {
        assertEquals(
            emptyList<Pair<LocalDate, Int>>(),
            preferredDailyWorkoutBurns(
                listOf(
                    burn("not-a-date", 400, 1, "2026-08-30T10:00:00Z"),
                    burn("2026-08-30", 0, 1, "2026-08-30T10:00:00Z"),
                    burn("2026-08-31", 5_001, 1, "2026-08-31T10:00:00Z")
                )
            )
        )
    }

    private fun burn(
        date: String,
        calories: Int,
        version: Int?,
        completedAt: String
    ): WorkoutSession {
        val completed = Instant.parse(completedAt)
        return WorkoutSession(
            diaryDateKey = date,
            startedAt = completed.minusSeconds(1_800),
            completedAt = completed,
            exercises = emptyList(),
            caloriesBurned = calories,
            healthSyncVersion = version
        )
    }
}
