package com.apoorvdarshan.calorietracker.ui.workouts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExerciseArtworkFramesTest {
    @Test
    fun `complete generated pair resolves in canonical order`() {
        assertEquals(
            listOf(
                "frames/male/Dumbbell_Bicep_Curl/0.webp",
                "frames/male/Dumbbell_Bicep_Curl/1.webp"
            ),
            generatedExerciseFramePaths(
                exerciseId = "Dumbbell_Bicep_Curl",
                gender = "male",
                availableFilenames = setOf("1.webp", "0.webp")
            )
        )
    }

    @Test
    fun `partial pair falls back instead of mixing art styles`() {
        assertNull(
            generatedExerciseFramePaths(
                exerciseId = "Dumbbell_Bicep_Curl",
                gender = "female",
                availableFilenames = setOf("0.webp")
            )
        )
    }

    @Test
    fun `unsafe id and invalid gender never form an asset path`() {
        assertNull(generatedExerciseFramePaths("../escape", "male", setOf("0.webp", "1.webp")))
        assertNull(generatedExerciseFramePaths("Safe_Id", "other", setOf("0.webp", "1.webp")))
    }
}
