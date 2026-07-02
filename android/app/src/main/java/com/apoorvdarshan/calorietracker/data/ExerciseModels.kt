package com.apoorvdarshan.calorietracker.data

/** Raw record as stored in exercises.json (free-exercise-db schema). */
data class ExerciseRecord(
    val id: String = "",
    val name: String = "",
    val force: String? = null,
    val level: String? = null,
    val mechanic: String? = null,
    val equipment: String? = null,
    val primaryMuscles: List<String> = emptyList(),
    val secondaryMuscles: List<String> = emptyList(),
    val instructions: List<String> = emptyList(),
    val category: String? = null,
    val images: List<String> = emptyList()
)

/** Domain model mirroring the iOS `ExerciseLibraryItem`. */
data class ExerciseItem(
    val id: String,
    val name: String,
    val level: String,
    val imagePaths: List<String>,
    val force: String,
    val mechanic: String,
    val category: String,
    val equipment: String,
    val primaryMuscles: List<String>,
    val secondaryMuscles: List<String>,
    val instructions: List<String>
) {
    val primaryMusclesTitle: String
        get() = if (primaryMuscles.isEmpty()) "Unspecified" else primaryMuscles.joinToString(", ")

    val secondaryMusclesTitle: String
        get() = if (secondaryMuscles.isEmpty()) "None" else secondaryMuscles.joinToString(", ")

    val databaseMetadataSummary: String
        get() {
            val parts = listOf(category, force, mechanic).filter { it != "Unspecified" }
            return if (parts.isEmpty()) "Database metadata" else parts.joinToString(" - ")
        }

    /** Lowercased haystack for free-text search (precomputed once). */
    val searchableText: String by lazy(LazyThreadSafetyMode.NONE) {
        buildList {
            add(name)
            add(level)
            add(force)
            add(mechanic)
            add(category)
            add(equipment)
            add(primaryMuscles.joinToString(" "))
            add(secondaryMuscles.joinToString(" "))
            add(instructions.joinToString(" "))
        }.joinToString(" ").lowercase()
    }

    companion object {
        fun from(record: ExerciseRecord): ExerciseItem? {
            val id = record.id.trim()
            val name = record.name.trim()
            if (id.isEmpty() || name.isEmpty()) return null
            return ExerciseItem(
                id = id,
                name = name,
                level = metadataTitle(record.level),
                imagePaths = record.images,
                force = metadataTitle(record.force),
                mechanic = metadataTitle(record.mechanic),
                category = metadataTitle(record.category),
                equipment = metadataTitle(record.equipment),
                primaryMuscles = metadataTitles(record.primaryMuscles),
                secondaryMuscles = metadataTitles(record.secondaryMuscles),
                instructions = record.instructions.map { it.trim() }.filter { it.isNotEmpty() }
            )
        }

        private fun metadataTitles(values: List<String>): List<String> =
            values.map { metadataTitle(it) }.filter { it != "Unspecified" }

        /** Title-cases a metadata token (splitting on spaces and hyphens), or "Unspecified". */
        fun metadataTitle(value: String?): String {
            val trimmed = value?.trim().orEmpty()
            if (trimmed.isEmpty()) return "Unspecified"
            // Split on runs of whitespace (drops empties) to match Swift's split(separator:" ").
            return trimmed.split(Regex("\\s+")).joinToString(" ") { word ->
                word.split("-").joinToString("-") { segment ->
                    if (segment.isEmpty()) {
                        ""
                    } else {
                        segment.first().uppercase() + segment.drop(1).lowercase()
                    }
                }
            }
        }
    }
}

/** Sort options, mirroring iOS `ExerciseLibrarySort`. */
enum class ExerciseSort(val titleRes: Int) {
    NAME(com.apoorvdarshan.calorietracker.R.string.label_name),
    LEVEL(com.apoorvdarshan.calorietracker.R.string.label_level),
    PRIMARY(com.apoorvdarshan.calorietracker.R.string.label_primary),
    SECONDARY(com.apoorvdarshan.calorietracker.R.string.label_secondary),
    CATEGORY(com.apoorvdarshan.calorietracker.R.string.label_category),
    FORCE(com.apoorvdarshan.calorietracker.R.string.label_force),
    MECHANIC(com.apoorvdarshan.calorietracker.R.string.label_mechanic),
    EQUIPMENT(com.apoorvdarshan.calorietracker.R.string.label_equipment)
}
