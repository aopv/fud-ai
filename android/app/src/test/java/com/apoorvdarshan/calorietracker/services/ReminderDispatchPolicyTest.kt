package com.apoorvdarshan.calorietracker.services

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderDispatchPolicyTest {
    @Test
    fun `streak reminder is skipped after food is logged today`() {
        assertFalse(
            ReminderDispatchPolicy.shouldPost(
                isStreakReminder = true,
                hasLoggedToday = true
            )
        )
    }

    @Test
    fun `streak reminder posts when no food is logged today`() {
        assertTrue(
            ReminderDispatchPolicy.shouldPost(
                isStreakReminder = true,
                hasLoggedToday = false
            )
        )
    }

    @Test
    fun `non-streak reminders are never suppressed by food logs`() {
        assertTrue(
            ReminderDispatchPolicy.shouldPost(
                isStreakReminder = false,
                hasLoggedToday = true
            )
        )
    }
}
