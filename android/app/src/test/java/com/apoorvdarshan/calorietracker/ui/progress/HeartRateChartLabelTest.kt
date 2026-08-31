package com.apoorvdarshan.calorietracker.ui.progress

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneOffset

class HeartRateChartLabelTest {
    @Test
    fun usesTimesForSameDayAndDatesAcrossDays() {
        val morning = Instant.parse("2026-08-31T08:00:00Z")

        assertTrue(
            shouldUseHeartRateTimeLabels(
                morning,
                Instant.parse("2026-08-31T18:00:00Z"),
                ZoneOffset.UTC
            )
        )
        assertFalse(
            shouldUseHeartRateTimeLabels(
                morning,
                Instant.parse("2026-09-01T08:00:00Z"),
                ZoneOffset.UTC
            )
        )
    }
}
