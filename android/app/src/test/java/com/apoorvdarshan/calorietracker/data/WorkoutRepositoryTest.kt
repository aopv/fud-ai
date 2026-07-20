package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.CompletedExercise
import com.apoorvdarshan.calorietracker.models.CompletedSet
import com.apoorvdarshan.calorietracker.models.PlannedSet
import com.apoorvdarshan.calorietracker.models.WorkoutDayPlan
import com.apoorvdarshan.calorietracker.models.WorkoutPersistedState
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import com.apoorvdarshan.calorietracker.models.WorkoutTabMode
import com.apoorvdarshan.calorietracker.models.WorkoutWeightUnit
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

class WorkoutRepositoryTest {
    @Test
    fun planEditingSanitizesInputsAddsBlankSetsAndCopiesWithoutDuplicates() = runBlocking {
        val store = FakeWorkoutStateStore()
        val repository = WorkoutRepository(store)
        val source = LocalDate.of(2026, 7, 18)
        val target = LocalDate.of(2026, 7, 19)
        val item = exerciseItem()

        repository.toggleExercise(item, source)
        val sourceExercise = repository.planNow(source).exercises.single()
        val firstSet = sourceExercise.sets.single()
        repository.updateSet(
            exerciseId = sourceExercise.id,
            setId = firstSet.id,
            date = source,
            weight = "82,5 kg",
            weightUnit = WorkoutWeightUnit.KG,
            reps = "8 reps",
            rpe = "7.5"
        )
        repository.setSetCount(99, sourceExercise.id, source)

        val edited = repository.planNow(source).exercises.single()
        assertEquals(12, edited.sets.size)
        assertEquals("82.5", edited.sets.first().weight)
        assertEquals("8", edited.sets.first().reps)
        assertEquals("7.5", edited.sets.first().rpe)
        assertTrue(edited.sets.drop(1).all {
            it.weight.isEmpty() && it.weightUnit == null && it.reps.isEmpty() &&
                it.rpe.isEmpty() && it.rpeScale == null
        })

        repository.toggleExercise(item, target)
        repository.copyPlan(source, target)
        repository.copyPlan(source, target)
        val copied = repository.planNow(target).exercises

        assertEquals(1, copied.size)
        assertNotEquals(edited.id, copied.single().id)
        assertEquals(1, copied.single().sets.size)
        assertEquals("", copied.single().sets.single().weight)
        assertEquals("", copied.single().sets.single().reps)
        assertEquals("", copied.single().sets.single().rpe)
    }

    @Test
    fun calculatedBurnUpsertsOneStableDailyVersionedSnapshot() = runBlocking {
        val store = FakeWorkoutStateStore()
        val repository = WorkoutRepository(store)
        val date = LocalDate.of(2026, 7, 19)
        val item = exerciseItem()
        repository.toggleExercise(item, date)
        val exercise = repository.planNow(date).exercises.single()
        repository.updateSet(
            exerciseId = exercise.id,
            setId = exercise.sets.single().id,
            date = date,
            weight = "100",
            weightUnit = WorkoutWeightUnit.KG,
            reps = "8",
            rpe = "8"
        )

        val first = repository.upsertCalculatedWorkout(date, 180, WorkoutWeightUnit.KG)!!
        val second = repository.upsertCalculatedWorkout(date, 225, WorkoutWeightUnit.KG)!!
        val current = repository.snapshot()

        assertEquals(first.id, second.id)
        assertEquals(1, first.healthSyncVersion)
        assertEquals(2, second.healthSyncVersion)
        assertEquals(225, second.caloriesBurned)
        assertEquals(1, current.completedSessions.count { it.caloriesBurned != null })
        assertEquals(1, current.dayPlans.getValue(date.toString()).exercises.size)
    }

    @Test
    fun failedHealthDeleteLeavesTombstoneAndBlocksRestore() = runBlocking {
        val session = burnSession()
        val store = FakeWorkoutStateStore(
            WorkoutPersistedState(completedSessions = listOf(session))
        )
        val health = FakeWorkoutHealthSync(deleteSucceeds = false)
        val repository = WorkoutRepository(store, health)

        repository.deleteSession(session.id)
        repository.importWorkoutBurnSessions(listOf(session.copy(healthSyncVersion = 2)))
        val current = repository.snapshot()

        assertTrue(current.completedSessions.isEmpty())
        assertEquals(session.diaryDateKey, current.healthDeletionTombstones[session.id.toString()])
        assertEquals(listOf(session.id to session.diaryDateKey), health.deleted)
    }

    @Test
    fun reconcileCannotResurrectARecordDeletedDuringStaleHealthRead() = runBlocking {
        val session = burnSession()
        val store = FakeWorkoutStateStore(
            WorkoutPersistedState(completedSessions = listOf(session))
        )
        val readStarted = CompletableDeferred<Unit>()
        val releaseRead = CompletableDeferred<Unit>()
        val health = FakeWorkoutHealthSync(
            owned = listOf(session),
            readStarted = readStarted,
            releaseRead = releaseRead
        )
        val repository = WorkoutRepository(store, health)

        val reconcile = async(Dispatchers.Default) { repository.synchronizeWithHealth() }
        readStarted.await()
        val deletion = async(Dispatchers.Default) { repository.deleteSession(session.id) }
        while (repository.snapshot().healthDeletionTombstones.isEmpty()) {
            kotlinx.coroutines.yield()
        }
        releaseRead.complete(Unit)
        reconcile.await()
        deletion.await()

        val current = repository.snapshot()
        assertTrue(current.completedSessions.isEmpty())
        assertFalse(session.id.toString() in current.pendingHealthUpsertIds)
        assertEquals(listOf(session.id to session.diaryDateKey), health.deleted)
    }

    @Test
    fun newUsersDefaultToDiaryAndLaterLaunchesRestoreTheLastWorkoutView() = runBlocking {
        val store = FakeWorkoutStateStore()
        val firstLaunch = WorkoutRepository(store)

        assertEquals(WorkoutTabMode.LOG, firstLaunch.snapshot().mode)

        firstLaunch.setMode(WorkoutTabMode.LIBRARY)
        val secondLaunch = WorkoutRepository(store)
        assertEquals(WorkoutTabMode.LIBRARY, secondLaunch.snapshot().mode)

        secondLaunch.setMode(WorkoutTabMode.LOG)
        val thirdLaunch = WorkoutRepository(store)
        assertEquals(WorkoutTabMode.LOG, thirdLaunch.snapshot().mode)
    }

    @Test
    fun modeAndSavedIdsPersistInTheSameState() = runBlocking {
        val repository = WorkoutRepository(FakeWorkoutStateStore())
        repository.setMode(WorkoutTabMode.LIBRARY)
        repository.toggleSaved("bench")

        val current = repository.snapshot()
        assertEquals(WorkoutTabMode.LIBRARY, current.mode)
        assertEquals(setOf("bench"), current.savedExerciseIds)
        assertNull(current.completedSessions.firstOrNull())
    }

    private fun exerciseItem() = ExerciseItem(
        id = "bench",
        name = "Bench Press",
        level = "Intermediate",
        imagePaths = emptyList(),
        force = "Push",
        mechanic = "Compound",
        category = "Strength",
        equipment = "Barbell",
        primaryMuscles = listOf("Chest"),
        secondaryMuscles = listOf("Triceps"),
        instructions = listOf("Control the repetition.")
    )

    private fun burnSession(): WorkoutSession {
        val instant = Instant.parse("2026-07-19T12:00:00Z")
        return WorkoutSession(
            diaryDateKey = "2026-07-19",
            startedAt = instant,
            completedAt = instant,
            exercises = listOf(
                CompletedExercise(
                    itemId = "bench",
                    name = "Bench Press",
                    targetMuscles = listOf("Chest"),
                    equipment = "Barbell",
                    sets = listOf(
                        CompletedSet(
                            setNumber = 1,
                            weight = "100",
                            weightUnit = WorkoutWeightUnit.KG,
                            reps = "5",
                            rpe = "8"
                        )
                    )
                )
            ),
            caloriesBurned = 200,
            healthSyncVersion = 1
        )
    }
}

private class FakeWorkoutStateStore(initial: WorkoutPersistedState = WorkoutPersistedState()) : WorkoutStateStore {
    private val mutable = MutableStateFlow(initial)
    override val workoutState: Flow<WorkoutPersistedState> = mutable

    override suspend fun setWorkoutState(state: WorkoutPersistedState) {
        mutable.value = state
    }

    override suspend fun clearWorkoutState() {
        mutable.value = WorkoutPersistedState()
    }
}

private class FakeWorkoutHealthSync(
    private val deleteSucceeds: Boolean = true,
    private val owned: List<WorkoutSession>? = emptyList(),
    private val readStarted: CompletableDeferred<Unit>? = null,
    private val releaseRead: CompletableDeferred<Unit>? = null
) : WorkoutHealthSync {
    val deleted = mutableListOf<Pair<UUID, String>>()

    override suspend fun upsertBurn(session: WorkoutSession): Boolean = true

    override suspend fun deleteBurn(sessionId: UUID, diaryDateKey: String): Boolean {
        deleted += sessionId to diaryDateKey
        return deleteSucceeds
    }

    override suspend fun readOwnedBurns(): List<WorkoutSession>? {
        readStarted?.complete(Unit)
        releaseRead?.await()
        return owned
    }
}
