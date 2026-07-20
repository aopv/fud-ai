package com.apoorvdarshan.calorietracker.models

import com.apoorvdarshan.calorietracker.data.ExerciseItem
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.util.Locale
import java.util.UUID
import kotlin.math.ceil
import kotlin.math.roundToInt

@Serializable
enum class WorkoutTabMode {
    LIBRARY,
    LOG;

    companion object {
        val Default: WorkoutTabMode = LOG
    }
}

@Serializable
enum class WorkoutWeightUnit(val storageValue: String) {
    KG("kg"),
    LBS("lbs");

    companion object {
        fun fromStorage(value: String?): WorkoutWeightUnit =
            entries.firstOrNull { it.storageValue == value } ?: LBS
    }
}

object WorkoutDate {
    fun key(date: LocalDate): String = date.toString()

    fun parse(key: String): LocalDate? = runCatching { LocalDate.parse(key) }.getOrNull()

    fun requireKey(key: String): String =
        requireNotNull(parse(key)) { "Invalid workout date key: $key" }.toString()
}

@Serializable
enum class WorkoutRpeScale {
    STRENGTH,
    CR10,
    BORG;

    val title: String
        get() = when (this) {
            STRENGTH -> "Strength 1–10"
            CR10 -> "CR10 0–10"
            BORG -> "Borg 6–20"
        }

    val shortTitle: String
        get() = when (this) {
            STRENGTH -> "1–10"
            CR10 -> "CR10"
            BORG -> "Borg"
        }

    val inputPlaceholder: String
        get() = when (this) {
            STRENGTH -> "1–10"
            CR10 -> "0–10"
            BORG -> "6–20"
        }

    val allowsDecimalInput: Boolean get() = this != BORG

    val inputRange: ClosedFloatingPointRange<Double>
        get() = when (this) {
            STRENGTH -> 1.0..10.0
            CR10 -> 0.0..10.0
            BORG -> 6.0..20.0
        }

    /**
     * Matches iOS's in-progress RPE sanitizer, including values such as `7.`
     * while the user is still typing and a single fractional digit where valid.
     */
    fun sanitize(proposedValue: String, previousValue: String = ""): String {
        val normalized = proposedValue.trim().replace(',', '.')
        if (normalized.isEmpty()) return ""

        val filtered = StringBuilder()
        var hasDecimal = false
        var fractionalDigits = 0
        for (character in normalized) {
            when {
                character.isDigit() -> {
                    if (hasDecimal) {
                        if (!allowsDecimalInput || fractionalDigits >= 1) continue
                        fractionalDigits += 1
                    }
                    filtered.append(character)
                }
                character == '.' && allowsDecimalInput && !hasDecimal && filtered.isNotEmpty() -> {
                    hasDecimal = true
                    filtered.append(character)
                }
            }
        }
        if (filtered.isEmpty()) return previousValue

        val result = filtered.toString()
        val numericText = result.removeSuffix(".")
        val value = numericText.toDoubleOrNull() ?: return previousValue
        if (value > inputRange.endInclusive) return inputRange.endInclusive.toInt().toString()
        if (value < inputRange.start && !isPossibleRangePrefix(result)) return previousValue
        return result
    }

    private fun isPossibleRangePrefix(value: String): Boolean {
        val integerPrefix = value.substringBefore('.')
        if (integerPrefix.isEmpty()) return false
        val lower = ceil(inputRange.start).toInt()
        val upper = inputRange.endInclusive.toInt()
        return (lower..upper).any { it.toString().startsWith(integerPrefix) }
    }
}

@Serializable
enum class WorkoutSplit {
    PUSH_PULL_LEGS,
    UPPER_LOWER,
    BODY_PART,
    ARNOLD,
    PUSH_PULL,
    ANTAGONIST,
    HYBRID,
    FULL_BODY,
    CUSTOM;

    val title: String
        get() = when (this) {
            PUSH_PULL_LEGS -> "Push / Pull / Legs"
            UPPER_LOWER -> "Upper / Lower"
            BODY_PART -> "Body-part split"
            ARNOLD -> "Arnold split"
            PUSH_PULL -> "Push / Pull"
            ANTAGONIST -> "Antagonist split"
            HYBRID -> "Hybrid split"
            FULL_BODY -> "Full body"
            CUSTOM -> "Custom"
        }

    companion object {
        val SelectableValues: List<WorkoutSplit> = listOf(
            FULL_BODY,
            UPPER_LOWER,
            PUSH_PULL_LEGS,
            BODY_PART,
            ARNOLD,
            PUSH_PULL,
            ANTAGONIST,
            HYBRID
        )
    }
}

@Serializable
enum class WorkoutIssue(val title: String) {
    SHOULDER("Shoulder"),
    ELBOW("Elbow"),
    WRIST("Wrist"),
    LOWER_BACK("Lower back"),
    HIP("Hip"),
    KNEE("Knee"),
    ANKLE("Ankle"),
    OTHER("Other")
}

@Serializable
data class WorkoutStrengthNumbers(
    val benchPressKg: Double? = null,
    val squatKg: Double? = null,
    val deadliftKg: Double? = null,
    val overheadPressKg: Double? = null
)

@Serializable
data class WorkoutPreferences(
    val targetMuscles: Set<String> = emptySet(),
    val issues: Set<WorkoutIssue> = emptySet(),
    val additionalIssues: String = "",
    val frequencyDays: Int = 3,
    val durationMinutes: Int = 60,
    val split: WorkoutSplit = WorkoutSplit.FULL_BODY,
    val customSplit: String = "",
    val equipment: Set<String> = emptySet(),
    val rpeScale: WorkoutRpeScale = WorkoutRpeScale.STRENGTH,
    val strength: WorkoutStrengthNumbers = WorkoutStrengthNumbers()
) {
    /** Keeps legacy fields decodable while enforcing the final selectable settings. */
    fun sanitized(): WorkoutPreferences = copy(
        additionalIssues = additionalIssues.trim().takeIf { WorkoutIssue.OTHER in issues }.orEmpty(),
        frequencyDays = frequencyDays.coerceIn(1, 7),
        split = if (split == WorkoutSplit.CUSTOM) WorkoutSplit.FULL_BODY else split,
        customSplit = "",
        strength = WorkoutStrengthNumbers(
            benchPressKg = validLoad(strength.benchPressKg),
            squatKg = validLoad(strength.squatKg),
            deadliftKg = validLoad(strength.deadliftKg),
            overheadPressKg = validLoad(strength.overheadPressKg)
        )
    )

    private fun validLoad(value: Double?): Double? =
        value?.takeIf { it.isFinite() && it > 0.0 }
}

@Serializable
data class PlannedSet(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val weight: String = "",
    val weightUnit: WorkoutWeightUnit? = null,
    val reps: String = "",
    val rpe: String = "",
    val rpeScale: WorkoutRpeScale? = null
) {
    val hasLoggedValue: Boolean
        get() = weight.isNotBlank() || reps.isNotBlank() || rpe.isNotBlank()

    fun blankCopy(carryingWeight: Boolean = false): PlannedSet = PlannedSet(
        weight = if (carryingWeight) weight else "",
        weightUnit = if (carryingWeight) weightUnit else null
    )

    fun displayWeight(targetUnit: WorkoutWeightUnit): String {
        val sourceUnit = weightUnit ?: return weight
        val numericWeight = weight.replace(',', '.').toDoubleOrNull()
            ?.takeIf { it.isFinite() } ?: return weight
        if (sourceUnit == targetUnit) return weight

        val poundsPerKilogram = 2.204_622_621_8
        val converted = if (sourceUnit == WorkoutWeightUnit.KG) {
            numericWeight * poundsPerKilogram
        } else {
            numericWeight / poundsPerKilogram
        }
        return String.format(Locale.US, "%.2f", converted)
            .trimEnd('0')
            .trimEnd('.')
    }
}

@Serializable
data class PlannedExercise(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val itemId: String,
    val name: String,
    val level: String,
    val imagePaths: List<String>,
    val force: String,
    val mechanic: String,
    val category: String,
    val equipment: String,
    val primaryMuscles: List<String>,
    val secondaryMuscles: List<String>,
    val instructions: List<String>,
    val sets: List<PlannedSet> = listOf(PlannedSet())
) {
    fun copiedForNewDay(): PlannedExercise = copy(
        id = UUID.randomUUID(),
        sets = listOf(PlannedSet())
    )

    fun asExerciseItem(): ExerciseItem = ExerciseItem(
        id = itemId,
        name = name,
        level = level,
        imagePaths = imagePaths,
        force = force,
        mechanic = mechanic,
        category = category,
        equipment = equipment,
        primaryMuscles = primaryMuscles,
        secondaryMuscles = secondaryMuscles,
        instructions = instructions
    )

    companion object {
        fun from(item: ExerciseItem): PlannedExercise = PlannedExercise(
            itemId = item.id,
            name = item.name,
            level = item.level,
            imagePaths = item.imagePaths,
            force = item.force,
            mechanic = item.mechanic,
            category = item.category,
            equipment = item.equipment,
            primaryMuscles = item.primaryMuscles,
            secondaryMuscles = item.secondaryMuscles,
            instructions = item.instructions
        )
    }
}

@Serializable
data class WorkoutDayPlan(
    val dateKey: String,
    val exercises: List<PlannedExercise> = emptyList()
)

@Serializable
data class CompletedSet(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val setNumber: Int,
    val weight: String,
    val weightUnit: WorkoutWeightUnit,
    val reps: String,
    val rpe: String,
    val rpeScale: WorkoutRpeScale? = null
) {
    /** A set is performed once reps were entered; load or RPE alone is incomplete. */
    val isPerformed: Boolean get() = reps.isNotEmpty()
}

@Serializable
data class CompletedExercise(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val itemId: String,
    val name: String,
    val targetMuscles: List<String>,
    val equipment: String,
    val sets: List<CompletedSet>
)

@Serializable
data class WorkoutSession(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val diaryDateKey: String,
    @Serializable(with = InstantSerializer::class)
    val startedAt: Instant,
    @Serializable(with = InstantSerializer::class)
    val completedAt: Instant,
    val durationSeconds: Int = 0,
    val exercises: List<CompletedExercise>,
    val caloriesBurned: Int? = null,
    val healthSyncVersion: Int? = null
) {
    val durationMinutes: Int get() = ceil(durationSeconds.coerceAtLeast(0) / 60.0).toInt()
    val exerciseCount: Int get() = exercises.size
    val performedSetCount: Int get() = exercises.sumOf { exercise -> exercise.sets.count { it.isPerformed } }
    val repCount: Int get() = exercises.sumOf { exercise -> exercise.sets.sumOf { it.reps.toIntOrNull() ?: 0 } }
}

@Serializable
data class WorkoutPersistedState(
    val version: Int = CurrentVersion,
    val dayPlans: Map<String, WorkoutDayPlan> = emptyMap(),
    val completedSessions: List<WorkoutSession> = emptyList(),
    val savedExerciseIds: Set<String> = emptySet(),
    val preferences: WorkoutPreferences = WorkoutPreferences(),
    val mode: WorkoutTabMode = WorkoutTabMode.Default,
    /**
     * Pending deletes double as tombstones so a health restore cannot resurrect them.
     * The date key is retained because Health Connect deletion is scoped by stable id + day.
     */
    val healthDeletionTombstones: Map<String, String> = emptyMap(),
    /** Deletes awaiting Health Connect confirmation; tombstones outlive a successful write
     * until a subsequent owned-record read proves the sample is no longer visible. */
    val pendingHealthDeleteIds: Set<String> = emptySet(),
    /** Failed/deferred health writes can be retried without losing local calculations. */
    val pendingHealthUpsertIds: Set<String> = emptySet()
) {
    fun sanitized(): WorkoutPersistedState = if (version != CurrentVersion) {
        WorkoutPersistedState()
    } else {
        copy(preferences = preferences.sanitized())
    }

    companion object {
        const val CurrentVersion = 1
    }
}

data class WorkoutBurnEstimate(
    val calories: Int,
    val performedSetCount: Int,
    val repCount: Int
)

/** Exact offline port of iOS `StrengthWorkoutBurnEstimator`. */
object WorkoutBurnEstimator {
    fun estimate(
        exercises: List<PlannedExercise>,
        bodyWeightKg: Double,
        defaultWeightUnit: WorkoutWeightUnit,
        defaultRpeScale: WorkoutRpeScale
    ): WorkoutBurnEstimate? {
        val safeBodyWeight = if (bodyWeightKg.isFinite()) bodyWeightKg.coerceIn(35.0, 300.0) else 70.0
        var performedSetCount = 0
        var repCount = 0
        var activeMinutes = 0.0
        var recoveryMinutes = 0.0
        var effortTotal = 0.0
        var relativeLoadTotal = 0.0
        var exercisesWithWork = 0

        for (exercise in exercises) {
            var performedInExercise = 0
            for (set in exercise.sets) {
                val rawReps = set.reps.toIntOrNull()?.takeIf { it > 0 } ?: continue
                val reps = rawReps.coerceAtMost(100)
                performedSetCount += 1
                performedInExercise += 1
                repCount += reps
                activeMinutes += (reps * 2.75 / 60.0).coerceIn(0.30, 1.50)
                recoveryMinutes += 1.60
                effortTotal += normalizedEffort(set.rpe, set.rpeScale ?: defaultRpeScale)
                relativeLoadTotal += relativeLoad(
                    text = set.weight,
                    unit = set.weightUnit ?: defaultWeightUnit,
                    bodyWeightKg = safeBodyWeight
                )
            }
            if (performedInExercise > 0) exercisesWithWork += 1
        }

        if (performedSetCount == 0) return null

        recoveryMinutes = (recoveryMinutes - 1.60).coerceAtLeast(0.0)
        val transitionMinutes = exercisesWithWork * 0.75
        val estimatedMinutes = (activeMinutes + recoveryMinutes + transitionMinutes).coerceAtLeast(4.0)
        val averageEffort = effortTotal / performedSetCount
        val averageRelativeLoad = relativeLoadTotal / performedSetCount
        val met = (3.8 + (2.4 * averageEffort) + (0.5 * averageRelativeLoad)).coerceIn(3.5, 8.0)
        val rawCalories = met * 3.5 * safeBodyWeight / 200.0 * estimatedMinutes

        return WorkoutBurnEstimate(
            calories = rawCalories.roundToInt().coerceIn(1, 5_000),
            performedSetCount = performedSetCount,
            repCount = repCount
        )
    }

    private fun normalizedEffort(text: String, scale: WorkoutRpeScale): Double {
        val value = text.replace(',', '.').toDoubleOrNull() ?: return 0.60
        val normalized = when (scale) {
            WorkoutRpeScale.STRENGTH -> (value - 1.0) / 9.0
            WorkoutRpeScale.CR10 -> value / 10.0
            WorkoutRpeScale.BORG -> (value - 6.0) / 14.0
        }
        return normalized.coerceIn(0.0, 1.0)
    }

    private fun relativeLoad(text: String, unit: WorkoutWeightUnit, bodyWeightKg: Double): Double {
        val value = text.toDoubleOrNull()?.takeIf { it.isFinite() && it > 0.0 } ?: return 0.0
        val kilograms = if (unit == WorkoutWeightUnit.KG) value else value / 2.204_622_621_8
        return (kilograms / bodyWeightKg).coerceIn(0.0, 2.0)
    }
}

data class WorkoutSplitGroup(
    val title: String,
    val muscles: Set<String>
) {
    companion object {
        fun groups(split: WorkoutSplit, availableMuscles: List<String>): List<WorkoutSplitGroup> {
            val namesByLowercase = availableMuscles.associateBy { it.lowercase() }
            fun matching(vararg candidates: String): Set<String> =
                candidates.mapNotNull { namesByLowercase[it.lowercase()] }.toSet()

            return when (split) {
                WorkoutSplit.PUSH_PULL_LEGS -> listOf(
                    WorkoutSplitGroup("Push", matching("Chest", "Shoulders", "Triceps")),
                    WorkoutSplitGroup("Pull", matching("Biceps", "Forearms", "Lats", "Middle Back", "Traps", "Neck")),
                    WorkoutSplitGroup("Legs", matching("Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Lower Back", "Quadriceps")),
                    WorkoutSplitGroup("Core", matching("Abdominals"))
                )
                WorkoutSplit.UPPER_LOWER -> listOf(
                    WorkoutSplitGroup("Upper", matching("Biceps", "Chest", "Forearms", "Lats", "Middle Back", "Neck", "Shoulders", "Traps", "Triceps")),
                    WorkoutSplitGroup("Lower", matching("Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Lower Back", "Quadriceps")),
                    WorkoutSplitGroup("Core", matching("Abdominals"))
                )
                WorkoutSplit.BODY_PART -> listOf(
                    WorkoutSplitGroup("Chest", matching("Chest")),
                    WorkoutSplitGroup("Back", matching("Lats", "Middle Back", "Lower Back", "Traps")),
                    WorkoutSplitGroup("Shoulders", matching("Shoulders", "Traps")),
                    WorkoutSplitGroup("Arms", matching("Biceps", "Triceps", "Forearms")),
                    WorkoutSplitGroup("Legs", matching("Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Quadriceps")),
                    WorkoutSplitGroup("Core", matching("Abdominals"))
                )
                WorkoutSplit.ARNOLD -> listOf(
                    WorkoutSplitGroup("Chest + Back", matching("Chest", "Lats", "Middle Back", "Lower Back", "Traps")),
                    WorkoutSplitGroup("Shoulders + Arms", matching("Shoulders", "Biceps", "Triceps", "Forearms", "Neck")),
                    WorkoutSplitGroup("Legs", matching("Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Quadriceps")),
                    WorkoutSplitGroup("Core", matching("Abdominals"))
                )
                WorkoutSplit.PUSH_PULL -> listOf(
                    WorkoutSplitGroup("Push", matching("Chest", "Shoulders", "Triceps", "Quadriceps", "Calves")),
                    WorkoutSplitGroup("Pull", matching("Biceps", "Forearms", "Lats", "Middle Back", "Traps", "Glutes", "Hamstrings", "Lower Back")),
                    WorkoutSplitGroup("Accessory/Core", matching("Abdominals", "Abductors", "Adductors", "Neck"))
                )
                WorkoutSplit.ANTAGONIST -> listOf(
                    WorkoutSplitGroup("Chest + Back", matching("Chest", "Lats", "Middle Back", "Lower Back", "Traps")),
                    WorkoutSplitGroup("Biceps + Triceps", matching("Biceps", "Triceps", "Forearms")),
                    WorkoutSplitGroup("Quads + Hamstrings/Glutes", matching("Quadriceps", "Hamstrings", "Glutes")),
                    WorkoutSplitGroup("Shoulders + Lats/Traps", matching("Shoulders", "Lats", "Traps")),
                    WorkoutSplitGroup("Core/Accessory", matching("Abdominals", "Abductors", "Adductors", "Calves", "Neck"))
                )
                WorkoutSplit.HYBRID -> listOf(
                    WorkoutSplitGroup("Strength/Compound", matching("Chest", "Lats", "Middle Back", "Lower Back", "Glutes", "Hamstrings", "Quadriceps", "Shoulders", "Traps")),
                    WorkoutSplitGroup("Accessory/Hypertrophy", matching("Biceps", "Triceps", "Forearms", "Calves", "Abductors", "Adductors", "Abdominals", "Neck"))
                )
                WorkoutSplit.FULL_BODY, WorkoutSplit.CUSTOM -> emptyList()
            }
        }

        fun selectionGroups(
            split: WorkoutSplit,
            availablePrimaryMuscles: List<String>,
            availableSecondaryMuscles: List<String>
        ): List<WorkoutSplitGroup> {
            val available = (availablePrimaryMuscles + availableSecondaryMuscles).toSet().sorted()
            val configured = groups(split, available).filter { it.muscles.isNotEmpty() }
            return configured.ifEmpty { available.map { WorkoutSplitGroup(it, setOf(it)) } }
        }
    }
}
