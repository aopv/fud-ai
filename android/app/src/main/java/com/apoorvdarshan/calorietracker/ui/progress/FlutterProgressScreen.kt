package com.apoorvdarshan.calorietracker.ui.progress

import android.content.Context
import android.content.ContextWrapper
import android.view.View
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentContainerView
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.viewinterop.AndroidView
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.MainActivity
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialog
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialogActions
import com.apoorvdarshan.calorietracker.ui.navigation.BottomNavScrollPadding
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import kotlinx.coroutines.launch
import java.util.Locale

/**
 * Flutter renders this one tab; the Compose shell, bottom navigation, dialogs,
 * repositories, and all durable data remain native.
 */
@Composable
internal fun ProgressScreen(
    container: AppContainer,
    initialAction: FlutterProgressAction? = null,
    onActionFinished: (() -> Unit)? = null
) {
    val activity = LocalContext.current.findMainActivity()
    if (initialAction != null || activity == null || activity.intent.getBooleanExtra(NATIVE_PROGRESS_EXTRA, false)) {
        NativeProgressScreen(container, initialAction, onActionFinished)
        return
    }
    FlutterProgressScreen(container = container, activity = activity)
}

@Composable
private fun FlutterProgressScreen(container: AppContainer, activity: MainActivity) {
    val vm: ProgressViewModel = viewModel(factory = ProgressViewModel.Factory(container))
    val ui by vm.ui.collectAsState()
    val foods by container.foodRepository.entries.collectAsState(initial = emptyList())
    val weightUnit by container.prefs.weightUnit.collectAsState(initial = "kg")
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val strings = remember(configuration) { progressStrings(context) }
    val bridge = activity.progressFlutterBridge
    val bindingOwner = remember { Any() }
    val scope = rememberCoroutineScope()

    var showAddWeight by remember { mutableStateOf(false) }
    var showAddBodyFat by remember { mutableStateOf(false) }
    var showWeightHistory by remember { mutableStateOf(false) }
    var showBodyFatHistory by remember { mutableStateOf(false) }
    var showWorkoutHistory by remember { mutableStateOf(false) }
    var workoutPendingDelete by remember { mutableStateOf<WorkoutSession?>(null) }
    var pendingHistoryWrites by remember { mutableIntStateOf(0) }
    var completeAfterHistoryWrites by remember { mutableStateOf(false) }

    fun historyWriteFinished() {
        pendingHistoryWrites = (pendingHistoryWrites - 1).coerceAtLeast(0)
        if (pendingHistoryWrites == 0 && completeAfterHistoryWrites) {
            completeAfterHistoryWrites = false
            bridge.completeAction()
        }
    }

    fun finishHistoryAction() {
        if (pendingHistoryWrites == 0) {
            bridge.completeAction()
        } else {
            completeAfterHistoryWrites = true
        }
    }

    val snapshotProvider = rememberUpdatedState<(String) -> Map<String, Any?>> { range ->
        buildProgressSnapshot(
            rangeName = range,
            ui = ui,
            foods = foods,
            weightUnit = weightUnit,
            isDark = isDark,
            strings = strings,
            bottomContentInset = BottomNavScrollPadding.value.toDouble()
        )
    }
    LaunchedEffect(ui, foods, weightUnit, isDark, strings, bridge) {
        bridge.notifySnapshotChanged()
    }
    val actionHandler = rememberUpdatedState<(FlutterProgressAction) -> Unit> { action ->
        completeAfterHistoryWrites = false
        when (action) {
            FlutterProgressAction.LOG_WEIGHT -> showAddWeight = true
            FlutterProgressAction.LOG_BODY_FAT -> showAddBodyFat = true
            FlutterProgressAction.WEIGHT_HISTORY -> showWeightHistory = true
            FlutterProgressAction.BODY_FAT_HISTORY -> showBodyFatHistory = true
            FlutterProgressAction.WORKOUT_HISTORY -> showWorkoutHistory = true
        }
    }

    val fragmentContainerId = rememberSaveable { View.generateViewId() }
    val fragmentTag = rememberSaveable(fragmentContainerId) {
        "fud-ai-flutter-progress-$fragmentContainerId"
    }
    AndroidView(
        factory = { viewContext ->
            FragmentContainerView(viewContext).apply { id = fragmentContainerId }
        },
        modifier = Modifier.fillMaxSize()
    )

    DisposableEffect(activity, bridge, bindingOwner, fragmentContainerId, fragmentTag) {
        bridge.bind(
            owner = bindingOwner,
            snapshotProvider = { range -> snapshotProvider.value(range) },
            actionHandler = { action -> actionHandler.value(action) }
        )

        val fragmentManager = activity.supportFragmentManager
        // FragmentManager may restore Flutter before Compose has recreated this
        // dynamic container after a theme/configuration change. Such a fragment
        // owns a 0x0 view forever, so replace every restored Progress fragment
        // once the real container is present.
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
                    .filter { it.tag?.startsWith(PROGRESS_FRAGMENT_TAG_PREFIX) == true }
                    .forEach { restored -> remove(restored) }
            }
            .add(fragmentContainerId, fragment, fragmentTag)
            .commitNow()

        onDispose {
            fragmentManager.findFragmentByTag(fragmentTag)?.let { fragment ->
                fragmentManager.beginTransaction()
                    .remove(fragment)
                    .commitNowAllowingStateLoss()
            }
            bridge.unbind(bindingOwner)
        }
    }

    if (showAddWeight) {
        val seedKg = ui.entries.maxByOrNull { it.date }?.weightKg
            ?: ui.profile?.weightKg
            ?: 70.0
        AddWeightDialog(
            useMetric = weightUnit == "kg",
            initialKg = seedKg,
            onUnitChange = { metric ->
                scope.launch { container.prefs.setWeightUnit(if (metric) "kg" else "lbs") }
            },
            onDismiss = {
                showAddWeight = false
                bridge.completeAction()
            },
            onSubmit = { kg ->
                showAddWeight = false
                vm.addWeight(kg) { bridge.completeAction() }
            }
        )
    }

    if (showAddBodyFat) {
        val seedFraction = ui.bodyFatEntries.maxByOrNull { it.date }?.bodyFatFraction
            ?: ui.profile?.bodyFatPercentage
            ?: 0.20
        AddBodyFatDialog(
            initialFraction = seedFraction,
            onDismiss = {
                showAddBodyFat = false
                bridge.completeAction()
            },
            onSubmit = { fraction ->
                showAddBodyFat = false
                vm.addBodyFat(fraction) { bridge.completeAction() }
            }
        )
    }

    if (showWeightHistory) {
        AllWeightHistorySheet(
            entries = ui.entries.sortedByDescending { it.date },
            useMetric = weightUnit == "kg",
            onDelete = { id ->
                pendingHistoryWrites += 1
                vm.deleteWeight(id, ::historyWriteFinished)
            },
            onDismiss = {
                showWeightHistory = false
                finishHistoryAction()
            }
        )
    }

    if (showBodyFatHistory) {
        AllBodyFatHistorySheet(
            entries = ui.bodyFatEntries.sortedByDescending { it.date },
            onDelete = { id ->
                pendingHistoryWrites += 1
                vm.deleteBodyFat(id, ::historyWriteFinished)
            },
            onDismiss = {
                showBodyFatHistory = false
                finishHistoryAction()
            }
        )
    }

    if (showWorkoutHistory) {
        AllWorkoutHistorySheet(
            entries = ui.workoutBurnSessions,
            onRequestDelete = { workoutPendingDelete = it },
            onDismiss = {
                showWorkoutHistory = false
                finishHistoryAction()
            }
        )
    }

    workoutPendingDelete?.let { session ->
        FudGlassDialog(onDismissRequest = { workoutPendingDelete = null }) {
            Text(
                text = stringResource(R.string.progress_workout_delete_title),
                fontSize = 21.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(R.string.progress_workout_delete_message),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_delete),
                onPrimary = {
                    pendingHistoryWrites += 1
                    vm.deleteWorkoutBurn(session.id, ::historyWriteFinished)
                    workoutPendingDelete = null
                },
                dismissText = stringResource(R.string.action_cancel),
                onDismiss = { workoutPendingDelete = null },
                destructive = true
            )
        }
    }

    if (ui.goalReached) {
        FudGlassDialog(onDismissRequest = vm::dismissGoalReached) {
            Text(
                text = stringResource(R.string.progress_goal_reached_title),
                fontSize = 21.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(R.string.progress_goal_reached_message),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_keep_going),
                onPrimary = vm::dismissGoalReached
            )
        }
    }
}

internal fun progressStrings(context: Context): Map<String, String> {
    val locale = context.resources.configuration.locales[0] ?: Locale.getDefault()
    fun upper(resource: Int): String = context.getString(resource).uppercase(locale)
    return mapOf(
        "eyebrow" to upper(R.string.progress_eyebrow),
        "title" to upper(R.string.nav_progress),
        "subtitle" to context.getString(R.string.progress_subtitle),
        "weight" to upper(R.string.progress_metric_weight),
        "bodyFat" to upper(R.string.progress_metric_body_fat),
        "logWeight" to upper(R.string.progress_log_weight),
        "logBodyFat" to upper(R.string.progress_log_body_fat),
        "current" to upper(R.string.progress_stat_current),
        "goal" to upper(R.string.progress_stat_goal),
        "netChange" to upper(R.string.progress_stat_net_change),
        "average" to upper(R.string.progress_stat_average),
        "emptyWeight" to context.getString(R.string.progress_log_first_weight),
        "emptyBodyFat" to context.getString(R.string.progress_log_first_body_fat),
        "weightHistory" to upper(R.string.progress_weight_history),
        "bodyFatHistory" to upper(R.string.progress_body_fat_history),
        "workoutHistory" to upper(R.string.progress_workout_history),
        "entries" to context.getString(R.string.progress_history_entries),
        "entry" to context.getString(R.string.progress_history_entry),
        "tapToView" to context.getString(R.string.progress_history_tap_to_view),
        "calories" to upper(R.string.progress_calories_section),
        "averagePrefix" to upper(R.string.progress_average_prefix),
        "noFood" to context.getString(R.string.progress_no_food),
        "macroAverages" to upper(R.string.progress_macro_averages),
        "protein" to upper(R.string.macro_protein),
        "carbs" to upper(R.string.macro_carbs),
        "fat" to upper(R.string.macro_fat)
    )
}

private tailrec fun Context.findMainActivity(): MainActivity? = when (this) {
    is MainActivity -> this
    is ContextWrapper -> baseContext.findMainActivity()
    else -> null
}

private const val NATIVE_PROGRESS_EXTRA = "native_progress"
private const val PROGRESS_FRAGMENT_TAG_PREFIX = "fud-ai-flutter-progress-"
