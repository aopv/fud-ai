package com.apoorvdarshan.calorietracker.models

import com.apoorvdarshan.calorietracker.data.ExerciseItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WorkoutModelsTest {
    @Test
    fun preferencesDefaultToFullBodyAndMigrateLegacyCustom() {
        val defaults = WorkoutPreferences()
        val migrated = WorkoutPreferences(
            split = WorkoutSplit.CUSTOM,
            customSplit = "Chest + back / Legs",
            frequencyDays = 9,
            strength = WorkoutStrengthNumbers(squatKg = -5.0)
        ).sanitized()

        assertEquals(WorkoutSplit.FULL_BODY, defaults.split)
        assertEquals(WorkoutRpeScale.STRENGTH, defaults.rpeScale)
        assertEquals(WorkoutSplit.FULL_BODY, migrated.split)
        assertEquals("", migrated.customSplit)
        assertEquals(7, migrated.frequencyDays)
        assertNull(migrated.strength.squatKg)
        assertTrue(WorkoutSplit.CUSTOM !in WorkoutSplit.SelectableValues)
    }

    @Test
    fun rpeSanitizationPreservesTypingAndEnforcesEachScale() {
        assertEquals("7.", WorkoutRpeScale.STRENGTH.sanitize("7."))
        assertEquals("8.6", WorkoutRpeScale.CR10.sanitize("8,67"))
        assertEquals("18", WorkoutRpeScale.BORG.sanitize("18"))
        assertEquals("20", WorkoutRpeScale.BORG.sanitize("99", previousValue = "18"))
        assertEquals("20", WorkoutRpeScale.BORG.sanitize("5", previousValue = "20"))
    }

    @Test
    fun plannedWeightDisplayConvertsWithoutMutatingStoredValue() {
        val set = PlannedSet(weight = "100", weightUnit = WorkoutWeightUnit.KG)

        assertEquals("220.46", set.displayWeight(WorkoutWeightUnit.LBS))
        assertEquals("100", set.weight)
        assertEquals(WorkoutWeightUnit.KG, set.weightUnit)
    }

    @Test
    fun estimatorRequiresPositiveRepsAndRespondsToEffortAndLoad() {
        val blank = exercise(PlannedSet())
        assertNull(
            WorkoutBurnEstimator.estimate(
                exercises = listOf(blank),
                bodyWeightKg = 75.0,
                defaultWeightUnit = WorkoutWeightUnit.KG,
                defaultRpeScale = WorkoutRpeScale.STRENGTH
            )
        )

        val easier = WorkoutBurnEstimator.estimate(
            exercises = listOf(exercise(PlannedSet(weight = "8", weightUnit = WorkoutWeightUnit.KG, reps = "12", rpe = "3"))),
            bodyWeightKg = 75.0,
            defaultWeightUnit = WorkoutWeightUnit.KG,
            defaultRpeScale = WorkoutRpeScale.STRENGTH
        )!!
        val harder = WorkoutBurnEstimator.estimate(
            exercises = listOf(exercise(PlannedSet(weight = "40", weightUnit = WorkoutWeightUnit.KG, reps = "12", rpe = "10"))),
            bodyWeightKg = 75.0,
            defaultWeightUnit = WorkoutWeightUnit.KG,
            defaultRpeScale = WorkoutRpeScale.STRENGTH
        )!!

        assertEquals(1, easier.performedSetCount)
        assertEquals(12, easier.repCount)
        assertTrue(harder.calories > easier.calories)
        assertTrue(harder.calories in 1..5_000)
    }

    @Test
    fun splitGroupsMatchPrimaryAndSecondaryCatalogMuscles() {
        val groups = WorkoutSplitGroup.selectionGroups(
            split = WorkoutSplit.PUSH_PULL_LEGS,
            availablePrimaryMuscles = listOf("Chest", "Lats", "Quadriceps", "Abdominals"),
            availableSecondaryMuscles = listOf("Shoulders", "Biceps", "Hamstrings")
        )

        assertEquals(listOf("Push", "Pull", "Legs", "Core"), groups.map { it.title })
        assertEquals(setOf("Chest", "Shoulders"), groups.first { it.title == "Push" }.muscles)
        assertEquals(setOf("Biceps", "Lats"), groups.first { it.title == "Pull" }.muscles)
    }

    private fun exercise(set: PlannedSet): PlannedExercise = PlannedExercise.from(
        ExerciseItem(
            id = "curl",
            name = "Dumbbell Curl",
            level = "Intermediate",
            imagePaths = emptyList(),
            force = "Pull",
            mechanic = "Isolation",
            category = "Strength",
            equipment = "Dumbbell",
            primaryMuscles = listOf("Biceps"),
            secondaryMuscles = listOf("Forearms"),
            instructions = listOf("Control the repetition.")
        )
    ).copy(sets = listOf(set))
}
