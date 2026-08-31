package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.Gender
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName

enum class ExerciseVisualFormat {
    JPEG,
    SVG
}

data class ExerciseVisual(
    val framePaths: List<String>,
    val format: ExerciseVisualFormat,
    val representativeFrameIndex: Int
) {
    companion object {
        fun jpeg(paths: List<String>): ExerciseVisual = ExerciseVisual(
            framePaths = paths,
            format = ExerciseVisualFormat.JPEG,
            representativeFrameIndex = 0
        )
    }
}

/** Complete gender-specific vector frame sets discovered in the flat exercise asset directory. */
internal data class GenderedExerciseSvgFrames(
    val male: List<String>,
    val female: List<String>,
    val representativeFrameIndex: Int
) {
    fun forGender(gender: Gender): List<String> = when (gender) {
        Gender.FEMALE -> female
        // OTHER intentionally uses the male visual convention so its result is deterministic.
        Gender.MALE, Gender.OTHER -> male
    }
}

internal object ExerciseVisualResolver {
    const val MANIFEST_ASSET_NAME = "exercise-visual-manifest.json"

    private data class ManifestDocument(
        @SerializedName("schemaVersion")
        val schemaVersion: Int? = null,
        @SerializedName("exercises")
        val exercises: List<ManifestRecord>? = null
    )

    private data class ManifestRecord(
        @SerializedName("exerciseId")
        val exerciseId: String? = null,
        @SerializedName("frameCount")
        val frameCount: Int? = null,
        @SerializedName("representativeFrameIndex")
        val representativeFrameIndex: Int? = null,
        @SerializedName("maleFrames")
        val maleFrames: List<String>? = null,
        @SerializedName("femaleFrames")
        val femaleFrames: List<String>? = null
    )

    /**
     * Parses the shared packaging manifest and exposes only atomic male/female sets with 3–5
     * contiguous frames. When [packagedAssetNames] is supplied, every referenced SVG must also
     * exist in the APK asset root; a partial package therefore falls back to the existing JPEGs.
     */
    fun parseManifest(
        json: String,
        packagedAssetNames: Collection<String>? = null
    ): Map<String, GenderedExerciseSvgFrames> {
        val document = runCatching { Gson().fromJson(json, ManifestDocument::class.java) }
            .getOrNull()
            ?: return emptyMap()
        if (document.schemaVersion != 1) return emptyMap()

        val entries = mutableMapOf<String, GenderedExerciseSvgFrames>()
        val duplicateIDs = mutableSetOf<String>()
        document.exercises.orEmpty().forEach { record ->
            val exerciseID = record.exerciseId?.takeIf { it.isNotBlank() } ?: return@forEach
            val frameCount = record.frameCount?.takeIf { it in 3..5 } ?: return@forEach
            val representative = record.representativeFrameIndex
                ?.takeIf { it in 0 until frameCount }
                ?: return@forEach
            val expectedMale = (0 until frameCount).map { "${exerciseID}_male_$it" }
            val expectedFemale = (0 until frameCount).map { "${exerciseID}_female_$it" }
            if (record.maleFrames != expectedMale || record.femaleFrames != expectedFemale) {
                return@forEach
            }

            val malePaths = expectedMale.map { "$it.svg" }
            val femalePaths = expectedFemale.map { "$it.svg" }
            if (packagedAssetNames != null &&
                !(malePaths + femalePaths).all(packagedAssetNames::contains)
            ) {
                return@forEach
            }

            if (entries.containsKey(exerciseID)) {
                duplicateIDs += exerciseID
            } else {
                entries[exerciseID] = GenderedExerciseSvgFrames(
                    male = malePaths,
                    female = femalePaths,
                    representativeFrameIndex = representative
                )
            }
        }
        duplicateIDs.forEach { entries.remove(it) }
        return entries
    }

    fun resolve(
        item: ExerciseItem,
        gender: Gender,
        svgFrames: Map<String, GenderedExerciseSvgFrames>
    ): ExerciseVisual {
        val vectors = svgFrames[item.id]?.forGender(gender)
        return if (vectors.isNullOrEmpty()) {
            ExerciseVisual.jpeg(item.imagePaths)
        } else {
            ExerciseVisual(
                framePaths = vectors,
                format = ExerciseVisualFormat.SVG,
                representativeFrameIndex = svgFrames.getValue(item.id).representativeFrameIndex
            )
        }
    }
}
