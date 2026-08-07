package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.Serializable
import java.time.Duration
import java.time.Instant
import java.util.UUID

object FastingDefaults {
    const val GOAL_MINUTES = 16 * 60
    const val MIN_GOAL_MINUTES = 60
    const val MAX_GOAL_MINUTES = 7 * 24 * 60
}

@Serializable
data class FastingSession(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    @Serializable(with = InstantSerializer::class)
    val startedAt: Instant = Instant.now(),
    @Serializable(with = InstantSerializer::class)
    val endedAt: Instant? = null,
    val goalMinutes: Int = FastingDefaults.GOAL_MINUTES
) {
    val isActive: Boolean get() = endedAt == null
    val goalAt: Instant get() = startedAt.plusSeconds(goalMinutes.coerceIn(
        FastingDefaults.MIN_GOAL_MINUTES,
        FastingDefaults.MAX_GOAL_MINUTES
    ).toLong() * 60)

    fun durationSeconds(now: Instant = Instant.now()): Long =
        Duration.between(startedAt, endedAt ?: now).seconds.coerceAtLeast(0)
}

fun formatFastingDuration(seconds: Long): String {
    val totalMinutes = seconds.coerceAtLeast(0) / 60
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return when {
        hours == 0L -> "${minutes}m"
        minutes == 0L -> "${hours}h"
        else -> "${hours}h ${minutes}m"
    }
}
