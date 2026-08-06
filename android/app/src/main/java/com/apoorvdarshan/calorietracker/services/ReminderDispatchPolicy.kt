package com.apoorvdarshan.calorietracker.services

/** Pure reminder eligibility rule, kept separate so it can be covered by local JVM tests. */
internal object ReminderDispatchPolicy {
    fun shouldPost(isStreakReminder: Boolean, hasLoggedToday: Boolean): Boolean =
        !isStreakReminder || !hasLoggedToday
}
