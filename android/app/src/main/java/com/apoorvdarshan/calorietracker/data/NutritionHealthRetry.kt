package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.services.health.NutritionWriteGate
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.UUID

/**
 * Health Connect as the food log needs it. Mirrors [WorkoutHealthSync] so the retry path
 * can be exercised without a live Health Connect service.
 */
interface NutritionHealthSync {
    suspend fun writeGate(): NutritionWriteGate
    suspend fun write(entry: FoodEntry): Boolean

    /**
     * Delete-then-write on the entry's own clientRecordId. Used for every retry, so a
     * second attempt cannot duplicate a record that did land after all — the delete
     * targets that one entry, never the day or the whole log.
     */
    suspend fun update(entry: FoodEntry): Boolean
}

/** The slice of persistence the retry needs. Mirrors [WorkoutStateStore]. */
interface NutritionSyncStore {
    val foodEntries: Flow<List<FoodEntry>>
    val healthConnectEnabled: Flow<Boolean>
    val pendingNutritionHealthWrites: Flow<Set<String>>
    suspend fun setPendingNutritionHealthWrites(ids: Set<String>)
}

/**
 * Keeps food entries whose Health Connect write was never confirmed, and re-attempts them
 * on the next foreground sync.
 *
 * Before this existed, `FoodRepository.addEntry` called `writeNutrition` and discarded the
 * result, and the permission probe in front of it turned an unreachable Health Connect
 * service into "no permission". Either path dropped the entry with no exception, no log
 * and no retry: the food log kept it, Health Connect never heard about it, and nothing in
 * the app knew the two had diverged. [WorkoutRepository] already defers and retries its
 * burn writes this way; nutrition simply never got the same treatment.
 */
class NutritionHealthRetry(
    private val store: NutritionSyncStore,
    private val health: NutritionHealthSync?
) {
    private val mutex = Mutex()

    /**
     * Push [entry] to Health Connect, queueing it when the write is not confirmed.
     *
     * On [NutritionWriteGate.UNKNOWN] the write is attempted anyway. Health Connect
     * enforces its own permissions, so the worst case is a rejection we then queue and
     * resolve on the next pass — strictly better than assuming the answer and dropping
     * the entry.
     */
    suspend fun sync(entry: FoodEntry, isUpdate: Boolean) = syncAll(listOf(entry), isUpdate)

    /**
     * Push several entries in one pass. A diary import can carry hundreds of changed
     * entries, and resolving the gate per entry would mean one Health Connect IPC
     * round-trip each, so the gate and the queue are resolved once for the batch.
     */
    suspend fun syncAll(entries: List<FoodEntry>, isUpdate: Boolean) {
        val adapter = health ?: return
        if (entries.isEmpty()) return
        if (!store.healthConnectEnabled.first()) return
        if (adapter.writeGate() == NutritionWriteGate.DENIED) return
        val written = mutableSetOf<String>()
        val failed = mutableSetOf<String>()
        for (entry in entries) {
            val ok = if (isUpdate) adapter.update(entry) else adapter.write(entry)
            (if (ok) written else failed) += entry.id.toString()
        }
        updateQueue { (it - written) + failed }
    }

    /** Drop [id] from the queue — the write landed, or the entry no longer exists. */
    suspend fun forget(id: UUID) = forgetAll(listOf(id))

    /** Batch form of [forget], so an import does not rewrite the queue once per entry. */
    suspend fun forgetAll(ids: Collection<UUID>) {
        if (ids.isEmpty()) return
        val keys = ids.mapTo(mutableSetOf()) { it.toString() }
        updateQueue { it - keys }
    }

    /**
     * Re-attempt every queued write. Called from the app-foreground Health Connect
     * coordinator, alongside the workout deferred writes.
     */
    suspend fun retryPending() {
        val adapter = health ?: return
        mutex.withLock {
            val pending = store.pendingNutritionHealthWrites.first()
            if (pending.isEmpty()) return@withLock
            if (!store.healthConnectEnabled.first()) return@withLock
            when (adapter.writeGate()) {
                // Still cannot reach the service. Keep the queue and try again on the next
                // foreground — discarding it here is the exact bug this retry exists to fix.
                NutritionWriteGate.UNKNOWN -> return@withLock
                // Nutrition write was revoked. Nothing is retryable any more, and an
                // unbounded queue would otherwise outlive the permission forever.
                NutritionWriteGate.DENIED -> {
                    store.setPendingNutritionHealthWrites(emptySet())
                    return@withLock
                }
                NutritionWriteGate.ALLOWED -> Unit
            }
            val byId = store.foodEntries.first().associateBy { it.id.toString() }
            val remaining = mutableSetOf<String>()
            for (key in pending) {
                // Deleted since it was queued: deleteEntry already removed the record.
                val entry = byId[key] ?: continue
                if (!adapter.update(entry)) remaining += key
            }
            if (remaining != pending) store.setPendingNutritionHealthWrites(remaining)
        }
    }

    /** Read-modify-write of the queue under the lock, skipping a no-op store write. */
    private suspend fun updateQueue(transform: (Set<String>) -> Set<String>) {
        mutex.withLock {
            val current = store.pendingNutritionHealthWrites.first()
            val next = transform(current)
            if (next != current) store.setPendingNutritionHealthWrites(next)
        }
    }
}
