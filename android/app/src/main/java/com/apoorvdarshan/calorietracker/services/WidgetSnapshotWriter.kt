package com.apoorvdarshan.calorietracker.services

import android.content.Context
import androidx.compose.ui.graphics.toArgb
import com.apoorvdarshan.calorietracker.data.FoodRepository
import com.apoorvdarshan.calorietracker.data.PreferencesStore
import com.apoorvdarshan.calorietracker.data.ProfileRepository
import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.HomeTopNutrient
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.models.WidgetNutrient
import com.apoorvdarshan.calorietracker.models.WidgetSnapshot
import com.apoorvdarshan.calorietracker.models.WaterEntry
import com.apoorvdarshan.calorietracker.models.WaterUnit
import com.apoorvdarshan.calorietracker.ui.theme.AppThemeColor
import com.apoorvdarshan.calorietracker.widget.WidgetRefreshScheduler
import com.apoorvdarshan.calorietracker.widget.WidgetUpdateCoordinator
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Recomputes today's totals whenever food entries or the user profile change,
 * writes the [WidgetSnapshot] into DataStore, and asks Glance to redraw both
 * the Calorie and Protein app widgets. Mirrors the iOS WidgetSnapshotWriter
 * call sites (every FoodStore change + profile-change notification + scene
 * resume).
 */
class WidgetSnapshotWriter(
    private val context: Context,
    private val prefs: PreferencesStore,
    private val foodRepository: FoodRepository,
    private val profileRepository: ProfileRepository
) {
    fun observe() = combine(
        combine(
            foodRepository.entries,
            profileRepository.profile,
            prefs.homeTopNutrients,
            prefs.appThemeColor,
            prefs.optionalNutrientGoals
        ) { entries, profile, _, _, _ ->
            // Selection / theme / goals are re-read inside publish; they're combined
            // here only so their changes re-trigger a snapshot write.
            CoreWidgetState(entries, profile)
        },
        combine(
            prefs.waterTrackingEnabled,
            prefs.waterDailyGoalMl,
            prefs.waterUnit,
            prefs.waterEntries
        ) { enabled, goalMl, unit, entries ->
            WaterWidgetState(enabled, goalMl, unit, entries)
        }
    ) { core, water -> WidgetInputs(core, water) }
        .distinctUntilChanged()
        .onEach { inputs -> publish(inputs.core.entries, inputs.core.profile, inputs.water) }
        .map { Unit }

    private suspend fun publish(entries: List<FoodEntry>, profile: UserProfile?, water: WaterWidgetState) {
        val todaysEntries = entries.filter {
            it.timestamp.atZone(ZoneId.systemDefault()).toLocalDate() == LocalDate.now()
        }
        if (profile == null) {
            prefs.clearWidgetSnapshot()
        } else {
            val selection = HomeTopNutrient.fromStorage(prefs.homeTopNutrients.first())
            val optionalGoals = prefs.optionalNutrientGoals.first()
            val theme = AppThemeColor.fromKey(prefs.appThemeColor.first())
            val waterTodayMl = water.entries
                .filter { it.date.atZone(ZoneId.systemDefault()).toLocalDate() == LocalDate.now() }
                .sumOf { it.milliliters }
            val snapshot = WidgetSnapshot(
                date = Instant.now(),
                dayStart = WidgetSnapshot.todayStart(),
                calories = todaysEntries.sumOf { it.calories },
                calorieGoal = profile.effectiveCalories,
                protein = todaysEntries.sumOf { it.protein },
                proteinGoal = profile.effectiveProtein,
                carbs = todaysEntries.sumOf { it.carbs },
                carbsGoal = profile.effectiveCarbs,
                fat = todaysEntries.sumOf { it.fat },
                fatGoal = profile.effectiveFat,
                homeNutrients = selection.map { nutrient ->
                    WidgetNutrient(
                        id = nutrient.storageKey,
                        label = context.getString(nutrient.displayNameRes),
                        unit = context.getString(nutrient.unitRes),
                        value = nutrient.current(todaysEntries),
                        goal = nutrient.goal(profile, optionalGoals).toDouble()
                    )
                },
                themeStartHex = theme.start.toArgb() and 0xFFFFFF,
                themeEndHex = theme.end.toArgb() and 0xFFFFFF,
                waterTrackingEnabled = water.enabled,
                waterCurrentMl = waterTodayMl,
                waterGoalMl = water.goalMl.coerceAtLeast(1),
                waterUnitRaw = water.unit.storageValue
            )
            prefs.setWidgetSnapshot(snapshot)
        }
        if (!WidgetUpdateCoordinator.updateAll(context)) {
            WidgetRefreshScheduler.enqueueImmediate(context, "snapshot_update_failed")
        }
    }
}

private data class CoreWidgetState(
    val entries: List<FoodEntry>,
    val profile: UserProfile?
)

private data class WaterWidgetState(
    val enabled: Boolean,
    val goalMl: Int,
    val unit: WaterUnit,
    val entries: List<WaterEntry>
)

private data class WidgetInputs(
    val core: CoreWidgetState,
    val water: WaterWidgetState
)
