package com.apoorvdarshan.calorietracker.services.health

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.MealType as HCMealType
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Percentage
import com.apoorvdarshan.calorietracker.models.BodyFatEntry
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.WeightEntry
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.UUID
import kotlin.math.roundToInt

/**
 * Single boundary for Health Connect I/O. Port of iOS HealthKitManager.
 *
 * Conventions:
 * - Each sample carries [Metadata.clientRecordId] = "fudai_<uuid>" so we can
 *   dedup in-app vs external writes and delete our own records cleanly.
 * - Nutrition records include macros plus every optional nutrient Health Connect
 *   can represent from Fud AI's food model.
 * - The "typesVersion" integer bumps when we add new record types so existing
 *   users get a re-authorization prompt.
 */
class HealthConnectManager(private val context: Context) {

    private val client: HealthConnectClient? by lazy {
        runCatching { HealthConnectClient.getOrCreate(context) }.getOrNull()
    }

    fun isAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    // Individual permission strings so each direction can be gated independently.
    // The old all-or-nothing gate meant a user who granted only READ (e.g. to pull
    // weigh-ins from a Withings scale) got no sync at all — see issue #91.
    private val weightRead = HealthPermission.getReadPermission(WeightRecord::class)
    private val weightWrite = HealthPermission.getWritePermission(WeightRecord::class)
    private val bodyFatRead = HealthPermission.getReadPermission(BodyFatRecord::class)
    private val bodyFatWrite = HealthPermission.getWritePermission(BodyFatRecord::class)
    private val nutritionRead = HealthPermission.getReadPermission(NutritionRecord::class)
    private val nutritionWrite = HealthPermission.getWritePermission(NutritionRecord::class)
    private val activeEnergyRead = HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class)
    private val totalEnergyRead = HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)

    val permissions: Set<String> = setOf(
        weightRead, weightWrite, nutritionRead, nutritionWrite,
        bodyFatRead, bodyFatWrite, activeEnergyRead, totalEnergyRead
    )

    private suspend fun granted(): Set<String> =
        runCatching { client?.permissionController?.getGrantedPermissions() }.getOrNull() ?: emptySet()

    /** The "connected" state: at least one Fud AI permission granted. Partial grants
     *  are valid — a read-only user still syncs the read direction. */
    suspend fun hasAnyPermission(): Boolean = granted().any { it in permissions }

    suspend fun hasWeightRead(): Boolean = weightRead in granted()
    suspend fun hasWeightWrite(): Boolean = weightWrite in granted()
    suspend fun hasBodyFatRead(): Boolean = bodyFatRead in granted()
    suspend fun hasBodyFatWrite(): Boolean = bodyFatWrite in granted()
    suspend fun hasNutritionRead(): Boolean = nutritionRead in granted()
    suspend fun hasNutritionWrite(): Boolean = nutritionWrite in granted()
    suspend fun hasEnergyRead(): Boolean = granted().let { activeEnergyRead in it && totalEnergyRead in it }

    /** One permission read snapshotting every capability — used by the read-sync coordinator. */
    suspend fun capabilities(): HealthCapabilities {
        val g = granted()
        return HealthCapabilities(
            weightRead = weightRead in g,
            weightWrite = weightWrite in g,
            bodyFatRead = bodyFatRead in g,
            bodyFatWrite = bodyFatWrite in g,
            nutritionRead = nutritionRead in g,
            nutritionWrite = nutritionWrite in g,
            energyRead = activeEnergyRead in g && totalEnergyRead in g
        )
    }

    /** True for records Fud AI itself wrote, so read-sync can tell them apart from
     *  external sources (change-token consumers skip them; the restore path keeps them). */
    fun isOwnRecord(clientRecordId: String?): Boolean =
        clientRecordId?.startsWith(CLIENT_PREFIX) == true

    /** The original in-app entry UUID embedded in one of our own clientRecordIds
     *  ("fudai_<uuid>"), or null for external/malformed tags. Restoring with the
     *  original id keeps future edits/deletes targeting the matching HC record. */
    fun ownRecordId(clientRecordId: String?): UUID? {
        if (clientRecordId == null || !clientRecordId.startsWith(CLIENT_PREFIX)) return null
        return runCatching { UUID.fromString(clientRecordId.removePrefix(CLIENT_PREFIX)) }.getOrNull()
    }

    /** Used to build the permission-request ActivityResultContract on the UI side. */
    fun permissionRequestContract() = PermissionController.createRequestPermissionResultContract()

    // -- Weight -----------------------------------------------------------

    suspend fun writeWeight(entry: WeightEntry): Boolean {
        val c = client ?: return false
        val record = WeightRecord(
            time = entry.date,
            zoneOffset = null,
            weight = Mass.kilograms(entry.weightKg),
            metadata = Metadata.manualEntry(clientRecordId = tag(entry.id))
        )
        return runCatching { c.insertRecords(listOf(record)) }.isSuccess
    }

    suspend fun deleteWeight(entryId: UUID): Boolean {
        val c = client ?: return false
        return runCatching {
            c.deleteRecords(
                recordType = WeightRecord::class,
                recordIdsList = emptyList(),
                clientRecordIdsList = listOf(tag(entryId))
            )
        }.isSuccess
    }

    suspend fun readWeights(from: Instant, to: Instant): List<ExternalWeight> {
        val c = client ?: return emptyList()
        val out = mutableListOf<ExternalWeight>()
        var pageToken: String? = null
        // readRecords returns one page (default 1000); follow pageToken so a large
        // history isn't silently truncated to the first page.
        do {
            val response = runCatching {
                c.readRecords(
                    ReadRecordsRequest(
                        recordType = WeightRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(from, to),
                        pageToken = pageToken
                    )
                )
            }.getOrNull() ?: break
            response.records.forEach {
                out.add(
                    ExternalWeight(
                        time = it.time,
                        weightKg = it.weight.inKilograms,
                        clientRecordId = it.metadata.clientRecordId,
                        recordId = it.metadata.id
                    )
                )
            }
            pageToken = response.pageToken
        } while (pageToken != null)
        return out
    }

    // -- Body fat ---------------------------------------------------------

    suspend fun writeBodyFat(entry: BodyFatEntry): Boolean {
        val c = client ?: return false
        val record = BodyFatRecord(
            time = entry.date,
            zoneOffset = null,
            // BodyFatRecord wants 0–100 percent, not a fraction.
            percentage = Percentage(entry.bodyFatFraction * 100),
            metadata = Metadata.manualEntry(clientRecordId = tag(entry.id))
        )
        return runCatching { c.insertRecords(listOf(record)) }.isSuccess
    }

    suspend fun deleteBodyFat(entryId: UUID): Boolean {
        val c = client ?: return false
        return runCatching {
            c.deleteRecords(
                recordType = BodyFatRecord::class,
                recordIdsList = emptyList(),
                clientRecordIdsList = listOf(tag(entryId))
            )
        }.isSuccess
    }

    suspend fun readBodyFats(from: Instant, to: Instant): List<ExternalBodyFat> {
        val c = client ?: return emptyList()
        val out = mutableListOf<ExternalBodyFat>()
        var pageToken: String? = null
        do {
            val response = runCatching {
                c.readRecords(
                    ReadRecordsRequest(
                        recordType = BodyFatRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(from, to),
                        pageToken = pageToken
                    )
                )
            }.getOrNull() ?: break
            response.records.forEach {
                out.add(
                    ExternalBodyFat(
                        time = it.time,
                        // Convert HC's 0–100 back to our 0–1 fraction convention.
                        bodyFatFraction = it.percentage.value / 100.0,
                        clientRecordId = it.metadata.clientRecordId,
                        recordId = it.metadata.id
                    )
                )
            }
            pageToken = response.pageToken
        } while (pageToken != null)
        return out
    }

    // -- Nutrition --------------------------------------------------------

    suspend fun writeNutrition(entry: FoodEntry): Boolean {
        val c = client ?: return false
        val start = entry.timestamp
        if (start.isAfter(Instant.now())) return false
        // Nutrition records need a non-zero duration or Health Connect rejects them; use 1 minute.
        val end = start.plusSeconds(60)
        return runCatching {
            val record = NutritionRecord(
                startTime = start,
                endTime = end,
                startZoneOffset = null,
                endZoneOffset = null,
                name = entry.name,
                mealType = mealTypeFor(entry.mealType),
                energy = Energy.kilocalories(entry.calories.toDouble()),
                protein = Mass.grams(entry.protein),
                totalCarbohydrate = Mass.grams(entry.carbs),
                totalFat = Mass.grams(entry.fat),
                dietaryFiber = entry.fiber?.let { Mass.grams(it) },
                sugar = entry.sugar?.let { Mass.grams(it) },
                saturatedFat = entry.saturatedFat?.let { Mass.grams(it) },
                monounsaturatedFat = entry.monounsaturatedFat?.let { Mass.grams(it) },
                polyunsaturatedFat = entry.polyunsaturatedFat?.let { Mass.grams(it) },
                transFat = entry.transFat?.let { Mass.grams(it) },
                cholesterol = entry.cholesterol?.let { Mass.milligrams(it) },
                sodium = entry.sodium?.let { Mass.milligrams(it) },
                potassium = entry.potassium?.let { Mass.milligrams(it) },
                calcium = entry.calcium?.let { Mass.milligrams(it) },
                iron = entry.iron?.let { Mass.milligrams(it) },
                magnesium = entry.magnesium?.let { Mass.milligrams(it) },
                zinc = entry.zinc?.let { Mass.milligrams(it) },
                vitaminA = entry.vitaminA?.let { Mass.micrograms(it) },
                vitaminC = entry.vitaminC?.let { Mass.milligrams(it) },
                vitaminD = entry.vitaminD?.let { Mass.micrograms(it) },
                vitaminB12 = entry.vitaminB12?.let { Mass.micrograms(it) },
                vitaminE = entry.vitaminE?.let { Mass.milligrams(it) },
                vitaminK = entry.vitaminK?.let { Mass.micrograms(it) },
                folate = entry.folate?.let { Mass.micrograms(it) },
                metadata = Metadata.manualEntry(clientRecordId = tag(entry.id))
            )
            c.insertRecords(listOf(record))
        }.isSuccess
    }

    suspend fun updateNutrition(entry: FoodEntry): Boolean {
        // Health Connect doesn't allow true updates across clientRecordIds; delete-then-write
        // preserves the UUID linkage.
        deleteNutrition(entry.id)
        return writeNutrition(entry)
    }

    suspend fun deleteNutrition(entryId: UUID): Boolean {
        val c = client ?: return false
        return runCatching {
            c.deleteRecords(
                recordType = NutritionRecord::class,
                recordIdsList = emptyList(),
                clientRecordIdsList = listOf(tag(entryId))
            )
        }.isSuccess
    }

    /** All NutritionRecords in the range, mapped back to Fud AI's units (the exact
     *  inverse of [writeNutrition]). Powers the food-log restore after a reinstall
     *  or new phone, where Health Connect data survives but app storage doesn't.
     *  Returns null when any page read fails (rate limit, binder error) so the
     *  caller can leave its one-shot flag unset and retry, instead of treating a
     *  partial read as the complete history. */
    suspend fun readNutrition(from: Instant, to: Instant): List<ExternalNutrition>? {
        val c = client ?: return null
        val out = mutableListOf<ExternalNutrition>()
        var pageToken: String? = null
        do {
            val response = runCatching {
                c.readRecords(
                    ReadRecordsRequest(
                        recordType = NutritionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(from, to),
                        pageToken = pageToken
                    )
                )
            }.getOrNull() ?: return null
            response.records.forEach {
                out.add(
                    ExternalNutrition(
                        time = it.startTime,
                        name = it.name,
                        mealType = mealTypeFrom(it.mealType),
                        calories = it.energy?.inKilocalories,
                        protein = it.protein?.inGrams,
                        carbs = it.totalCarbohydrate?.inGrams,
                        fat = it.totalFat?.inGrams,
                        fiber = it.dietaryFiber?.inGrams,
                        sugar = it.sugar?.inGrams,
                        saturatedFat = it.saturatedFat?.inGrams,
                        monounsaturatedFat = it.monounsaturatedFat?.inGrams,
                        polyunsaturatedFat = it.polyunsaturatedFat?.inGrams,
                        transFat = it.transFat?.inGrams,
                        cholesterol = it.cholesterol?.inMilligrams,
                        sodium = it.sodium?.inMilligrams,
                        potassium = it.potassium?.inMilligrams,
                        calcium = it.calcium?.inMilligrams,
                        iron = it.iron?.inMilligrams,
                        magnesium = it.magnesium?.inMilligrams,
                        zinc = it.zinc?.inMilligrams,
                        vitaminA = it.vitaminA?.inMicrograms,
                        vitaminC = it.vitaminC?.inMilligrams,
                        vitaminD = it.vitaminD?.inMicrograms,
                        vitaminB12 = it.vitaminB12?.inMicrograms,
                        vitaminE = it.vitaminE?.inMilligrams,
                        vitaminK = it.vitaminK?.inMicrograms,
                        folate = it.folate?.inMicrograms,
                        clientRecordId = it.metadata.clientRecordId
                    )
                )
            }
            pageToken = response.pageToken
        } while (pageToken != null)
        return out
    }

    // -- Energy burn summary --------------------------------------------

    suspend fun readRecentEnergySummary(days: Int = 14): HealthEnergySummary? {
        val c = client ?: return null
        val requestedDays = maxOf(3, days)
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        val daily = mutableListOf<DailyEnergy>()

        for (offset in requestedDays downTo 1) {
            val date = today.minusDays(offset.toLong())
            val start = date.atStartOfDay(zone).toInstant()
            val end = date.plusDays(1).atStartOfDay(zone).toInstant()
            val result = runCatching {
                c.aggregate(
                    AggregateRequest(
                        metrics = setOf(
                            ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL,
                            TotalCaloriesBurnedRecord.ENERGY_TOTAL
                        ),
                        timeRangeFilter = TimeRangeFilter.between(start, end)
                    )
                )
            }.getOrNull() ?: continue

            val active = result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0
            val total = result[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories?.takeIf { it > 0.0 }
            if (active + (total ?: 0.0) <= 0.0) continue
            daily.add(DailyEnergy(active = active, total = total))
        }

        if (daily.size < 3) return null

        val activeAverage = daily.sumOf { it.active } / daily.size
        val totalValues = daily.mapNotNull { it.total }
        val totalAverage = totalValues.takeIf { it.isNotEmpty() }?.let { values -> values.sum() / values.size }
        val basalAverage = totalAverage?.let { maxOf(0.0, it - activeAverage) }
        return HealthEnergySummary(
            activeAverageCalories = activeAverage.roundToInt(),
            basalAverageCalories = basalAverage?.roundToInt(),
            totalAverageCalories = totalAverage?.roundToInt(),
            daysUsed = daily.size,
            requestedDays = requestedDays
        )
    }

    // -- Change observation (external weight imports) --------------------

    /** Opaque token used to fetch incremental changes. Call once, persist, pass back later.
     *  Now watches both Weight and BodyFat records — a single token reflects upserts of either. */
    suspend fun getChangesToken(
        recordTypes: Set<kotlin.reflect.KClass<out androidx.health.connect.client.records.Record>> =
            setOf(WeightRecord::class, BodyFatRecord::class)
    ): String? {
        val c = client ?: return null
        if (recordTypes.isEmpty()) return null
        return runCatching {
            c.getChangesToken(
                androidx.health.connect.client.request.ChangesTokenRequest(recordTypes = recordTypes)
            )
        }.getOrNull()
    }

    /** Returns observed external weight upserts since [sinceToken] plus the next token to use.
     *  Returns null when the token is expired or invalid so the caller re-backfills from scratch
     *  (an expired token is a *successful* response with changesTokenExpired=true, not an exception). */
    suspend fun consumeWeightChanges(sinceToken: String): Pair<List<ExternalWeight>, String?>? {
        val c = client ?: return null
        val results = mutableListOf<ExternalWeight>()
        var token = sinceToken
        // getChanges returns one page; drain hasMore so we don't truncate a large backlog.
        while (true) {
            val changes = runCatching { c.getChanges(token) }.getOrNull() ?: return null
            if (changes.changesTokenExpired) return null
            changes.changes.filterIsInstance<UpsertionChange>().forEach { change ->
                val rec = change.record as? WeightRecord ?: return@forEach
                // Skip samples we wrote ourselves (prefix matches our tag).
                val cid = rec.metadata.clientRecordId
                if (cid != null && cid.startsWith(CLIENT_PREFIX)) return@forEach
                results.add(
                    ExternalWeight(
                        time = rec.time,
                        weightKg = rec.weight.inKilograms,
                        clientRecordId = cid,
                        recordId = rec.metadata.id
                    )
                )
            }
            token = changes.nextChangesToken
            if (!changes.hasMore) break
        }
        return results to token
    }

    /** Sibling of [consumeWeightChanges] for BodyFat records. The combined
     *  changes-token watches both record types, so callers should drain both
     *  consumers using the SAME nextChangesToken returned by either call.
     *  We expose them as separate functions only to keep each result strongly typed. */
    suspend fun consumeBodyFatChanges(sinceToken: String): Pair<List<ExternalBodyFat>, String?>? {
        val c = client ?: return null
        val results = mutableListOf<ExternalBodyFat>()
        var token = sinceToken
        while (true) {
            val changes = runCatching { c.getChanges(token) }.getOrNull() ?: return null
            if (changes.changesTokenExpired) return null
            changes.changes.filterIsInstance<UpsertionChange>().forEach { change ->
                val rec = change.record as? BodyFatRecord ?: return@forEach
                val cid = rec.metadata.clientRecordId
                if (cid != null && cid.startsWith(CLIENT_PREFIX)) return@forEach
                results.add(
                    ExternalBodyFat(
                        time = rec.time,
                        bodyFatFraction = rec.percentage.value / 100.0,
                        clientRecordId = cid,
                        recordId = rec.metadata.id
                    )
                )
            }
            token = changes.nextChangesToken
            if (!changes.hasMore) break
        }
        return results to token
    }

    private fun tag(id: UUID): String = "$CLIENT_PREFIX${id}"

    private fun mealTypeFor(meal: com.apoorvdarshan.calorietracker.models.MealType): Int = when (meal) {
        com.apoorvdarshan.calorietracker.models.MealType.BREAKFAST -> HCMealType.MEAL_TYPE_BREAKFAST
        com.apoorvdarshan.calorietracker.models.MealType.LUNCH -> HCMealType.MEAL_TYPE_LUNCH
        com.apoorvdarshan.calorietracker.models.MealType.DINNER -> HCMealType.MEAL_TYPE_DINNER
        com.apoorvdarshan.calorietracker.models.MealType.SNACK -> HCMealType.MEAL_TYPE_SNACK
        com.apoorvdarshan.calorietracker.models.MealType.OTHER -> HCMealType.MEAL_TYPE_UNKNOWN
    }

    private fun mealTypeFrom(hcMealType: Int): com.apoorvdarshan.calorietracker.models.MealType = when (hcMealType) {
        HCMealType.MEAL_TYPE_BREAKFAST -> com.apoorvdarshan.calorietracker.models.MealType.BREAKFAST
        HCMealType.MEAL_TYPE_LUNCH -> com.apoorvdarshan.calorietracker.models.MealType.LUNCH
        HCMealType.MEAL_TYPE_DINNER -> com.apoorvdarshan.calorietracker.models.MealType.DINNER
        HCMealType.MEAL_TYPE_SNACK -> com.apoorvdarshan.calorietracker.models.MealType.SNACK
        else -> com.apoorvdarshan.calorietracker.models.MealType.OTHER
    }

    companion object {
        private const val CLIENT_PREFIX = "fudai_"

        /** Bump this when we add a new record type so users re-auth.
         *  v2 = added BodyFatRecord read+write permissions.
         *  v3 = added energy burn read permissions.
         *  v4 = added NutritionRecord read permission (food-log restore). */
        const val CURRENT_TYPES_VERSION = 4
    }
}

private data class DailyEnergy(
    val active: Double,
    val total: Double?
)

data class HealthCapabilities(
    val weightRead: Boolean,
    val weightWrite: Boolean,
    val bodyFatRead: Boolean,
    val bodyFatWrite: Boolean,
    val nutritionRead: Boolean,
    val nutritionWrite: Boolean,
    val energyRead: Boolean
)

/** A NutritionRecord read back from Health Connect in Fud AI's own units —
 *  kcal for energy, grams/milligrams/micrograms per nutrient, matching
 *  [HealthConnectManager.writeNutrition]. */
data class ExternalNutrition(
    val time: Instant,
    val name: String?,
    val mealType: com.apoorvdarshan.calorietracker.models.MealType,
    val calories: Double?,
    val protein: Double?,
    val carbs: Double?,
    val fat: Double?,
    val fiber: Double?,
    val sugar: Double?,
    val saturatedFat: Double?,
    val monounsaturatedFat: Double?,
    val polyunsaturatedFat: Double?,
    val transFat: Double?,
    val cholesterol: Double?,
    val sodium: Double?,
    val potassium: Double?,
    val calcium: Double?,
    val iron: Double?,
    val magnesium: Double?,
    val zinc: Double?,
    val vitaminA: Double?,
    val vitaminC: Double?,
    val vitaminD: Double?,
    val vitaminB12: Double?,
    val vitaminE: Double?,
    val vitaminK: Double?,
    val folate: Double?,
    val clientRecordId: String?
)

data class ExternalWeight(
    val time: Instant,
    val weightKg: Double,
    val clientRecordId: String?,
    /** Stable Health Connect record id (Metadata.id) — used as the dedup key when the
     *  source set no clientRecordId, so in-place value edits update rather than duplicate. */
    val recordId: String = ""
) {
    @Suppress("unused")
    val zoneOffset: ZoneOffset? get() = null
}

data class ExternalBodyFat(
    val time: Instant,
    /** 0–1 fraction, matching UserProfile.bodyFatPercentage convention. */
    val bodyFatFraction: Double,
    val clientRecordId: String?,
    /** Stable Health Connect record id (Metadata.id) — see [ExternalWeight.recordId]. */
    val recordId: String = ""
)

data class HealthEnergySummary(
    val activeAverageCalories: Int,
    val basalAverageCalories: Int?,
    val totalAverageCalories: Int?,
    val daysUsed: Int,
    val requestedDays: Int
)
