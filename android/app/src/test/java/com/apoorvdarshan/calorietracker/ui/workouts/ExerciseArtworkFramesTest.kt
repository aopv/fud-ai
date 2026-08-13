package com.apoorvdarshan.calorietracker.ui.workouts

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ExerciseArtworkFramesTest {
    private fun indexJson(
        frameIndexes: List<Int>,
        gender: String = "male",
        frameDurationMs: Int? = null
    ): String = """
        {
          "entries": [
            {
              "exerciseID": "Dumbbell_Bicep_Curl",
              "gender": "$gender",
              ${frameDurationMs?.let { "\"frameDurationMs\":$it," }.orEmpty()}
              "frames": [
                ${frameIndexes.joinToString(",") { index ->
                    """{"frameIndex":$index,"path":"shared/exercise-artwork/fud-flat-raster-v1/packaged-768/frames/$gender/Dumbbell_Bicep_Curl/$index.webp"}"""
                }}
              ]
            }
          ]
        }
    """.trimIndent()

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
                indexJson = indexJson(listOf(1, 0))
            )
        )
    }

    @Test
    fun `six indexed frames resolve in canonical order`() {
        assertEquals(
            (0..5).map { "frames/female/Dumbbell_Bicep_Curl/$it.webp" },
            generatedExerciseFramePaths(
                exerciseId = "Dumbbell_Bicep_Curl",
                gender = "female",
                indexJson = indexJson((0..5).toList(), gender = "female")
            )
        )
    }

    @Test
    fun `partial or noncontiguous sequence falls back instead of mixing art styles`() {
        assertNull(
            generatedExerciseFramePaths(
                exerciseId = "Dumbbell_Bicep_Curl",
                gender = "female",
                indexJson = indexJson(listOf(0), gender = "female")
            )
        )
        assertNull(generatedExerciseFramePaths("Dumbbell_Bicep_Curl", "male", indexJson(listOf(0, 2))))
    }

    @Test
    fun `unsafe id and invalid gender never form an asset path`() {
        assertNull(generatedExerciseFramePaths("../escape", "male", indexJson(listOf(0, 1))))
        assertNull(generatedExerciseFramePaths("Safe_Id", "other", indexJson(listOf(0, 1))))
    }

    @Test
    fun `index paths must match their exact exercise gender and frame`() {
        val wrongPath = indexJson(listOf(0, 1)).replace(
            "frames/male/Dumbbell_Bicep_Curl/1.webp",
            "frames/male/Another_Exercise/1.webp"
        )
        assertNull(generatedExerciseFramePaths("Dumbbell_Bicep_Curl", "male", wrongPath))
    }

    @Test
    fun `one malformed frame invalidates the entire sequence`() {
        val extraMismatchedFrame = indexJson(listOf(0, 1)).replace(
            "\"frames\": [",
            "\"frames\": [{\"frameIndex\":2,\"path\":\"frames/male/Other/2.webp\"},"
        )
        assertNull(generatedExerciseFramePaths("Dumbbell_Bicep_Curl", "male", extraMismatchedFrame))
    }

    @Test
    fun `ping pong order has no last to first snap`() {
        assertEquals(listOf(0, 1), pingPongFrameIndexes(2))
        assertEquals(listOf(0, 1, 2, 3, 4, 5, 4, 3, 2, 1), pingPongFrameIndexes(6))
    }

    @Test
    fun `generated timing and animator scale are honored`() {
        assertEquals(850L, generatedFrameDurationMs(2))
        assertEquals(120L, generatedFrameDurationMs(6))
        assertEquals(60L, scaledFrameDurationMs(120L, 0.5f))
        assertEquals(240L, scaledFrameDurationMs(120L, 2f))
    }

    @Test
    fun `entry timing metadata overrides frame count default`() {
        val sequence = generatedExerciseSequence(
            "Dumbbell_Bicep_Curl",
            "male",
            indexJson((0..5).toList(), frameDurationMs = 144)
        )
        assertEquals(144L, sequence?.frameDurationMs)
        assertEquals(120L, generatedExerciseSequence(
            "Dumbbell_Bicep_Curl",
            "male",
            indexJson((0..5).toList())
        )?.frameDurationMs)
    }
}
