package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.Gender
import com.google.gson.Gson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class ExerciseVisualResolverTest {
    @Test
    fun manifestAcceptsThreeFourAndFiveFrameAtomicGenderSets() {
        (3..5).forEach { frameCount ->
            val frames = ExerciseVisualResolver.parseManifest(
                json = manifestJson(frameCount = frameCount),
                packagedAssetNames = assetNames(frameCount)
            )

            assertSvgVisual(
                visual = ExerciseVisualResolver.resolve(item, Gender.FEMALE, frames),
                expectedGender = "female",
                frameCount = frameCount
            )
            assertSvgVisual(
                visual = ExerciseVisualResolver.resolve(item, Gender.MALE, frames),
                expectedGender = "male",
                frameCount = frameCount
            )
            assertSvgVisual(
                visual = ExerciseVisualResolver.resolve(item, Gender.OTHER, frames),
                expectedGender = "male",
                frameCount = frameCount
            )
        }
    }

    @Test
    fun twoOrSixFrameManifestEntriesFallBackToDatasetJpegs() {
        listOf(2, 6).forEach { frameCount ->
            val frames = ExerciseVisualResolver.parseManifest(
                json = manifestJson(frameCount = frameCount),
                packagedAssetNames = assetNames(frameCount)
            )
            val visual = ExerciseVisualResolver.resolve(item, Gender.MALE, frames)

            assertEquals(ExerciseVisualFormat.JPEG, visual.format)
            assertEquals(item.imagePaths, visual.framePaths)
        }
    }

    @Test
    fun missingOppositeGenderOrPackagedFrameFallsBackToDatasetJpegs() {
        val missingFemaleManifest = ExerciseVisualResolver.parseManifest(
            json = manifestJson(frameCount = 4, includeFemaleFrames = false),
            packagedAssetNames = assetNames(4)
        )
        val missingPackagedFrame = ExerciseVisualResolver.parseManifest(
            json = manifestJson(frameCount = 4),
            packagedAssetNames = assetNames(4) - "${item.id}_female_2.svg"
        )

        listOf(missingFemaleManifest, missingPackagedFrame).forEach { frames ->
            val visual = ExerciseVisualResolver.resolve(item, Gender.MALE, frames)
            assertEquals(ExerciseVisualFormat.JPEG, visual.format)
            assertEquals(item.imagePaths, visual.framePaths)
        }
    }

    @Test
    fun sharedPilotManifestAndPackagedSourcesAreComplete() {
        val vectorDirectory = File(repositoryRoot(), "shared/workout-vectors")
        val manifest = File(vectorDirectory, ExerciseVisualResolver.MANIFEST_ASSET_NAME)
        assertTrue("Missing shared exercise visual manifest: ${manifest.absolutePath}", manifest.isFile)

        val frames = ExerciseVisualResolver.parseManifest(
            json = manifest.readText(),
            packagedAssetNames = vectorDirectory.list()?.toSet().orEmpty()
        )
        assertSvgVisual(
            visual = ExerciseVisualResolver.resolve(item, Gender.FEMALE, frames),
            expectedGender = "female",
            frameCount = 4,
            expectedRepresentativeFrame = 2
        )
        assetNames(4).forEach { assetName ->
            val asset = File(vectorDirectory, assetName)
            assertTrue("Missing pilot workout vector: ${asset.absolutePath}", asset.isFile)
        }
    }

    private fun assertSvgVisual(
        visual: ExerciseVisual,
        expectedGender: String,
        frameCount: Int,
        expectedRepresentativeFrame: Int = 1
    ) {
        assertEquals(ExerciseVisualFormat.SVG, visual.format)
        assertEquals(
            (0 until frameCount).map { frame -> "${item.id}_${expectedGender}_${frame}.svg" },
            visual.framePaths
        )
        assertEquals(expectedRepresentativeFrame, visual.representativeFrameIndex)
    }

    private fun manifestJson(
        frameCount: Int,
        includeMaleFrames: Boolean = true,
        includeFemaleFrames: Boolean = true
    ): String {
        val entry = linkedMapOf<String, Any>(
            "exerciseId" to item.id,
            "frameCount" to frameCount,
            "representativeFrameIndex" to 1
        )
        if (includeMaleFrames) {
            entry["maleFrames"] = frameNames("male", frameCount)
        }
        if (includeFemaleFrames) {
            entry["femaleFrames"] = frameNames("female", frameCount)
        }
        return Gson().toJson(
            mapOf(
                "schemaVersion" to 1,
                "exercises" to listOf(entry)
            )
        )
    }

    private fun frameNames(gender: String, frameCount: Int): List<String> =
        (0 until frameCount).map { frame -> "${item.id}_${gender}_$frame" }

    private fun assetNames(frameCount: Int): Set<String> = buildSet {
        listOf("male", "female").forEach { gender ->
            frameNames(gender, frameCount).forEach { add("$it.svg") }
        }
    }

    private fun repositoryRoot(): File = generateSequence(
        File(System.getProperty("user.dir")).absoluteFile
    ) { directory -> directory.parentFile }
        .firstOrNull { directory ->
            File(directory, "shared/workout-vectors").isDirectory
        }
        ?: error("Could not locate the repository root from ${System.getProperty("user.dir")}")

    private val item = ExerciseItem(
        id = "Barbell_Full_Squat",
        name = "Barbell Full Squat",
        level = "Intermediate",
        imagePaths = listOf("Barbell_Full_Squat/0.jpg", "Barbell_Full_Squat/1.jpg"),
        force = "Push",
        mechanic = "Compound",
        category = "Strength",
        equipment = "Barbell",
        primaryMuscles = listOf("Quadriceps"),
        secondaryMuscles = listOf("Glutes"),
        instructions = listOf("Squat with control.")
    )
}
