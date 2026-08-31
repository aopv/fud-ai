package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.HeartRateEntry
import com.apoorvdarshan.calorietracker.models.HeartRateSource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.time.Instant
import java.util.UUID

class HeartRateRepositoryTest {
    @Test
    fun entriesPersistInChronologicalOrderAndCrudIsStable() = runBlocking {
        val store = FakeHeartRateStore()
        val repository = HeartRateRepository(store)
        val later = HeartRateEntry(
            date = Instant.parse("2026-08-30T10:00:00Z"),
            bpm = 90,
            source = HeartRateSource.CAMERA,
            quality = 0.82
        )
        val earlier = HeartRateEntry(
            date = Instant.parse("2026-08-29T10:00:00Z"),
            bpm = 60,
            source = HeartRateSource.MANUAL
        )

        assertTrue(repository.addEntry(later))
        assertTrue(repository.addEntry(earlier))
        assertEquals(listOf(earlier, later), repository.entries.first())
        assertEquals(listOf(earlier, later), store.values.value)
        assertEquals(
            listOf(earlier),
            repository.entriesInRange(
                earlier.date.minusSeconds(60),
                earlier.date.plusSeconds(60)
            )
        )

        assertTrue(repository.deleteEntry(earlier.id))
        assertEquals(listOf(later), repository.entries.first())
        assertTrue(repository.clear())
        assertTrue(repository.entries.first().isEmpty())
    }

    @Test
    fun rejectsImplausibleOrMalformedEntries() = runBlocking {
        val store = FakeHeartRateStore()
        val repository = HeartRateRepository(store)

        assertFalse(repository.addEntry(HeartRateEntry(bpm = 20, source = HeartRateSource.MANUAL)))
        assertFalse(
            repository.addEntry(
                HeartRateEntry(bpm = 80, source = HeartRateSource.CAMERA, quality = 1.4)
            )
        )
        assertTrue(store.values.value.orEmpty().isEmpty())
    }

    @Test
    fun corruptPersistedStateIsNeverOverwrittenByAnAdd() = runBlocking {
        val store = FakeHeartRateStore(initial = null)
        val repository = HeartRateRepository(store)

        assertFalse(
            repository.addEntry(HeartRateEntry(bpm = 72, source = HeartRateSource.MANUAL))
        )
        assertEquals(null, store.values.value)
        assertTrue(repository.entries.first().isEmpty())
    }

    @Test
    fun decodedButInvalidPersistedStateIsAlsoPreserved() = runBlocking {
        val invalid = HeartRateEntry(bpm = 280, source = HeartRateSource.MANUAL)
        val store = FakeHeartRateStore(initial = listOf(invalid))
        val repository = HeartRateRepository(store)

        assertFalse(
            repository.addEntry(HeartRateEntry(bpm = 72, source = HeartRateSource.MANUAL))
        )
        assertEquals(listOf(invalid), store.values.value)
    }

    @Test
    fun duplicatePersistedIdsFailClosedAndAreNotExposedToLazyListKeys() = runBlocking {
        val duplicateId = UUID.randomUUID()
        val first = HeartRateEntry(
            id = duplicateId,
            date = Instant.parse("2026-08-29T10:00:00Z"),
            bpm = 70,
            source = HeartRateSource.MANUAL
        )
        val duplicate = first.copy(date = Instant.parse("2026-08-30T10:00:00Z"), bpm = 72)
        val store = FakeHeartRateStore(initial = listOf(first, duplicate))
        val repository = HeartRateRepository(store)

        assertTrue(repository.entries.first().isEmpty())
        assertFalse(
            repository.addEntry(HeartRateEntry(bpm = 74, source = HeartRateSource.MANUAL))
        )
        assertFalse(repository.deleteEntry(duplicateId))
        assertEquals(listOf(first, duplicate), store.values.value)
    }

    @Test
    fun incomingDuplicateIdIsRejectedWithoutReplacingExistingReading() = runBlocking {
        val existing = HeartRateEntry(
            date = Instant.parse("2026-08-29T10:00:00Z"),
            bpm = 70,
            source = HeartRateSource.MANUAL
        )
        val store = FakeHeartRateStore(initial = listOf(existing))
        val repository = HeartRateRepository(store)

        assertFalse(
            repository.addEntry(
                existing.copy(date = Instant.parse("2026-08-30T10:00:00Z"), bpm = 90)
            )
        )
        assertEquals(listOf(existing), store.values.value)
    }

    @Test
    fun writeFailuresReturnFalseInsteadOfEscaping() = runBlocking {
        val store = FakeHeartRateStore(throwOnWrite = true)
        val repository = HeartRateRepository(store)

        assertFalse(
            repository.addEntry(HeartRateEntry(bpm = 72, source = HeartRateSource.MANUAL))
        )
        assertFalse(repository.deleteEntry(UUID.randomUUID()))
        assertFalse(repository.clear())
        assertTrue(repository.entries.first().isEmpty())
    }
}

private class FakeHeartRateStore(
    initial: List<HeartRateEntry>? = emptyList(),
    private val throwOnWrite: Boolean = false
) : HeartRateStateStore {
    val values = MutableStateFlow(initial)
    override val heartRateEntries: Flow<List<HeartRateEntry>?> = values
    override suspend fun setHeartRateEntries(entries: List<HeartRateEntry>) {
        if (throwOnWrite) throw IOException("simulated DataStore write failure")
        values.value = entries
    }
}
