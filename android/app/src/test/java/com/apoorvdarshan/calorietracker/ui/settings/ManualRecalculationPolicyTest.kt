package com.apoorvdarshan.calorietracker.ui.settings

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ManualRecalculationPolicyTest {
    @Test
    fun successfulManualRunSatisfiesAdaptiveWeeklyCheckWithoutSecondAiCall() {
        val today = LocalDate.of(2026, 8, 31)

        assertEquals("2026-08-31", adaptiveCheckDayAfterManualRecalculation(true, today))
        assertNull(adaptiveCheckDayAfterManualRecalculation(false, today))
    }
}
