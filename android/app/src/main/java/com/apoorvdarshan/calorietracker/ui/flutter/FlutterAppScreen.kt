package com.apoorvdarshan.calorietracker.ui.flutter

import android.view.View
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.fragment.app.FragmentContainerView
import androidx.lifecycle.viewmodel.compose.viewModel
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.MainActivity
import com.apoorvdarshan.calorietracker.models.WorkoutTabMode
import com.apoorvdarshan.calorietracker.models.WorkoutWeightUnit
import com.apoorvdarshan.calorietracker.models.QuickAction
import com.apoorvdarshan.calorietracker.models.AIProvider
import com.apoorvdarshan.calorietracker.models.SpeechLanguage
import com.apoorvdarshan.calorietracker.models.SpeechProvider
import com.apoorvdarshan.calorietracker.models.WorkoutRpeScale
import com.apoorvdarshan.calorietracker.models.WorkoutSplit
import com.apoorvdarshan.calorietracker.ui.coach.CoachViewModel
import com.apoorvdarshan.calorietracker.ui.home.HomeViewModel
import com.apoorvdarshan.calorietracker.ui.progress.FlutterProgressAction
import com.apoorvdarshan.calorietracker.ui.progress.ProgressViewModel
import com.apoorvdarshan.calorietracker.ui.progress.buildProgressSnapshot
import com.apoorvdarshan.calorietracker.ui.progress.progressStrings
import com.apoorvdarshan.calorietracker.ui.settings.SettingsViewModel
import com.apoorvdarshan.calorietracker.ui.workouts.WorkoutsViewModel
import com.apoorvdarshan.calorietracker.ui.theme.AppThemeColor
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import java.time.LocalDate

/** Hosts the complete shared post-onboarding Flutter presentation. */
@Composable
internal fun FlutterAppScreen(
    container: AppContainer,
    activity: MainActivity,
    settingsViewModel: SettingsViewModel,
    updateAvailable: Boolean,
    onOpenNative: (String) -> Unit
) {
    val homeViewModel: HomeViewModel = viewModel(factory = HomeViewModel.Factory(container))
    val coachViewModel: CoachViewModel = viewModel(factory = CoachViewModel.Factory(container))
    val progressViewModel: ProgressViewModel = viewModel(factory = ProgressViewModel.Factory(container))
    val workoutsViewModel: WorkoutsViewModel = viewModel()

    val home by homeViewModel.ui.collectAsState()
    val coach by coachViewModel.ui.collectAsState()
    val progress by progressViewModel.ui.collectAsState()
    val settings by settingsViewModel.ui.collectAsState()
    val foods by container.foodRepository.entries.collectAsState(initial = emptyList())
    val weightUnit by container.prefs.weightUnit.collectAsState(initial = "kg")
    val weekStartsOnMonday by container.prefs.weekStartsOnMonday.collectAsState(initial = true)
    val profile by container.profileRepository.profile.collectAsState(initial = null)
    val latestWeight by container.weightRepository.latest.collectAsState(initial = null)
    val workoutMode by container.workoutRepository.mode.collectAsState(initial = WorkoutTabMode.Default)
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val localizedProgressStrings = remember(configuration) { progressStrings(context) }
    val appBridge = activity.appFlutterBridge
    val progressBridge = activity.progressFlutterBridge
    val bindingOwner = remember { Any() }
    var selectedTab by rememberSaveable { mutableStateOf("home") }

    val bodyWeightKg = latestWeight?.weightKg ?: profile?.weightKg ?: 70.0
    val workoutWeightUnit = WorkoutWeightUnit.fromStorage(weightUnit)
    LaunchedEffect(container.workoutRepository, bodyWeightKg, workoutWeightUnit) {
        workoutsViewModel.bindWorkoutRepository(
            repository = container.workoutRepository,
            currentBodyWeightKg = bodyWeightKg,
            weightUnit = workoutWeightUnit
        )
    }

    val shellProvider = rememberUpdatedState<() -> Map<String, Any?>> {
        buildAppShellSnapshot(
            isDark = isDark,
            selectedTab = selectedTab,
            updateAvailable = updateAvailable,
            workoutMode = workoutMode
        )
    }
    val pageProvider = rememberUpdatedState<(String) -> Map<String, Any?>> { tab ->
        when (tab) {
            "home" -> buildHomeSnapshot(context, home, weekStartsOnMonday)
            "coach" -> buildCoachSnapshot(context, coach)
            "settings" -> buildSettingsSnapshot(context, settings)
            "workouts" -> buildWorkoutsSnapshot(context, workoutsViewModel)
            else -> emptyMap()
        }
    }
    val actionHandler = rememberUpdatedState<(String, Map<*, *>) -> Any?> { action, arguments ->
        when (action) {
            "home.selectDate" -> (arguments["date"] as? String)
                ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
                ?.let(homeViewModel::setSelectedDate)
            "home.quickAction" -> (arguments["quickAction"] as? String)
                ?.let { runCatching { QuickAction.valueOf(it) }.getOrNull() }
                ?.let { onOpenNative(NativeFlutterDestination.homeAction(it)) }
            "home.openEntry" -> (arguments["id"] as? String)
                ?.takeIf(String::isNotBlank)
                ?.let { onOpenNative(NativeFlutterDestination.homeEntry(it)) }
            "home.addWater" -> (arguments["milliliters"] as? Number)
                ?.toInt()
                ?.let(homeViewModel::addWater)
            "home.startFast" -> (arguments["minutes"] as? Number)
                ?.toInt()
                ?.let(homeViewModel::startFast)
            "home.endFast" -> homeViewModel.endFast()
            "home.cancelFast" -> homeViewModel.cancelFast()
            "coach.send" -> coachViewModel.send(arguments["text"] as? String ?: "")
            "coach.reset" -> coachViewModel.resetConversation()
            "coach.capability" -> (arguments["capability"] as? String)
                ?.takeIf { it in setOf("camera", "photos", "voice") }
                ?.let { onOpenNative(NativeFlutterDestination.coachAction(it)) }
            "workouts.toggleMode" -> workoutsViewModel.setMode(
                if (workoutsViewModel.diaryUiState.mode == WorkoutTabMode.LOG) {
                    WorkoutTabMode.LIBRARY
                } else {
                    WorkoutTabMode.LOG
                }
            )
            "workouts.previousDate" -> workoutsViewModel.moveDate(-1)
            "workouts.nextDate" -> workoutsViewModel.moveDate(1)
            "workouts.search" -> workoutsViewModel.search = arguments["query"] as? String ?: ""
            "workouts.calculateBurn" -> workoutsViewModel.calculateBurn()
            "workouts.addExercise" -> onOpenNative(
                NativeFlutterDestination.workoutsAction("add")
            )
            "workouts.copyDay" -> onOpenNative(
                NativeFlutterDestination.workoutsAction("copy")
            )
            "workouts.openExercise", "workouts.openLibraryExercise" ->
                (arguments["id"] as? String)
                    ?.takeIf(String::isNotBlank)
                    ?.let { onOpenNative(NativeFlutterDestination.workoutExercise(it)) }
            "settings.toggle" -> {
                val id = arguments["id"] as? String
                val value = arguments["value"] as? Boolean ?: false
                if (value && id in setOf(
                        "notifications.master",
                        "notifications.summary",
                        "health.connect",
                        "health.energy"
                    )
                ) {
                    onOpenNative(NativeFlutterDestination.settingsRow(id!!))
                } else {
                    handleSettingsToggle(settingsViewModel, id, value)
                }
            }
            "settings.choice" -> handleSettingsChoice(
                settingsViewModel,
                arguments["id"] as? String,
                arguments["value"] as? String
            )
            "settings.open" -> openSettingsDestination(
                arguments["id"] as? String,
                onOpenNative
            )
            "settings.openProfile" -> onOpenNative(NativeFlutterDestination.SETTINGS)
            else -> when {
                action.startsWith("home.") -> onOpenNative(NativeFlutterDestination.HOME)
                action.startsWith("coach.") -> onOpenNative(NativeFlutterDestination.COACH)
                action.startsWith("settings.") -> onOpenNative(NativeFlutterDestination.SETTINGS)
                action.startsWith("workouts.") -> onOpenNative(NativeFlutterDestination.WORKOUTS)
                else -> null
            }
        }
    }
    val tabHandler = rememberUpdatedState<(String) -> Unit> { selectedTab = it }
    val progressSnapshotProvider = rememberUpdatedState<(String) -> Map<String, Any?>> { range ->
        buildProgressSnapshot(
            rangeName = range,
            ui = progress,
            foods = foods,
            weightUnit = weightUnit,
            isDark = isDark,
            strings = localizedProgressStrings,
            bottomContentInset = 0.0,
            safeAreaTop = true
        )
    }
    val progressActionHandler = rememberUpdatedState<(FlutterProgressAction) -> Unit> {
        onOpenNative(NativeFlutterDestination.progressAction(it))
        progressBridge.completeAction()
    }

    LaunchedEffect(home) { appBridge.notifySnapshotChanged("home") }
    LaunchedEffect(coach) { appBridge.notifySnapshotChanged("coach") }
    LaunchedEffect(settings) { appBridge.notifySnapshotChanged("settings") }
    LaunchedEffect(workoutsViewModel.diaryUiState, workoutsViewModel.search) {
        appBridge.notifySnapshotChanged("workouts")
    }
    LaunchedEffect(progress, foods, weightUnit, isDark, localizedProgressStrings) {
        progressBridge.notifySnapshotChanged()
    }
    LaunchedEffect(isDark, updateAvailable, workoutMode) {
        appBridge.notifySnapshotChanged("shell")
    }

    val fragmentContainerId = rememberSaveable { View.generateViewId() }
    val fragmentTag = rememberSaveable(fragmentContainerId) {
        "fud-ai-flutter-app-$fragmentContainerId"
    }
    AndroidView(
        factory = { viewContext ->
            FragmentContainerView(viewContext).apply { id = fragmentContainerId }
        },
        modifier = Modifier.fillMaxSize()
    )

    DisposableEffect(activity, appBridge, progressBridge, bindingOwner, fragmentContainerId) {
        appBridge.bind(
            owner = bindingOwner,
            shellProvider = { shellProvider.value() },
            pageProvider = { tab -> pageProvider.value(tab) },
            actionHandler = { action, arguments -> actionHandler.value(action, arguments) },
            tabHandler = { tab -> tabHandler.value(tab) }
        )
        progressBridge.bind(
            owner = bindingOwner,
            snapshotProvider = { range -> progressSnapshotProvider.value(range) },
            actionHandler = { action -> progressActionHandler.value(action) }
        )

        val fragmentManager = activity.supportFragmentManager
        val fragment = FlutterFragment.withNewEngine()
            .renderMode(RenderMode.texture)
            .transparencyMode(TransparencyMode.opaque)
            .shouldAttachEngineToActivity(true)
            .shouldAutomaticallyHandleOnBackPressed(false)
            .build<FlutterFragment>()
        fragmentManager.beginTransaction()
            .setReorderingAllowed(true)
            .apply {
                fragmentManager.fragments
                    .filter { it.tag?.startsWith(APP_FRAGMENT_TAG_PREFIX) == true }
                    .forEach(::remove)
            }
            .add(fragmentContainerId, fragment, fragmentTag)
            .commitNow()

        onDispose {
            fragmentManager.findFragmentByTag(fragmentTag)?.let { existing ->
                fragmentManager.beginTransaction().remove(existing).commitNowAllowingStateLoss()
            }
            appBridge.unbind(bindingOwner)
            progressBridge.unbind(bindingOwner)
        }
    }
}

private fun handleSettingsToggle(vm: SettingsViewModel, id: String?, value: Boolean) {
    when (id) {
        "food.grams" -> vm.setPreferGramsByDefault(value)
        "food.water" -> vm.setWaterTrackingEnabled(value)
        "food.fasting" -> vm.setFastingTrackingEnabled(value)
        "ai.fallback" -> vm.setFallbackEnabled(value)
        "notifications.master" -> vm.setNotificationsEnabled(value)
        "notifications.streak" -> vm.setStreakReminderEnabled(value)
        "notifications.summary" -> vm.setDailySummaryEnabled(value)
        "notifications.weight" -> vm.setWeightReminderEnabled(value)
        "notifications.update" -> vm.setAppUpdateNotificationsEnabled(value)
        "health.connect" -> vm.setHealthConnectEnabled(value)
        "health.energy" -> vm.setHealthEnergyGoalsEnabled(value)
        "health.adaptive" -> vm.setAdaptiveGoalsEnabled(value)
    }
}

private fun openSettingsDestination(id: String?, open: (String) -> Unit) {
    open(
        when (id) {
            "profile.bodyMeasurements" -> NativeFlutterDestination.BODY_MEASUREMENTS
            "targets.optional" -> NativeFlutterDestination.OPTIONAL_NUTRIENTS
            "app.quickActions" -> NativeFlutterDestination.QUICK_ACTIONS
            else -> id?.let(NativeFlutterDestination::settingsRow)
                ?: NativeFlutterDestination.SETTINGS
        }
    )
}

private fun handleSettingsChoice(vm: SettingsViewModel, id: String?, value: String?) {
    if (value == null) return
    when (id) {
        "food.weightUnit" -> vm.setWeightUnit(value)
        "food.heightUnit" -> vm.setHeightUnit(value)
        "food.waterGoal" -> value.toIntOrNull()?.let(vm::setWaterDailyGoalMl)
        "food.fastingGoal" -> value.toIntOrNull()?.let(vm::setFastingDefaultGoalMinutes)
        "ai.provider" -> runCatching { AIProvider.valueOf(value) }.getOrNull()?.let(vm::selectProvider)
        "ai.model" -> vm.selectModel(value)
        "speech.provider" -> runCatching { SpeechProvider.valueOf(value) }.getOrNull()?.let(vm::selectSpeech)
        "speech.language" -> runCatching { SpeechLanguage.valueOf(value) }.getOrNull()?.let(vm::selectSpeechLanguage)
        "workout.split" -> runCatching { WorkoutSplit.valueOf(value) }.getOrNull()?.let(vm::selectWorkoutSplit)
        "workout.rpe" -> runCatching { WorkoutRpeScale.valueOf(value) }.getOrNull()?.let(vm::selectWorkoutRpeScale)
        "app.appearance" -> vm.setAppearanceMode(value)
        "app.theme" -> runCatching { AppThemeColor.valueOf(value) }.getOrNull()?.let(vm::setAppThemeColor)
        "app.weekStart" -> vm.setWeekStartsOnMonday(value == "monday")
    }
}

internal object NativeFlutterDestination {
    const val HOME = "native/home"
    const val PROGRESS = "native/progress"
    const val COACH = "native/coach"
    const val SETTINGS = "native/settings"
    const val WORKOUTS = "native/workouts"
    const val OPTIONAL_NUTRIENTS = "settings/optional-nutrient-goals"
    const val QUICK_ACTIONS = "settings/quick-actions"
    const val BODY_MEASUREMENTS = "settings/body-measurements"
    const val HOME_ACTION = "native/home/action/{action}"
    const val HOME_ENTRY = "native/home/entry/{entryId}"
    const val COACH_ACTION = "native/coach/action/{action}"
    const val WORKOUTS_ACTION = "native/workouts/action/{action}"
    const val WORKOUT_EXERCISE = "native/workouts/exercise/{itemId}"
    const val SETTINGS_ROW = "native/settings/row/{rowId}"
    const val PROGRESS_ACTION = "native/progress/action/{action}"

    fun homeAction(action: QuickAction): String = "native/home/action/${action.name}"
    fun homeEntry(entryId: String): String = "native/home/entry/$entryId"
    fun coachAction(action: String): String = "native/coach/action/$action"
    fun workoutsAction(action: String): String = "native/workouts/action/$action"
    fun workoutExercise(itemId: String): String = "native/workouts/exercise/$itemId"
    fun settingsRow(rowId: String): String = "native/settings/row/$rowId"
    fun progressAction(action: FlutterProgressAction): String =
        "native/progress/action/${action.name}"
}

private const val APP_FRAGMENT_TAG_PREFIX = "fud-ai-flutter-app-"
