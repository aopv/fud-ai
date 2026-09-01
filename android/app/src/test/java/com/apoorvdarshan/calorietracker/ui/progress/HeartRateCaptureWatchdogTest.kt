package com.apoorvdarshan.calorietracker.ui.progress

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HeartRateCaptureWatchdogTest {
    @Test
    fun absoluteTorchDeadlineLeavesTimeToAcquireContact() {
        val enabledAt = 1_000L

        assertFalse(hasHeartRateCaptureTimedOut(enabledAt, enabledAt + 44_999L))
        assertTrue(hasHeartRateCaptureTimedOut(enabledAt, enabledAt + 45_000L))
        assertFalse(hasHeartRateCaptureTimedOut(enabledAt, enabledAt - 1L))
    }
}
