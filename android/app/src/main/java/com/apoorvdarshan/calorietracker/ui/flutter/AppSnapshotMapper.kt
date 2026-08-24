package com.apoorvdarshan.calorietracker.ui.flutter

import android.content.Context
import com.apoorvdarshan.calorietracker.data.ExerciseRepository
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.AIProvider
import com.apoorvdarshan.calorietracker.models.SpeechLanguage
import com.apoorvdarshan.calorietracker.models.SpeechProvider
import com.apoorvdarshan.calorietracker.models.WorkoutRpeScale
import com.apoorvdarshan.calorietracker.models.WorkoutSplit
import com.apoorvdarshan.calorietracker.ui.theme.AppThemeColor
import com.apoorvdarshan.calorietracker.models.WorkoutTabMode
import com.apoorvdarshan.calorietracker.ui.coach.CoachUiState
import com.apoorvdarshan.calorietracker.ui.home.HomeUiState
import com.apoorvdarshan.calorietracker.ui.settings.SettingsUiState
import com.apoorvdarshan.calorietracker.ui.workouts.WorkoutsViewModel
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.TemporalAdjusters
import java.util.Locale

internal fun buildAppShellSnapshot(
    isDark: Boolean,
    selectedTab: String,
    updateAvailable: Boolean,
    workoutMode: WorkoutTabMode
): Map<String, Any?> = mapOf(
    "platform" to "android",
    "isDark" to isDark,
    "usesNativeNavigation" to false,
    "selectedTab" to selectedTab,
    "bottomContentInset" to 112.0,
    "workoutsLabel" to if (workoutMode == WorkoutTabMode.LOG) "Workouts" else "Exercises",
    "updateAvailable" to updateAvailable
)

internal fun buildHomeSnapshot(
    context: Context,
    ui: HomeUiState,
    weekStartsOnMonday: Boolean
): Map<String, Any?> {
    val locale = context.resources.configuration.locales[0] ?: Locale.getDefault()
    val profile = ui.profile
    val start = if (weekStartsOnMonday) {
        ui.date.with(TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY))
    } else {
        ui.date.with(TemporalAdjusters.previousOrSame(java.time.DayOfWeek.SUNDAY))
    }
    val weekDays = (0L..6L).map { offset ->
        val date = start.plusDays(offset)
        mapOf(
            "date" to date.toString(),
            "weekday" to date.format(DateTimeFormatter.ofPattern("EEEEE", locale)),
            "day" to date.dayOfMonth,
            "selected" to (date == ui.date)
        )
    }
    val mealGroups = listOf(
        MealType.BREAKFAST to "Breakfast",
        MealType.LUNCH to "Lunch",
        MealType.DINNER to "Dinner",
        MealType.SNACK to "Snack",
        MealType.OTHER to "Other"
    ).mapNotNull { (meal, title) ->
        val entries = ui.todayEntries.filter { it.mealType == meal }
        if (meal == MealType.OTHER && entries.isEmpty()) return@mapNotNull null
        mapOf(
            "meal" to meal.name.lowercase(Locale.US),
            "title" to title,
            "calories" to entries.sumOf { it.calories },
            "entries" to entries.map { entry ->
                mapOf(
                    "id" to entry.id.toString(),
                    "name" to entry.name,
                    "emoji" to entry.emoji,
                    "calories" to entry.calories,
                    "protein" to entry.protein,
                    "carbs" to entry.carbs,
                    "fat" to entry.fat,
                    "fiber" to entry.fiber,
                    "favorite" to ui.isFavorite(entry),
                    "timestampMs" to entry.timestamp.toEpochMilli()
                )
            }
        )
    }
    val activeFast = ui.activeFast
    val fastingStatus = if (activeFast == null) {
        "Ready for ${ui.fastingDefaultGoalMinutes / 60}h"
    } else {
        "In progress · ${activeFast.goalMinutes / 60}h goal"
    }
    return mapOf(
        "title" to if (ui.date == LocalDate.now()) "Today" else "Diary",
        "date" to ui.date.toString(),
        "dateLabel" to ui.date.format(
            DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale)
        ),
        "weekDays" to weekDays,
        "calories" to ui.caloriesToday,
        "calorieGoal" to (profile?.effectiveCalories ?: 2_000),
        "protein" to ui.proteinToday,
        "proteinGoal" to (profile?.effectiveProtein ?: 150),
        "carbs" to ui.carbsToday,
        "carbsGoal" to (profile?.effectiveCarbs ?: 220),
        "fat" to ui.fatToday,
        "fatGoal" to (profile?.effectiveFat ?: 70),
        "fiber" to ui.todayEntries.sumOf { it.fiber ?: 0.0 },
        "fiberGoal" to ui.optionalNutrientGoals.fiber,
        "mealGroups" to mealGroups,
        "waterEnabled" to ui.waterTrackingEnabled,
        "waterMl" to ui.waterTodayMl,
        "waterGoalMl" to ui.waterDailyGoalMl,
        "waterDisplay" to "${ui.waterTodayMl} ml",
        "waterGoalDisplay" to "${ui.waterDailyGoalMl} ml",
        "fastingEnabled" to ui.fastingTrackingEnabled,
        "fastingStatus" to fastingStatus,
        "analyzing" to ui.analyzing,
        "error" to ui.error
    )
}

internal fun buildCoachSnapshot(context: Context, ui: CoachUiState): Map<String, Any?> = mapOf(
    "messages" to ui.messages.map { message ->
        mapOf(
            "id" to message.id.toString(),
            "role" to message.role.name.lowercase(Locale.US),
            "content" to message.content,
            "hasImage" to (message.attachmentImageBase64 != null),
            "timestampMs" to message.timestamp.toEpochMilli()
        )
    },
    "sending" to ui.sending,
    "error" to (ui.error ?: ui.errorRes?.let(context::getString)),
    "suggestions" to ui.suggestions.map(context::getString)
)

private fun settingsRow(
    id: String,
    title: String,
    subtitle: String = "",
    value: String = "",
    icon: String = "tune",
    type: String = "navigation",
    valueBool: Boolean = false,
    enabled: Boolean = true,
    destructive: Boolean = false,
    choices: List<Map<String, String>> = emptyList()
): Map<String, Any?> = mapOf(
    "id" to id,
    "title" to title,
    "subtitle" to subtitle,
    "value" to value,
    "icon" to icon,
    "type" to type,
    "valueBool" to valueBool,
    "enabled" to enabled,
    "destructive" to destructive,
    "choices" to choices
)

private fun choice(value: String, label: String = value): Map<String, String> =
    mapOf("value" to value, "label" to label)

private fun settingsSection(title: String, vararg rows: Map<String, Any?>): Map<String, Any?> =
    mapOf("title" to title, "rows" to rows.toList())

internal fun buildSettingsSnapshot(context: Context, ui: SettingsUiState): Map<String, Any?> {
    val profile = ui.profile
    val locale = context.resources.configuration.locales[0] ?: Locale.getDefault()
    val birthday = profile?.birthday?.atZone(ZoneId.systemDefault())?.toLocalDate()
    return mapOf(
        "sections" to listOf(
            settingsSection(
                "Profile",
                settingsRow("profile.name", "Profile", profile?.displayName ?: "User", icon = "person", enabled = false),
                settingsRow("profile.gender", "Gender", value = profile?.gender?.name.orEmpty(), icon = "person"),
                settingsRow("profile.birthday", "Birthday", value = birthday?.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale)).orEmpty(), icon = "person"),
                settingsRow("profile.height", "Height", value = profile?.let { if (ui.heightMetric) "${it.heightCm.toInt()} cm" else "${(it.heightCm / 2.54).toInt()} in" }.orEmpty(), icon = "scale"),
                settingsRow("profile.weight", "Current weight", value = profile?.let { if (ui.weightMetric) "%.1f kg".format(locale, it.weightKg) else "%.1f lb".format(locale, it.weightKg * 2.20462) }.orEmpty(), icon = "scale"),
                settingsRow("profile.goal", "Goal", value = profile?.goal?.name.orEmpty(), icon = "target"),
                settingsRow("profile.bodyMeasurements", "Body measurements", "Track circumference history", icon = "scale")
            ),
            settingsSection(
                "Daily targets",
                settingsRow("targets.calories", "Calories", value = "${profile?.effectiveCalories ?: 0} kcal", icon = "target"),
                settingsRow("targets.protein", "Protein", value = "${profile?.effectiveProtein ?: 0} g", icon = "nutrition"),
                settingsRow("targets.carbs", "Carbs", value = "${profile?.effectiveCarbs ?: 0} g", icon = "nutrition"),
                settingsRow("targets.fat", "Fat", value = "${profile?.effectiveFat ?: 0} g", icon = "nutrition"),
                settingsRow("targets.optional", "Optional nutrients", "Fiber, sugar, vitamins, minerals", icon = "nutrition"),
                settingsRow("targets.recalculate", "Recalculate goals", if (ui.goalsNeedRecalc) "Profile changed · update recommended" else "Refresh targets from your profile", icon = "target")
            ),
            settingsSection(
                "Food & tracking",
                settingsRow("food.weightUnit", "Weight unit", value = ui.weightUnit, icon = "scale", choices = listOf(choice("kg", "Kilograms"), choice("lbs", "Pounds"))),
                settingsRow("food.heightUnit", "Height unit", value = ui.heightUnit, icon = "scale", choices = listOf(choice("cm", "Centimeters"), choice("ftin", "Feet & inches"))),
                settingsRow("food.grams", "Prefer grams", "Use grams when a food supports them", icon = "nutrition", type = "toggle", valueBool = ui.preferGramsByDefault),
                settingsRow("food.mealSchedule", "Meal schedule", "Breakfast, lunch, dinner, and snack times", icon = "nutrition"),
                settingsRow("food.water", "Water tracking", icon = "water", type = "toggle", valueBool = ui.waterTrackingEnabled),
                settingsRow("food.waterGoal", "Water goal", value = "${ui.waterDailyGoalMl} ml", icon = "water", enabled = ui.waterTrackingEnabled, choices = listOf(1500, 2000, 2500, 3000, 3500, 4000).map { choice(it.toString(), "$it ml") }),
                settingsRow("food.fasting", "Fasting tracking", icon = "fasting", type = "toggle", valueBool = ui.fastingTrackingEnabled),
                settingsRow("food.fastingGoal", "Default fast", value = "${ui.fastingDefaultGoalMinutes / 60} h", icon = "fasting", enabled = ui.fastingTrackingEnabled, choices = listOf(12, 14, 16, 18, 20, 24).map { choice((it * 60).toString(), "$it hours") })
            ),
            settingsSection(
                "AI & voice",
                settingsRow("ai.provider", "AI provider", value = context.getString(ui.selectedAI.displayNameRes), icon = "ai", choices = AIProvider.entries.map { choice(it.name, context.getString(it.displayNameRes)) }),
                settingsRow("ai.model", "AI model", value = ui.selectedModel, icon = "ai", choices = ui.selectedAI.models.map(::choice)),
                settingsRow("ai.apiKey", "API key", value = ui.apiKeyMasked, icon = "privacy"),
                settingsRow("ai.context", "Personal context", "Preferences the coach should remember", icon = "ai"),
                settingsRow("ai.fallback", "Fallback provider", icon = "ai", type = "toggle", valueBool = ui.fallbackEnabled),
                settingsRow("speech.provider", "Speech provider", value = context.getString(ui.selectedSpeech.displayNameRes), icon = "speech", choices = SpeechProvider.entries.map { choice(it.name, context.getString(it.displayNameRes)) }),
                settingsRow("speech.language", "Speech language", value = context.getString(ui.selectedSpeechLanguage.displayNameRes), icon = "speech", choices = SpeechLanguage.optionsFor(ui.selectedSpeech).map { choice(it.name, context.getString(it.displayNameRes)) })
            ),
            settingsSection(
                "Reminders",
                settingsRow("notifications.master", "Notifications", icon = "notification", type = "toggle", valueBool = ui.notificationsEnabled),
                settingsRow("notifications.streak", "Streak reminder", icon = "notification", type = "toggle", valueBool = ui.streakReminderEnabled, enabled = ui.notificationsEnabled),
                settingsRow("notifications.summary", "Daily summary", icon = "notification", type = "toggle", valueBool = ui.dailySummaryEnabled, enabled = ui.notificationsEnabled),
                settingsRow("notifications.weight", "Weight reminder", icon = "notification", type = "toggle", valueBool = ui.weightReminderEnabled, enabled = ui.notificationsEnabled),
                settingsRow("notifications.update", "App updates", icon = "notification", type = "toggle", valueBool = ui.appUpdateNotificationsEnabled, enabled = ui.notificationsEnabled)
            ),
            settingsSection(
                "Health & workouts",
                settingsRow("health.connect", "Health Connect", "Sync compatible health records", icon = "health", type = "toggle", valueBool = ui.healthConnectEnabled),
                settingsRow("health.energy", "Energy-based goals", icon = "health", type = "toggle", valueBool = ui.healthEnergyGoalsEnabled, enabled = ui.healthConnectEnabled),
                settingsRow("health.adaptive", "Adaptive goals", "Refresh targets from your trends", icon = "health", type = "toggle", valueBool = ui.adaptiveGoalsEnabled),
                settingsRow("workout.split", "Workout split", value = ui.workoutSplit.title, icon = "workout", choices = WorkoutSplit.SelectableValues.map { choice(it.name, it.title) }),
                settingsRow("workout.rpe", "RPE scale", value = ui.workoutRpeScale.title, icon = "workout", choices = WorkoutRpeScale.entries.map { choice(it.name, it.title) })
            ),
            settingsSection(
                "App",
                settingsRow("app.appearance", "Appearance", value = ui.appearanceMode, icon = "appearance", choices = listOf(choice("system", "System"), choice("light", "Light"), choice("dark", "Dark"))),
                settingsRow("app.theme", "Theme color", value = context.getString(ui.appThemeColor.displayNameRes), icon = "appearance", choices = AppThemeColor.entries.map { choice(it.name, context.getString(it.displayNameRes)) }),
                settingsRow("app.weekStart", "Week starts on", value = if (ui.weekStartsOnMonday) "Monday" else "Sunday", icon = "appearance", choices = listOf(choice("monday", "Monday"), choice("sunday", "Sunday"))),
                settingsRow("app.quickActions", "Quick actions", "Choose home-screen shortcuts", icon = "tune"),
                settingsRow("data.export", "Export diary", icon = "data"),
                settingsRow("data.import", "Import diary", icon = "data"),
                settingsRow("data.clearFood", "Clear food log", icon = "delete", destructive = true),
                settingsRow("data.deleteAll", "Delete all data", icon = "delete", destructive = true),
                settingsRow("app.about", "About Füd AI", "Version 7.0", icon = "info")
            )
        )
    )
}

internal fun buildWorkoutsSnapshot(
    context: Context,
    vm: WorkoutsViewModel
): Map<String, Any?> {
    val state = vm.diaryUiState
    val locale = context.resources.configuration.locales[0] ?: Locale.getDefault()
    val repo = ExerciseRepository.get(context)
    val library = repo.filtered(
        levels = vm.levels,
        equipment = vm.equipment,
        primaryMuscles = vm.primaryMuscles,
        secondaryMuscles = vm.secondaryMuscles,
        forces = vm.forces,
        mechanics = vm.mechanics,
        categories = vm.categories,
        sort = vm.sort,
        searchText = vm.search
    ).take(80)
    return mapOf(
        "mode" to if (state.mode == WorkoutTabMode.LOG) "log" else "library",
        "date" to state.selectedDate.toString(),
        "dateTitle" to if (state.selectedDate == LocalDate.now()) "Today" else state.selectedDate.dayOfWeek.getDisplayName(java.time.format.TextStyle.FULL, locale),
        "dateSubtitle" to state.selectedDate.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(locale)),
        "canMoveForward" to state.selectedDate.isBefore(LocalDate.now()),
        "setCount" to state.performedSetCount,
        "repCount" to state.repCount,
        "caloriesBurned" to state.caloriesBurned,
        "calculatingBurn" to state.isCalculatingBurn,
        "exercises" to state.exercises.map { exercise ->
            mapOf(
                "id" to exercise.id.toString(),
                "itemId" to exercise.itemId,
                "name" to exercise.name,
                "equipment" to exercise.equipment,
                "sets" to exercise.sets.map { set ->
                    mapOf(
                        "id" to set.id.toString(),
                        "weight" to set.displayWeight(state.weightUnit),
                        "reps" to set.reps,
                        "rpe" to set.rpe
                    )
                }
            )
        },
        "libraryExercises" to library.map { exercise ->
            mapOf(
                "id" to exercise.id,
                "name" to exercise.name,
                "primaryMuscle" to exercise.primaryMuscles.firstOrNull().orEmpty(),
                "equipment" to exercise.equipment,
                "level" to exercise.level,
                "saved" to (exercise.id in state.savedExerciseIds)
            )
        }
    )
}
