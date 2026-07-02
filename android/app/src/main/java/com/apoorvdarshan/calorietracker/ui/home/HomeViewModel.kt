package com.apoorvdarshan.calorietracker.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.HomeTopNutrient
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.OptionalNutrientGoals
import com.apoorvdarshan.calorietracker.models.PendingFoodAnalysisDraft
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.services.FoodImageComposer
import com.apoorvdarshan.calorietracker.services.OpenFoodFactsService
import com.apoorvdarshan.calorietracker.services.ai.AiError
import com.apoorvdarshan.calorietracker.services.ai.FoodAnalysis
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import kotlin.math.roundToInt

enum class FoodLogSortOrder(val storageValue: String, val displayName: String) {
    STANDARD("standard", "Breakfast → Lunch → Dinner"),
    LATEST_MEALS_FIRST("latestMealsFirst", "Latest Meals First");

    companion object {
        fun fromStorage(value: String?): FoodLogSortOrder =
            values().firstOrNull { it.storageValue == value } ?: STANDARD
    }
}

data class HomeUiState(
    val date: LocalDate = LocalDate.now(),
    val profile: UserProfile? = null,
    val todayEntries: List<FoodEntry> = emptyList(),
    val homeTopNutrients: List<HomeTopNutrient> = HomeTopNutrient.DefaultSelection,
    val optionalNutrientGoals: OptionalNutrientGoals = OptionalNutrientGoals.Default,
    val foodLogSortOrder: FoodLogSortOrder = FoodLogSortOrder.STANDARD,
    val preferGramsByDefault: Boolean = false,
    val weightMetric: Boolean = true,
    val favoriteKeys: Set<String> = emptySet(),
    val pendingAnalysis: FoodAnalysis? = null,
    val pendingImageBytes: ByteArray? = null,
    val pendingFoodSource: FoodSource? = null,
    val pendingDraftImageFilename: String? = null,
    /**
     * Set when the pendingAnalysis came from a Saved Meals tap (Recents /
     * Frequent / Favorites) instead of a fresh AI analysis. We keep the
     * original entry so saveAnalysis can reuse its imageFilename instead of
     * re-storing the image bytes as a new file on disk.
     */
    val pendingReviewSource: FoodEntry? = null,
    val analyzing: Boolean = false,
    val error: String? = null
) {
    val caloriesToday: Int get() = todayEntries.sumOf { it.calories }
    val proteinToday: Double get() = todayEntries.sumOf { it.protein }
    val carbsToday: Double get() = todayEntries.sumOf { it.carbs }
    val fatToday: Double get() = todayEntries.sumOf { it.fat }
    fun isFavorite(entry: FoodEntry): Boolean = entry.favoriteKey in favoriteKeys
}

class HomeViewModel(private val container: AppContainer) : ViewModel() {
    private val _ui = MutableStateFlow(HomeUiState())
    val ui: StateFlow<HomeUiState> = _ui.asStateFlow()
    private val _selectedDate = MutableStateFlow(LocalDate.now())

    init {
        combine(
            container.profileRepository.profile,
            container.foodRepository.entries,
            container.foodRepository.favoriteKeys,
            container.prefs.foodLogSortOrder,
            _selectedDate
        ) { p, entries, favKeys, sortOrder, day ->
            val zone = ZoneId.systemDefault()
            val dayEntries = entries
                .filter { it.timestamp.atZone(zone).toLocalDate() == day }
                .sortedByDescending { it.timestamp }
            _ui.value.copy(
                profile = p,
                date = day,
                todayEntries = dayEntries,
                foodLogSortOrder = FoodLogSortOrder.fromStorage(sortOrder),
                favoriteKeys = favKeys
            )
        }
            .onEach { _ui.value = it }
            .launchIn(viewModelScope)

        container.prefs.homeTopNutrients
            .onEach { raw ->
                _ui.value = _ui.value.copy(homeTopNutrients = HomeTopNutrient.fromStorage(raw))
            }
            .launchIn(viewModelScope)

        container.prefs.optionalNutrientGoals
            .onEach { goals ->
                _ui.value = _ui.value.copy(optionalNutrientGoals = goals)
            }
            .launchIn(viewModelScope)

        container.prefs.preferGramsByDefault
            .onEach { preferGrams ->
                _ui.value = _ui.value.copy(preferGramsByDefault = preferGrams)
            }
            .launchIn(viewModelScope)

        container.prefs.weightUnit
            .onEach { unit ->
                _ui.value = _ui.value.copy(weightMetric = unit == "kg")
            }
            .launchIn(viewModelScope)

        viewModelScope.launch {
            container.prefs.pendingFoodAnalysisDraft.first()?.let { restorePendingDraft(it) }
        }
    }

    fun setSelectedDate(date: LocalDate) {
        _selectedDate.value = date
    }

    fun setFoodLogSortOrder(order: FoodLogSortOrder) {
        viewModelScope.launch {
            container.prefs.setFoodLogSortOrder(order.storageValue)
        }
    }

    fun setHomeTopNutrients(selection: List<HomeTopNutrient>) {
        viewModelScope.launch {
            container.prefs.setHomeTopNutrients(HomeTopNutrient.toStorage(selection))
        }
    }

    fun analyzeText(description: String) {
        viewModelScope.launch {
            val previousDraftImage = _ui.value.pendingDraftImageFilename
            container.analyzingFood.value = true
            _ui.value = _ui.value.copy(
                analyzing = true,
                error = null,
                pendingAnalysis = null,
                pendingImageBytes = null,
                pendingFoodSource = FoodSource.TEXT_INPUT,
                pendingDraftImageFilename = null,
                pendingReviewSource = null
            )
            discardPendingDraft(previousDraftImage)
            try {
                val analysis = container.foodAnalysis.analyzeText(description)
                savePendingDraft(analysis, imageBytes = null, source = FoodSource.TEXT_INPUT)
            } catch (e: AiError) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.message)
            } catch (e: Throwable) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.localizedMessage ?: "Analysis failed")
            } finally {
                container.analyzingFood.value = false
            }
        }
    }

    fun analyzePhoto(bytes: ByteArray) {
        viewModelScope.launch {
            val previousDraftImage = _ui.value.pendingDraftImageFilename
            container.analyzingFood.value = true
            _ui.value = _ui.value.copy(
                analyzing = true,
                error = null,
                pendingAnalysis = null,
                pendingImageBytes = bytes,
                pendingFoodSource = FoodSource.SNAP_FOOD,
                pendingDraftImageFilename = null,
                pendingReviewSource = null
            )
            discardPendingDraft(previousDraftImage)
            try {
                val analysis = container.foodAnalysis.analyzeAuto(bytes)
                savePendingDraft(analysis, imageBytes = bytes, source = FoodSource.SNAP_FOOD)
            } catch (e: AiError) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.message)
            } catch (e: Throwable) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.localizedMessage ?: "Analysis failed")
            } finally {
                container.analyzingFood.value = false
            }
        }
    }

    fun analyzePhotos(firstBytes: ByteArray, secondBytes: ByteArray) {
        viewModelScope.launch {
            val previousDraftImage = _ui.value.pendingDraftImageFilename
            container.analyzingFood.value = true
            // Both shots side by side — this composite becomes the entry's stored
            // image, so the log row and edit sheet show both photos (mirrors iOS).
            val combinedBytes = withContext(Dispatchers.Default) {
                FoodImageComposer.sideBySide(firstBytes, secondBytes)
            }
            _ui.value = _ui.value.copy(
                analyzing = true,
                error = null,
                pendingAnalysis = null,
                pendingImageBytes = combinedBytes,
                pendingFoodSource = FoodSource.SNAP_FOOD,
                pendingDraftImageFilename = null,
                pendingReviewSource = null
            )
            discardPendingDraft(previousDraftImage)
            try {
                val analysis = container.foodAnalysis.analyzeFood(listOf(firstBytes, secondBytes))
                savePendingDraft(analysis, imageBytes = combinedBytes, source = FoodSource.SNAP_FOOD)
            } catch (e: AiError) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.message)
            } catch (e: Throwable) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.localizedMessage ?: "Analysis failed")
            } finally {
                container.analyzingFood.value = false
            }
        }
    }

    /**
     * "Camera + Note" flow — analyze a photo with extra textual context the
     * user typed in (e.g. "extra cheese", "no oil"). Mirrors iOS
     * `cameraMode == .snapFoodWithContext` → `GeminiService.analyzeFood(image, description:)`.
     */
    fun analyzePhotoWithNote(bytes: ByteArray, note: String) {
        viewModelScope.launch {
            val previousDraftImage = _ui.value.pendingDraftImageFilename
            container.analyzingFood.value = true
            _ui.value = _ui.value.copy(
                analyzing = true,
                error = null,
                pendingAnalysis = null,
                pendingImageBytes = bytes,
                pendingFoodSource = FoodSource.SNAP_FOOD,
                pendingDraftImageFilename = null,
                pendingReviewSource = null
            )
            discardPendingDraft(previousDraftImage)
            try {
                val analysis = container.foodAnalysis.analyzeFood(bytes, note.takeIf { it.isNotBlank() })
                    .copy(customNote = note.takeIf { it.isNotBlank() })
                savePendingDraft(analysis, imageBytes = bytes, source = FoodSource.SNAP_FOOD)
            } catch (e: AiError) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.message)
            } catch (e: Throwable) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.localizedMessage ?: "Analysis failed")
            } finally {
                container.analyzingFood.value = false
            }
        }
    }

    fun lookupBarcode(barcode: String) {
        viewModelScope.launch {
            val previousDraftImage = _ui.value.pendingDraftImageFilename
            container.analyzingFood.value = true
            _ui.value = _ui.value.copy(
                analyzing = true,
                error = null,
                pendingAnalysis = null,
                pendingImageBytes = null,
                pendingFoodSource = FoodSource.BARCODE,
                pendingDraftImageFilename = null,
                pendingReviewSource = null
            )
            discardPendingDraft(previousDraftImage)
            try {
                val analysis = OpenFoodFactsService.lookup(barcode)
                savePendingDraft(analysis, imageBytes = null, source = FoodSource.BARCODE)
            } catch (e: Throwable) {
                _ui.value = _ui.value.copy(analyzing = false, error = e.localizedMessage ?: "Barcode lookup failed")
            } finally {
                container.analyzingFood.value = false
            }
        }
    }

    fun saveAnalysis(
        name: String? = null,
        servingGrams: Double? = null,
        scale: Double = 1.0,
        mealType: MealType = MealType.currentMeal,
        selectedServingUnit: String? = null,
        selectedServingQuantity: Double? = null,
        editedAnalysis: FoodAnalysis? = null
    ) {
        val analysis = editedAnalysis ?: _ui.value.pendingAnalysis ?: return
        val reviewSource = _ui.value.pendingReviewSource
        val pendingFoodSource = _ui.value.pendingFoodSource
        val pendingDraftImageFilename = _ui.value.pendingDraftImageFilename
        viewModelScope.launch {
            val imageBytes = _ui.value.pendingImageBytes
            val id = UUID.randomUUID()
            // If this analysis came from a Saved Meals review, reuse the
            // template's existing on-disk image so we don't duplicate the
            // JPEG. Otherwise (fresh AI analysis), persist the in-memory
            // bytes as a new file under the new entry id.
            val filename = reviewSource?.imageFilename
                ?: pendingDraftImageFilename
                ?: imageBytes?.let { container.imageStore.storeBytes(it, id) }
            fun s(v: Int) = (v * scale).roundToInt()
            fun macro(v: Double) = v * scale
            fun s(v: Double?) = v?.let { it * scale }
            val entry = FoodEntry(
                id = id,
                name = name?.takeIf { it.isNotBlank() } ?: analysis.name,
                calories = s(analysis.calories),
                protein = macro(analysis.protein),
                carbs = macro(analysis.carbs),
                fat = macro(analysis.fat),
                timestamp = timestampForSelectedDay(),
                imageFilename = filename,
                emoji = analysis.emoji,
                source = reviewSource?.source
                    ?: pendingFoodSource
                    ?: if (imageBytes != null) FoodSource.SNAP_FOOD else FoodSource.TEXT_INPUT,
                mealType = mealType,
                sugar = s(analysis.sugar),
                addedSugar = s(analysis.addedSugar),
                fiber = s(analysis.fiber),
                saturatedFat = s(analysis.saturatedFat),
                monounsaturatedFat = s(analysis.monounsaturatedFat),
                polyunsaturatedFat = s(analysis.polyunsaturatedFat),
                cholesterol = s(analysis.cholesterol),
                sodium = s(analysis.sodium),
                potassium = s(analysis.potassium),
                transFat = s(analysis.transFat),
                calcium = s(analysis.calcium),
                iron = s(analysis.iron),
                magnesium = s(analysis.magnesium),
                zinc = s(analysis.zinc),
                vitaminA = s(analysis.vitaminA),
                vitaminC = s(analysis.vitaminC),
                vitaminD = s(analysis.vitaminD),
                vitaminB12 = s(analysis.vitaminB12),
                vitaminE = s(analysis.vitaminE),
                vitaminK = s(analysis.vitaminK),
                folate = s(analysis.folate),
                omega3 = s(analysis.omega3),
                servingSizeGrams = servingGrams ?: analysis.servingSizeGrams,
                servingUnitOptions = analysis.servingUnitOptions,
                selectedServingUnit = if (analysis.servingUnitOptions.isEmpty()) null else selectedServingUnit,
                selectedServingQuantity = if (analysis.servingUnitOptions.isEmpty()) null else selectedServingQuantity,
                customNote = analysis.customNote
            )
            container.foodRepository.addEntry(entry)
            container.prefs.setPendingFoodAnalysisDraft(null)
            _ui.value = _ui.value.copy(
                pendingAnalysis = null,
                pendingImageBytes = null,
                pendingFoodSource = null,
                pendingDraftImageFilename = null,
                pendingReviewSource = null
            )
        }
    }

    suspend fun suggestMealWhatIf(entry: FoodEntry): String {
        val snapshot = _ui.value
        val profile = snapshot.profile
            ?: return "Finish onboarding first to compare this meal against your daily goals."
        return container.foodAnalysis.suggestMealWhatIf(
            entry = entry,
            dayEntries = snapshot.todayEntries,
            profile = profile,
            weightMetric = snapshot.weightMetric
        )
    }

    fun dismissPending() {
        val previousDraftImage = _ui.value.pendingDraftImageFilename
        _ui.value = _ui.value.copy(
            pendingAnalysis = null,
            pendingImageBytes = null,
            pendingFoodSource = null,
            pendingDraftImageFilename = null,
            pendingReviewSource = null,
            error = null
        )
        viewModelScope.launch {
            discardPendingDraft(previousDraftImage)
        }
    }

    /**
     * Tap a row in Saved Meals (Recents / Frequent / Favorites) → open the
     * FoodResultSheet for review instead of logging immediately. The user
     * can edit name / serving / meal type, then tap "Log" to commit. Mirrors
     * iOS RecentsView's `onReview` callback path.
     */
    fun reviewSavedMeal(template: FoodEntry) {
        val analysis = template.toAnalysis()
        val bytes = template.imageFilename?.let {
            runCatching { container.imageStore.file(it).readBytes() }.getOrNull()
        }
        _ui.value = _ui.value.copy(
            pendingAnalysis = analysis,
            pendingImageBytes = bytes,
            pendingFoodSource = template.source,
            pendingDraftImageFilename = null,
            pendingReviewSource = template,
            error = null
        )
    }

    fun deleteEntry(id: UUID) {
        viewModelScope.launch {
            container.foodRepository.deleteEntry(id)
        }
    }

    fun toggleFavorite(entry: FoodEntry) {
        viewModelScope.launch {
            container.foodRepository.toggleFavorite(entry)
        }
    }

    fun updateEntry(entry: FoodEntry) {
        viewModelScope.launch {
            container.foodRepository.updateEntry(entry)
        }
    }

    /** Re-log a saved meal (from Saved Meals sheet) as a new entry timestamped to the selected day. */
    fun relogMeal(template: FoodEntry) {
        viewModelScope.launch {
            container.foodRepository.addEntry(template.duplicatedForLogging(timestampForSelectedDay()))
        }
    }

    fun copyEntriesToSelectedDay(entries: List<FoodEntry>) {
        if (entries.isEmpty()) return
        viewModelScope.launch {
            entries.forEach { entry ->
                container.foodRepository.addEntry(
                    entry.duplicatedForLogging(
                        logDate = timestampForSelectedDayPreservingTime(entry.timestamp),
                        mealType = entry.mealType
                    )
                )
            }
        }
    }

    /** Save a user-typed entry with no AI involvement (manual macro input from issue #15). */
    fun saveManualEntry(
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        mealType: MealType = MealType.currentMeal
    ) {
        viewModelScope.launch {
            container.foodRepository.addEntry(
                FoodEntry(
                    name = name,
                    calories = calories,
                    protein = protein,
                    carbs = carbs,
                    fat = fat,
                    timestamp = timestampForSelectedDay(),
                    source = FoodSource.MANUAL,
                    mealType = mealType
                )
            )
        }
    }

    /**
     * Mirrors iOS `logDate: selectedDate` behavior. When viewing today, returns now.
     * When viewing a past or future day, combines that day with the current wall-clock
     * time so the entry shows a sensible time and lands on the correct calendar day.
     */
    private fun timestampForSelectedDay(): Instant {
        val day = _selectedDate.value
        val today = LocalDate.now()
        if (day == today) return Instant.now()
        val zone = ZoneId.systemDefault()
        val nowTime = java.time.LocalTime.now()
        return day.atTime(nowTime).atZone(zone).toInstant()
    }

    private fun timestampForSelectedDayPreservingTime(sourceTimestamp: Instant): Instant {
        val zone = ZoneId.systemDefault()
        val sourceTime = sourceTimestamp.atZone(zone).toLocalTime()
        return _selectedDate.value.atTime(sourceTime).atZone(zone).toInstant()
    }

    private suspend fun savePendingDraft(
        analysis: FoodAnalysis,
        imageBytes: ByteArray?,
        source: FoodSource
    ) {
        val imageFilename = imageBytes?.let { container.imageStore.storeBytes(it, UUID.randomUUID()) }
        container.prefs.setPendingFoodAnalysisDraft(
            PendingFoodAnalysisDraft(
                analysis = analysis,
                imageFilename = imageFilename,
                source = source
            )
        )
        _ui.value = _ui.value.copy(
            analyzing = false,
            pendingAnalysis = analysis,
            pendingImageBytes = imageBytes,
            pendingFoodSource = source,
            pendingDraftImageFilename = imageFilename,
            pendingReviewSource = null
        )
    }

    private fun restorePendingDraft(draft: PendingFoodAnalysisDraft) {
        val bytes = draft.imageFilename?.let {
            runCatching { container.imageStore.file(it).readBytes() }.getOrNull()
        }
        _ui.value = _ui.value.copy(
            analyzing = false,
            pendingAnalysis = draft.analysis,
            pendingImageBytes = bytes,
            pendingFoodSource = draft.source,
            pendingDraftImageFilename = draft.imageFilename,
            pendingReviewSource = null,
            error = null
        )
    }

    private suspend fun discardPendingDraft(imageFilename: String? = _ui.value.pendingDraftImageFilename) {
        val filename = imageFilename ?: container.prefs.pendingFoodAnalysisDraft.first()?.imageFilename
        container.prefs.setPendingFoodAnalysisDraft(null)
        filename?.let { container.imageStore.delete(it) }
    }

    class Factory(private val container: AppContainer) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            HomeViewModel(container) as T
    }

    suspend fun reprocessFoodEntry(entry: FoodEntry, updatedNote: String): FoodAnalysis {
        val imageBytes = entry.imageFilename?.let {
            runCatching { container.imageStore.file(it).readBytes() }.getOrNull()
        }
        // Compose name + serving + note so a photo-less (text / voice / emoji) entry
        // keeps its food context instead of re-analyzing the bare note; a photo entry
        // gets the name/note as extra grounding on top of the image.
        val description = reprocessDescription(entry, updatedNote)
        val result = if (imageBytes != null) {
            container.foodAnalysis.analyzeFood(imageBytes, description.takeIf { it.isNotBlank() })
        } else {
            container.foodAnalysis.analyzeText(description)
        }
        return result.copy(customNote = updatedNote.takeIf { it.isNotBlank() })
    }

    private fun reprocessDescription(entry: FoodEntry, note: String): String {
        val parts = mutableListOf<String>()
        entry.name.trim().takeIf { it.isNotEmpty() }?.let { parts += it }
        val qty = entry.selectedServingQuantity
        val unit = entry.selectedServingUnit?.trim()
        if (qty != null && qty > 0 && !unit.isNullOrEmpty()) {
            val q = if (qty % 1.0 == 0.0) qty.toInt().toString() else qty.toString()
            parts += "$q $unit"
        } else {
            entry.servingSizeGrams?.takeIf { it > 0 }?.let { parts += "${it.toInt()} g" }
        }
        val base = parts.joinToString(", ")
        val trimmed = note.trim()
        return when {
            base.isEmpty() -> trimmed
            trimmed.isEmpty() -> base
            else -> "$base. $trimmed"
        }
    }
}

/**
 * Map a logged FoodEntry back into a FoodAnalysis so the FoodResultSheet
 * (which only knows how to render a FoodAnalysis) can review a saved meal
 * before re-logging. The serving size defaults to 100g if the original entry
 * didn't record one — same fallback as EditFoodEntrySheet.
 */
private fun FoodEntry.toAnalysis(): FoodAnalysis = FoodAnalysis(
    name = name,
    calories = calories,
    protein = protein,
    carbs = carbs,
    fat = fat,
    servingSizeGrams = servingSizeGrams ?: 100.0,
    emoji = emoji,
    sugar = sugar,
    addedSugar = addedSugar,
    fiber = fiber,
    saturatedFat = saturatedFat,
    monounsaturatedFat = monounsaturatedFat,
    polyunsaturatedFat = polyunsaturatedFat,
    cholesterol = cholesterol,
    sodium = sodium,
    potassium = potassium,
    transFat = transFat,
    calcium = calcium,
    iron = iron,
    magnesium = magnesium,
    zinc = zinc,
    vitaminA = vitaminA,
    vitaminC = vitaminC,
    vitaminD = vitaminD,
    vitaminB12 = vitaminB12,
    vitaminE = vitaminE,
    vitaminK = vitaminK,
    folate = folate,
    omega3 = omega3,
    servingUnitOptions = servingUnitOptions,
    selectedServingUnit = selectedServingUnit,
    selectedServingQuantity = selectedServingQuantity,
    customNote = customNote
)
