package com.apoorvdarshan.calorietracker.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class FastingSessionTest {
    @Test
    fun activeSessionUsesSavedStartAndGoal() {
        val start = Instant.parse("2026-08-07T10:00:00Z")
        val session = FastingSession(startedAt = start, goalMinutes = 16 * 60)

        assertTrue(session.isActive)
        assertEquals(Instant.parse("2026-08-08T02:00:00Z"), session.goalAt)
        assertEquals(17 * 60 * 60L, session.durationSeconds(Instant.parse("2026-08-08T03:00:00Z")))
    }

    @Test
    fun completedSessionAndFormatterAreIndependentOfNutrition() {
        val start = Instant.parse("2026-08-07T10:00:00Z")
        val session = FastingSession(
            startedAt = start,
            endedAt = Instant.parse("2026-08-08T02:30:00Z"),
            goalMinutes = 16 * 60
        )

        assertFalse(session.isActive)
        assertEquals("16h 30m", formatFastingDuration(session.durationSeconds()))
    }
}
