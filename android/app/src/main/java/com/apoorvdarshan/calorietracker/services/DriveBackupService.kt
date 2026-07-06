package com.apoorvdarshan.calorietracker.services

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.apoorvdarshan.calorietracker.data.BodyFatRepository
import com.apoorvdarshan.calorietracker.data.BodyMeasurementRepository
import com.apoorvdarshan.calorietracker.data.ChatRepository
import com.apoorvdarshan.calorietracker.data.FoodRepository
import com.apoorvdarshan.calorietracker.data.PreferencesStore
import com.apoorvdarshan.calorietracker.data.ProfileRepository
import com.apoorvdarshan.calorietracker.data.WeightRepository
import com.apoorvdarshan.calorietracker.models.BodyFatEntry
import com.apoorvdarshan.calorietracker.models.BodyMeasurement
import com.apoorvdarshan.calorietracker.models.ChatMessage
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.OptionalNutrientGoals
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.models.WeightEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.security.MessageDigest
import java.time.Instant

/**
 * Everything worth keeping if the phone dies, minus photos. Food photos and
 * Coach image attachments are deliberately excluded — they dominate the size
 * and add nothing to a restore. Entry UUIDs are preserved, so a Drive restore
 * and the Health Connect restore merge cleanly instead of duplicating, and
 * Health Connect edits/deletes keep targeting the right records afterwards.
 * Sibling of the iOS BackupSnapshot (formats differ per platform's encoders).
 */
@Serializable
data class BackupSnapshot(
    val version: Int = 1,
    val createdAtEpochMillis: Long,
    val foodEntries: List<FoodEntry>,
    val favorites: List<FoodEntry>,
    val weightEntries: List<WeightEntry>,
    val bodyFatEntries: List<BodyFatEntry>,
    val bodyMeasurements: List<BodyMeasurement>,
    val chatMessages: List<ChatMessage>,
    val profile: UserProfile?,
    val optionalNutrientGoals: OptionalNutrientGoals?,
    /** Simple preference values keyed by their DataStore key name. Bools are
     *  stored as "true"/"false"; [applySettings] restores the right type. */
    val settings: Map<String, String>
)

/**
 * Folder-based cloud backup: the user picks a folder once (Google Drive in the
 * system picker — or any other provider), and the whole snapshot is a single
 * fudai-backup.json in it, overwritten on every backup. Snapshot semantics mean
 * deletions propagate naturally — an entry deleted in-app is simply absent from
 * the next backup. No Google sign-in, no OAuth, no servers of ours; the Drive
 * app uploads the file itself. API keys are NOT included in the snapshot.
 * Port of iOS CloudBackupService (which uses CloudKit instead of a folder).
 */
class DriveBackupService(
    private val context: Context,
    private val prefs: PreferencesStore,
    private val foodRepository: FoodRepository,
    private val weightRepository: WeightRepository,
    private val bodyFatRepository: BodyFatRepository,
    private val bodyMeasurementRepository: BodyMeasurementRepository,
    private val chatRepository: ChatRepository,
    private val profileRepository: ProfileRepository
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    sealed class RestoreResult {
        data object Success : RestoreResult()
        data object NoBackupFound : RestoreResult()
        data object Failed : RestoreResult()
    }

    /** Fire-and-forget hook for MainActivity.onStop — survives activity death
     *  because the write runs on this service's own application-lifetime scope. */
    fun scheduleBackup() {
        scope.launch { runCatching { backUp(force = false) } }
    }

    /** Uploads the current snapshot, skipping the disk write entirely when
     *  nothing changed since the last successful backup (content hash).
     *  Returns false when backups are off, the folder grant is gone, or the
     *  write failed. */
    suspend fun backUp(force: Boolean): Boolean {
        if (!prefs.driveBackupEnabled.first()) return false
        val folder = backupFolder() ?: return false

        var snapshot = buildSnapshot()
        // Hash with a fixed timestamp so the timestamp itself never counts as a change.
        val hash = sha256(json.encodeToString(BackupSnapshot.serializer(), snapshot.copy(createdAtEpochMillis = 0)))
        if (!force && hash == prefs.driveBackupLastHash.first()) return true

        snapshot = snapshot.copy(createdAtEpochMillis = Instant.now().toEpochMilli())
        val payload = json.encodeToString(BackupSnapshot.serializer(), snapshot)

        val file = folder.findFile(FILE_NAME)
            ?: folder.createFile("application/json", FILE_NAME)
            ?: return false
        val ok = runCatching {
            context.contentResolver.openOutputStream(file.uri, "wt")?.use {
                it.write(payload.toByteArray(Charsets.UTF_8))
            } ?: error("no output stream")
        }.isSuccess
        if (ok) {
            prefs.setDriveBackupLastHash(hash)
            prefs.setDriveBackupLastDate(Instant.now().toEpochMilli())
        }
        return ok
    }

    /** Reads the snapshot from the picked folder and merges it into the app.
     *  Merge is by UUID (backup wins for a same-id record — it can only be
     *  richer, never staler; anything logged after the backup has a new id and
     *  is untouched). Nothing here echoes back to Health Connect — the
     *  replaceAll paths bypass the per-entry write hooks; the records for
     *  backed-up entries already exist there. */
    suspend fun restore(): RestoreResult {
        val folder = backupFolder() ?: return RestoreResult.NoBackupFound
        val file = folder.findFile(FILE_NAME) ?: return RestoreResult.NoBackupFound
        val snapshot = runCatching {
            val text = context.contentResolver.openInputStream(file.uri)?.use {
                it.readBytes().toString(Charsets.UTF_8)
            } ?: return RestoreResult.Failed
            json.decodeFromString(BackupSnapshot.serializer(), text)
        }.getOrNull() ?: return RestoreResult.Failed

        val mergedFood = mergeById(foodRepository.entries.first(), snapshot.foodEntries) { it.id }
        foodRepository.replaceAll(mergedFood.sortedBy { it.timestamp })

        val existingFavorites = prefs.favoriteFoodEntries.first()
        val existingKeys = existingFavorites.map { it.favoriteKey }.toSet()
        val mergedFavorites = existingFavorites + snapshot.favorites.filter { it.favoriteKey !in existingKeys }
        if (mergedFavorites.size != existingFavorites.size) {
            prefs.setFavoriteFoodEntries(mergedFavorites)
            prefs.setFavoriteKeys(mergedFavorites.map { it.favoriteKey }.toSet())
        }

        weightRepository.replaceAll(mergeById(weightRepository.entries.first(), snapshot.weightEntries) { it.id }.sortedBy { it.date })
        bodyFatRepository.replaceAll(mergeById(bodyFatRepository.entries.first(), snapshot.bodyFatEntries) { it.id }.sortedBy { it.date })
        bodyMeasurementRepository.replaceAll(mergeById(bodyMeasurementRepository.entries.first(), snapshot.bodyMeasurements) { it.id }.sortedBy { it.date })

        val existingMessages = chatRepository.messages.first()
        val existingMessageIds = existingMessages.map { it.id }.toSet()
        val mergedMessages = (existingMessages + snapshot.chatMessages.filter { it.id !in existingMessageIds })
            .sortedBy { it.timestamp }
        chatRepository.replaceAll(mergedMessages)

        snapshot.profile?.let { profileRepository.save(it) }
        snapshot.optionalNutrientGoals?.let { prefs.setOptionalNutrientGoals(it) }
        applySettings(snapshot.settings)
        return RestoreResult.Success
    }

    private suspend fun buildSnapshot(): BackupSnapshot = BackupSnapshot(
        createdAtEpochMillis = 0,
        foodEntries = foodRepository.entries.first().map { it.copy(imageFilename = null) },
        favorites = prefs.favoriteFoodEntries.first().map { it.copy(imageFilename = null) },
        weightEntries = weightRepository.entries.first(),
        bodyFatEntries = bodyFatRepository.entries.first(),
        bodyMeasurements = bodyMeasurementRepository.entries.first(),
        chatMessages = chatRepository.messages.first().map { it.copy(attachmentImageBase64 = null) },
        profile = profileRepository.current(),
        optionalNutrientGoals = prefs.optionalNutrientGoals.first(),
        settings = buildMap {
            put(KEY_THEME, prefs.appThemeColor.first())
            put(KEY_APPEARANCE, prefs.appearanceMode.first())
            put(KEY_HEIGHT_UNIT, prefs.heightUnit.first())
            put(KEY_WEIGHT_UNIT, prefs.weightUnit.first())
            put(KEY_WEEK_MONDAY, prefs.weekStartsOnMonday.first().toString())
            put(KEY_SORT_ORDER, prefs.foodLogSortOrder.first())
            put(KEY_HOME_NUTRIENTS, prefs.homeTopNutrients.first())
            put(KEY_PREFER_GRAMS, prefs.preferGramsByDefault.first().toString())
            put(KEY_ADAPTIVE, prefs.adaptiveGoalsEnabled.first().toString())
            put(KEY_ENERGY, prefs.healthEnergyGoalsEnabled.first().toString())
        }
    )

    private suspend fun applySettings(settings: Map<String, String>) {
        settings[KEY_THEME]?.let { prefs.setAppThemeColor(it) }
        settings[KEY_APPEARANCE]?.let { prefs.setAppearanceMode(it) }
        settings[KEY_HEIGHT_UNIT]?.let { prefs.setHeightUnit(it) }
        settings[KEY_WEIGHT_UNIT]?.let { prefs.setWeightUnit(it) }
        settings[KEY_WEEK_MONDAY]?.let { prefs.setWeekStartsOnMonday(it.toBoolean()) }
        settings[KEY_SORT_ORDER]?.let { prefs.setFoodLogSortOrder(it) }
        settings[KEY_HOME_NUTRIENTS]?.let { prefs.setHomeTopNutrients(it) }
        settings[KEY_PREFER_GRAMS]?.let { prefs.setPreferGramsByDefault(it.toBoolean()) }
        settings[KEY_ADAPTIVE]?.let { prefs.setAdaptiveGoalsEnabled(it.toBoolean()) }
        settings[KEY_ENERGY]?.let { prefs.setHealthEnergyGoalsEnabled(it.toBoolean()) }
    }

    private fun <T, K> mergeById(existing: List<T>, backup: List<T>, id: (T) -> K): List<T> {
        val merged = LinkedHashMap<K, T>()
        existing.forEach { merged[id(it)] = it }
        backup.forEach { merged[id(it)] = it }
        return merged.values.toList()
    }

    /** The picked folder, or null when no folder was picked or the persisted
     *  grant was revoked (folder deleted, permission cleared in settings). */
    private suspend fun backupFolder(): DocumentFile? {
        val raw = prefs.driveBackupFolderUri.first() ?: return null
        val uri = runCatching { Uri.parse(raw) }.getOrNull() ?: return null
        val hasGrant = context.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        if (!hasGrant) return null
        val folder = DocumentFile.fromTreeUri(context, uri) ?: return null
        return if (folder.canWrite()) folder else null
    }

    private fun sha256(text: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(text.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }

    companion object {
        const val FILE_NAME = "fudai-backup.json"

        private const val KEY_THEME = "appThemeColor"
        private const val KEY_APPEARANCE = "appearanceMode"
        private const val KEY_HEIGHT_UNIT = "heightUnit"
        private const val KEY_WEIGHT_UNIT = "weightUnit"
        private const val KEY_WEEK_MONDAY = "weekStartsOnMonday"
        private const val KEY_SORT_ORDER = "foodLogSortOrder"
        private const val KEY_HOME_NUTRIENTS = "homeTopNutrients"
        private const val KEY_PREFER_GRAMS = "preferGramsByDefault"
        private const val KEY_ADAPTIVE = "adaptiveGoalsEnabled"
        private const val KEY_ENERGY = "healthEnergyGoalsEnabled"
    }
}
