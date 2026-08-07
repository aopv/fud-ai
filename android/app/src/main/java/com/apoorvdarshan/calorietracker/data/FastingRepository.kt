package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.FastingDefaults
import com.apoorvdarshan.calorietracker.models.FastingSession
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.util.UUID

class FastingRepository(private val prefs: PreferencesStore) {
    val sessions: Flow<List<FastingSession>> = prefs.fastingSessions.map { list -> list.sortedBy { it.startedAt } }

    suspend fun active(): FastingSession? = prefs.fastingSessions.first().lastOrNull { it.isActive }

    suspend fun start(goalMinutes: Int, at: Instant = Instant.now()): FastingSession? {
        val current = prefs.fastingSessions.first()
        if (current.any { it.isActive }) return null
        val session = FastingSession(
            startedAt = at,
            goalMinutes = goalMinutes.coerceIn(FastingDefaults.MIN_GOAL_MINUTES, FastingDefaults.MAX_GOAL_MINUTES)
        )
        prefs.setFastingSessions(current + session)
        return session
    }

    suspend fun endActive(at: Instant = Instant.now()): FastingSession? {
        val current = prefs.fastingSessions.first()
        val active = current.lastOrNull { it.isActive } ?: return null
        val completed = active.copy(endedAt = maxOf(at, active.startedAt))
        prefs.setFastingSessions(current.map { if (it.id == active.id) completed else it })
        return completed
    }

    suspend fun cancelActive() {
        val current = prefs.fastingSessions.first()
        prefs.setFastingSessions(current.filterNot { it.isActive })
    }

    suspend fun update(session: FastingSession) {
        val current = prefs.fastingSessions.first()
        if (session.isActive && current.any { it.id != session.id && it.isActive }) return
        val validated = session.copy(
            endedAt = session.endedAt?.let { maxOf(it, session.startedAt) },
            goalMinutes = session.goalMinutes.coerceIn(
                FastingDefaults.MIN_GOAL_MINUTES,
                FastingDefaults.MAX_GOAL_MINUTES
            )
        )
        prefs.setFastingSessions(current.map { if (it.id == session.id) validated else it })
    }

    suspend fun delete(id: UUID) {
        prefs.setFastingSessions(prefs.fastingSessions.first().filterNot { it.id == id })
    }
}
