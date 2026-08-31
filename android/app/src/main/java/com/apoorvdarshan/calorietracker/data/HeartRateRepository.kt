package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.HeartRateEntry
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.util.UUID

/** Persistence seam keeps local heart-rate behavior independently testable from Android DataStore. */
interface HeartRateStateStore {
    /** Null means persisted data exists but could not be decoded; callers must not overwrite it. */
    val heartRateEntries: Flow<List<HeartRateEntry>?>
    suspend fun setHeartRateEntries(entries: List<HeartRateEntry>)
}

/** Local-only CRUD for manual and camera spot checks. It does not affect profile or goal math. */
class HeartRateRepository(private val store: HeartRateStateStore) {
    private val mutationMutex = Mutex()

    val entries: Flow<List<HeartRateEntry>> = store.heartRateEntries.map { values ->
        values
            ?.takeIf(::isValidPersistedState)
            ?.sortedBy(HeartRateEntry::date)
            .orEmpty()
    }

    suspend fun addEntry(entry: HeartRateEntry): Boolean {
        if (!entry.isValid) return false
        return runCatching {
            mutationMutex.withLock {
                val current = store.heartRateEntries.first() ?: return@withLock false
                if (!isValidPersistedState(current)) return@withLock false
                if (current.any { it.id == entry.id }) return@withLock false
                store.setHeartRateEntries((current + entry).sortedBy(HeartRateEntry::date))
                true
            }
        }.getOrDefault(false)
    }

    suspend fun deleteEntry(id: UUID): Boolean = runCatching {
        mutationMutex.withLock {
            val current = store.heartRateEntries.first() ?: return@withLock false
            if (!isValidPersistedState(current)) return@withLock false
            store.setHeartRateEntries(current.filterNot { it.id == id })
            true
        }
    }.getOrDefault(false)

    suspend fun entriesInRange(from: Instant, to: Instant): List<HeartRateEntry> =
        entries.first().filter { it.date in from..to }

    suspend fun clear(): Boolean = runCatching {
        mutationMutex.withLock { store.setHeartRateEntries(emptyList()) }
        true
    }.getOrDefault(false)

    private fun isValidPersistedState(values: List<HeartRateEntry>): Boolean =
        values.all(HeartRateEntry::isValid) && values.map(HeartRateEntry::id).distinct().size == values.size
}
