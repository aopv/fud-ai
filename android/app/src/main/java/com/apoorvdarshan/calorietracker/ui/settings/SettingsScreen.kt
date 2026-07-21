package com.apoorvdarshan.calorietracker.ui.settings

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.IosShare
import androidx.compose.material.icons.automirrored.outlined.DirectionsRun
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material.icons.automirrored.outlined.DirectionsWalk
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material.icons.outlined.LocalDining
import androidx.compose.material.icons.outlined.SelfImprovement
import androidx.compose.material.icons.outlined.SportsMartialArts
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.LightMode
import androidx.compose.material.icons.outlined.SettingsBrightness
import androidx.compose.material.icons.outlined.Wc
import androidx.compose.material.icons.outlined.Female
import androidx.compose.material.icons.outlined.Male
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingFlat
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Brightness6
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.Cake
import androidx.compose.material.icons.outlined.DataUsage
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.DeleteSweep
import androidx.compose.material.icons.outlined.Equalizer
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Height
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Key
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.Numbers
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.outlined.LockOpen
import androidx.compose.material.icons.outlined.LocalFireDepartment
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.MonitorWeight
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Calculate
import androidx.compose.material.icons.outlined.Percent
import androidx.compose.material.icons.outlined.SystemUpdate
import androidx.compose.material.icons.outlined.TrackChanges
import androidx.compose.material.icons.outlined.BatteryAlert
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.SmartToy
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Speed
import androidx.compose.material.icons.outlined.Straighten
import androidx.compose.material.icons.automirrored.outlined.TrendingUp
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.IconButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.apoorvdarshan.calorietracker.R
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import com.apoorvdarshan.calorietracker.AppContainer
import com.apoorvdarshan.calorietracker.models.ActivityLevel
import com.apoorvdarshan.calorietracker.models.AIProvider
import com.apoorvdarshan.calorietracker.models.AutoBalanceMacro
import com.apoorvdarshan.calorietracker.models.Gender
import com.apoorvdarshan.calorietracker.models.MealSchedule
import com.apoorvdarshan.calorietracker.models.OptionalNutrient
import com.apoorvdarshan.calorietracker.models.OptionalNutrientGoals
import com.apoorvdarshan.calorietracker.models.SpeechLanguage
import com.apoorvdarshan.calorietracker.models.SpeechProvider
import com.apoorvdarshan.calorietracker.models.UserProfile
import com.apoorvdarshan.calorietracker.models.WeightDisplayFormatter
import com.apoorvdarshan.calorietracker.models.WeightGoal
import com.apoorvdarshan.calorietracker.models.WaterUnit
import com.apoorvdarshan.calorietracker.models.WorkoutRpeScale
import com.apoorvdarshan.calorietracker.models.WorkoutSplit
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import com.apoorvdarshan.calorietracker.ui.components.DecimalWheelPicker
import com.apoorvdarshan.calorietracker.ui.components.DateWheelPicker
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialog
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialogActions
import com.apoorvdarshan.calorietracker.ui.components.FudGlassPrimaryButton
import com.apoorvdarshan.calorietracker.ui.components.FudGlassSurface
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextButton
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextField
import com.apoorvdarshan.calorietracker.ui.components.FudIconBubble
import com.apoorvdarshan.calorietracker.ui.components.FeetInchesWheelPicker
import com.apoorvdarshan.calorietracker.ui.components.NumericWheelPicker
import com.apoorvdarshan.calorietracker.ui.components.WheelPicker
import com.apoorvdarshan.calorietracker.ui.about.AboutSettingsRows
import com.apoorvdarshan.calorietracker.ui.components.SplitDecimalWheelPicker
import com.apoorvdarshan.calorietracker.ui.components.UnitToggle
import com.apoorvdarshan.calorietracker.ui.navigation.BottomNavScrollPadding
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import com.apoorvdarshan.calorietracker.ui.theme.AppThemeColor
import com.apoorvdarshan.calorietracker.ui.navigation.FudAIRoutes
import com.apoorvdarshan.calorietracker.ui.util.clockTimePattern
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import java.util.Locale
import java.time.LocalTime
import kotlin.math.roundToInt

private enum class SettingsSheet {
    AI_PROVIDER, AI_MODEL, MAX_TOKENS, REQUEST_TIMEOUT, API_KEY, CUSTOM_BASE_URL, SPEECH_PROVIDER, SPEECH_LANGUAGE, SPEECH_KEY,
    FALLBACK_PROVIDER, FALLBACK_MODEL, FALLBACK_KEY, FALLBACK_BASE_URL,
    GENDER, BIRTHDAY, HEIGHT, WEIGHT, BODY_FAT, GOAL_BODY_FAT, ACTIVITY, GOAL, GOAL_WEIGHT, GOAL_SPEED,
    CALORIES, PROTEIN, CARBS, FAT, OPTIONAL_NUTRIENTS,
    APPEARANCE, WEEK_START, MEAL_TIMES, WATER_GOAL, WATER_UNIT, WORKOUT_SPLIT, WORKOUT_RPE
}

private enum class HealthConnectPermissionAction {
    SYNC, ENERGY_GOALS
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(container: AppContainer, nav: NavHostController, vm: SettingsViewModel) {
    val ui by vm.ui.collectAsState()
    val profile = ui.profile
    val latestMeasurement by container.bodyMeasurementRepository.latest.collectAsState(initial = null)

    var sheet by remember { mutableStateOf<SettingsSheet?>(null) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showClearFoodDialog by remember { mutableStateOf(false) }
    var showExportSheet by remember { mutableStateOf(false) }
    var invalidGoalWeightMessage by remember { mutableStateOf<String?>(null) }
    var showMaxPinnedAlert by remember { mutableStateOf(false) }
    var showRebalanceBlockedAlert by remember { mutableStateOf(false) }
    var showAdaptiveLockHint by remember { mutableStateOf(false) }
    var permissionDeniedMessage by remember { mutableStateOf<String?>(null) }
    var showHealthPermissionHelp by remember { mutableStateOf(false) }
    var showDefaultGramsInfo by remember { mutableStateOf(false) }
    var showHealthEnergyGoalsInfo by remember { mutableStateOf(false) }
    var showAdaptiveGoalsInfo by remember { mutableStateOf(false) }
    var pendingHealthPermissionAction by remember { mutableStateOf<HealthConnectPermissionAction?>(null) }
    val activityContext = LocalContext.current

    // Notifications: API 33+ requires runtime POST_NOTIFICATIONS. We only flip the
    // pref to true if the user actually grants. Denial leaves the toggle off so
    // the UI never lies about whether notifications can fire.
    val notifDeniedMsg = stringResource(R.string.settings_notifications_denied)
    val healthDeniedMsg = stringResource(R.string.settings_health_denied)
    val healthUnavailableMsg = stringResource(R.string.settings_health_unavailable)

    val notificationLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) vm.setNotificationsEnabled(true)
        else permissionDeniedMessage = notifDeniedMsg
    }

    // Health Connect honors partial grants: any granted permission connects the app, and
    // each direction is gated on its own permission downstream (issue #91). The SYNC toggle
    // accepts any grant; ENERGY_GOALS still needs the energy reads, which its VM re-checks.
    val healthConnectLauncher = rememberLauncherForActivityResult(
        contract = container.health.permissionRequestContract()
    ) { granted ->
        val action = pendingHealthPermissionAction ?: HealthConnectPermissionAction.SYNC
        pendingHealthPermissionAction = null
        if (granted.any { it in container.health.permissions }) {
            when (action) {
                HealthConnectPermissionAction.SYNC -> vm.setHealthConnectEnabled(true)
                HealthConnectPermissionAction.ENERGY_GOALS -> vm.setHealthEnergyGoalsEnabled(true)
            }
        } else {
            showHealthPermissionHelp = true
        }
    }

    fun openHealthConnectAccess() {
        runCatching { activityContext.startActivity(container.health.manageAccessIntent()) }
            .onFailure { permissionDeniedMessage = healthUnavailableMsg }
    }

    fun onNotificationsToggle(enabled: Boolean) {
        if (!enabled) {
            vm.setNotificationsEnabled(false)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            vm.setNotificationsEnabled(true)
        } else {
            val granted = ContextCompat.checkSelfPermission(
                activityContext, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (granted) vm.setNotificationsEnabled(true)
            else notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    fun onHealthConnectToggle(enabled: Boolean) {
        if (!enabled) {
            vm.setHealthConnectEnabled(false)
            return
        }
        if (!container.health.isAvailable()) {
            permissionDeniedMessage = healthUnavailableMsg
            return
        }
        // Don't pre-check granted state — Health Connect's contract handles the
        // already-granted case by returning the full set immediately.
        pendingHealthPermissionAction = HealthConnectPermissionAction.SYNC
        healthConnectLauncher.launch(container.health.permissions)
    }

    fun onHealthEnergyGoalsToggle(enabled: Boolean) {
        if (!enabled) {
            vm.setHealthEnergyGoalsEnabled(false)
            return
        }
        if (!container.health.isAvailable()) {
            permissionDeniedMessage = healthUnavailableMsg
            return
        }
        pendingHealthPermissionAction = HealthConnectPermissionAction.ENERGY_GOALS
        healthConnectLauncher.launch(container.health.permissions)
    }

    fun openBatteryOptimizationSettings() {
        val intents = listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:${activityContext.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        for (intent in intents) {
            if (runCatching { activityContext.startActivity(intent) }.isSuccess) return
        }
    }

    // iOS Settings: bare List, no NavigationBar visible. Match that — no TopAppBar.
    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Section 1 — Personal Info (matches iOS Section "Personal Info")
            SectionCard(title = stringResource(R.string.settings_section_personal)) {
                profile?.let { p ->
                    SettingRow(stringResource(R.string.settings_gender), stringResource(p.gender.displayNameRes), icon = Icons.Outlined.Person, inlineMenu = true) { sheet = SettingsSheet.GENDER }
                    HorizontalDivider()
                    SettingRow(stringResource(R.string.settings_birthday), birthdayDisplay(p), icon = Icons.Outlined.Cake) { sheet = SettingsSheet.BIRTHDAY }
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_height),
                        if (ui.heightMetric) stringResource(R.string.height_cm_format, p.heightCm.toInt())
                        else feetInchesLabel(p.heightCm.toInt()),
                        icon = Icons.Outlined.Height
                    ) { sheet = SettingsSheet.HEIGHT }
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_weight),
                        if (ui.weightMetric) String.format(Locale.US, "%.1f kg", p.weightKg)
                        else String.format(Locale.US, "%.1f lbs", p.weightKg * 2.20462),
                        icon = Icons.Outlined.MonitorWeight
                    ) { sheet = SettingsSheet.WEIGHT }
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_body_fat),
                        p.bodyFatPercentage?.let { "${(it * 100).toInt()}%" } ?: stringResource(R.string.settings_not_set),
                        icon = Icons.Outlined.Percent
                    ) { sheet = SettingsSheet.BODY_FAT }

                    // Goal Body Fat only renders when the user actually has a body
                    // fat % set — avoids surfacing irrelevant controls to users who
                    // never opted in. When body fat is set it is always used for BMR
                    // (Katch-McArdle); otherwise Mifflin-St Jeor — no manual toggle.
                    if (p.bodyFatPercentage != null) {
                        HorizontalDivider()
                        SettingRow(
                            stringResource(R.string.settings_goal_body_fat),
                            p.goalBodyFatPercentage?.let { "${(it * 100).toInt()}%" } ?: stringResource(R.string.settings_not_set),
                            icon = Icons.Outlined.TrackChanges
                        ) { sheet = SettingsSheet.GOAL_BODY_FAT }
                    }
                    HorizontalDivider()
                    // Optional tape-measure circumferences — extra signal for the AI goal calc +
                    // Coach. Never edits BMR / the body-fat field.
                    SettingRow(
                        stringResource(R.string.body_measurements_title),
                        latestMeasurement?.waistCm?.let { waist ->
                            if (ui.heightMetric) stringResource(R.string.settings_waist_cm_format, waist)
                            else stringResource(R.string.settings_waist_in_format, waist / 2.54)
                        } ?: stringResource(R.string.settings_not_set),
                        icon = Icons.Outlined.Straighten
                    ) { nav.navigate(FudAIRoutes.BODY_MEASUREMENTS) }
                }
            }

            // Section 2 — Goals & Nutrition (matches iOS Section "Goals & Nutrition")
            SectionCard(title = stringResource(R.string.settings_section_goals)) {
                profile?.let { p ->
                    SettingRow(stringResource(R.string.settings_weight_goal), stringResource(p.goal.displayNameRes), icon = Icons.Outlined.Equalizer, inlineMenu = true) { sheet = SettingsSheet.GOAL }
                    HorizontalDivider()
                    ActivityLevelSettingRow(p.activityLevel) { sheet = SettingsSheet.ACTIVITY }
                    if (p.goal != WeightGoal.MAINTAIN) {
                        HorizontalDivider()
                        SettingRow(
                            stringResource(R.string.settings_weekly_change),
                            WeightDisplayFormatter.weeklyChange(
                                kilograms = p.weeklyChangeKg ?: 0.5,
                                useMetric = ui.weightMetric
                            ),
                            icon = Icons.Outlined.Speed
                        ) { sheet = SettingsSheet.GOAL_SPEED }
                        HorizontalDivider()
                        SettingRow(
                            stringResource(R.string.settings_goal_weight),
                            p.goalWeightKg?.let {
                                if (ui.weightMetric) String.format(Locale.US, "%.1f kg", it)
                                else String.format(Locale.US, "%.1f lbs", it * 2.20462)
                            } ?: stringResource(R.string.settings_not_set),
                            icon = Icons.AutoMirrored.Outlined.TrendingUp
                        ) { sheet = SettingsSheet.GOAL_WEIGHT }
                    }
                    HorizontalDivider()
                    AdaptiveGoalsRow(
                        checked = ui.adaptiveGoalsEnabled,
                        applying = ui.applyingAdaptiveGoals,
                        onInfo = { showAdaptiveGoalsInfo = true },
                        onChange = vm::setAdaptiveGoalsEnabled
                    )
                    HorizontalDivider()
                    EnergyBurnGoalsRow(
                        checked = ui.healthEnergyGoalsEnabled,
                        applying = ui.recalculatingGoals,
                        needsHealthConnect = !ui.healthConnectEnabled,
                        onInfo = { showHealthEnergyGoalsInfo = true },
                        onChange = ::onHealthEnergyGoalsToggle
                    )
                    HorizontalDivider()
                    // The lock glyph is read-only. Saving a value locks it; the picker's Reset
                    // releases it. While Adaptive Goals is on, tapping a row explains that it owns
                    // the targets (so editing would be overwritten weekly) instead of opening.
                    val lockEnabled = !ui.adaptiveGoalsEnabled
                    val openGoal = { target: SettingsSheet ->
                        if (ui.adaptiveGoalsEnabled) showAdaptiveLockHint = true else sheet = target
                    }
                    LockableGoalRow(
                        label = stringResource(R.string.settings_calories),
                        value = stringResource(R.string.kcal_value_format, p.effectiveCalories),
                        icon = Icons.Outlined.LocalFireDepartment,
                        locked = p.caloriesLocked,
                        lockEnabled = lockEnabled,
                        onClick = { openGoal(SettingsSheet.CALORIES) }
                    )
                    HorizontalDivider()
                    LockableGoalRow(
                        label = stringResource(R.string.macro_protein),
                        value = "${p.effectiveProtein}g",
                        icon = Icons.Outlined.DataUsage,
                        locked = p.isMacroLocked(AutoBalanceMacro.PROTEIN),
                        lockEnabled = lockEnabled,
                        onClick = { openGoal(SettingsSheet.PROTEIN) }
                    )
                    HorizontalDivider()
                    LockableGoalRow(
                        label = stringResource(R.string.macro_carbs),
                        value = "${p.effectiveCarbs}g",
                        icon = Icons.Outlined.DataUsage,
                        locked = p.isMacroLocked(AutoBalanceMacro.CARBS),
                        lockEnabled = lockEnabled,
                        onClick = { openGoal(SettingsSheet.CARBS) }
                    )
                    HorizontalDivider()
                    LockableGoalRow(
                        label = stringResource(R.string.macro_fat),
                        value = "${p.effectiveFat}g",
                        icon = Icons.Outlined.DataUsage,
                        locked = p.isMacroLocked(AutoBalanceMacro.FAT),
                        lockEnabled = lockEnabled,
                        onClick = { openGoal(SettingsSheet.FAT) }
                    )
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_other_nutrient_goals),
                        optionalNutrientSummary(ui.optionalNutrientGoals),
                        icon = Icons.Outlined.DataUsage
                    ) { nav.navigate(FudAIRoutes.OPTIONAL_NUTRIENT_GOALS) }
                    HorizontalDivider()
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable(enabled = !ui.recalculatingGoals) { vm.recalculateGoals() }
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        FudIconBubble(icon = Icons.Outlined.Refresh, size = 22.dp, iconSize = 14.dp)
                        Spacer(Modifier.width(14.dp))
                        Text(
                            stringResource(R.string.settings_recalculate_goals),
                            color = if (ui.recalculatingGoals) {
                                MaterialTheme.colorScheme.onSurface.copy(alpha = 0.42f)
                            } else {
                                AppColors.Calorie
                            },
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(Modifier.weight(1f))
                        if (ui.recalculatingGoals) {
                            CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                        } else if (ui.goalsNeedRecalc) {
                            // Soft nudge: a goal input changed since the last recalc. A CTA on the
                            // row's right edge, not a wrapped line below it.
                            Text(
                                stringResource(R.string.settings_tap_to_update),
                                color = AppColors.Calorie,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_calc_methods),
                        "",
                        icon = Icons.Outlined.Calculate
                    ) { nav.navigate(FudAIRoutes.CALCULATION_METHODS) }
                }
            }

            // Section 3 — App Settings (matches iOS Section "App Settings")
            SectionCard(title = stringResource(R.string.settings_section_app)) {
                SettingRow(
                    stringResource(R.string.settings_appearance),
                    when (ui.appearanceMode) {
                        "light" -> stringResource(R.string.settings_appearance_light)
                        "dark" -> stringResource(R.string.settings_appearance_dark)
                        else -> stringResource(R.string.settings_appearance_system)
                    },
                    icon = Icons.Outlined.Brightness6
                ) { sheet = SettingsSheet.APPEARANCE }
                HorizontalDivider()
                var themeMenuExpanded by remember { mutableStateOf(false) }
                Box {
                    SettingRow(
                        stringResource(R.string.settings_theme_color),
                        stringResource(ui.appThemeColor.displayNameRes),
                        icon = Icons.Outlined.Palette,
                        inlineMenu = true
                    ) { themeMenuExpanded = true }
                    // Zero-size anchor at the row's trailing edge so the menu drops
                    // under the value text (right side), not the row's left edge.
                    Box(Modifier.align(Alignment.BottomEnd)) {
                        DropdownMenu(
                            expanded = themeMenuExpanded,
                            onDismissRequest = { themeMenuExpanded = false },
                            modifier = Modifier.heightIn(max = 420.dp)
                        ) {
                            AppThemeColor.values().forEach { themeColor ->
                                DropdownMenuItem(
                                    text = { Text(stringResource(themeColor.displayNameRes)) },
                                    leadingIcon = { ThemeColorSwatch(themeColor, Modifier.size(22.dp)) },
                                    trailingIcon = if (themeColor == ui.appThemeColor) {
                                        {
                                            Icon(
                                                Icons.Filled.Check,
                                                contentDescription = stringResource(R.string.sheet_selected_a11y),
                                                tint = AppColors.Calorie,
                                                modifier = Modifier.size(18.dp)
                                            )
                                        }
                                    } else null,
                                    onClick = {
                                        vm.setAppThemeColor(themeColor)
                                        themeMenuExpanded = false
                                    }
                                )
                            }
                        }
                    }
                }
                HorizontalDivider()
                ToggleRowWithInfo(
                    label = stringResource(R.string.settings_default_to_grams),
                    checked = ui.preferGramsByDefault,
                    icon = Icons.Outlined.LocalDining,
                    onInfo = { showDefaultGramsInfo = true },
                    onChange = vm::setPreferGramsByDefault
                )
                HorizontalDivider()
                SettingRow(
                    stringResource(R.string.settings_meal_times),
                    stringResource(R.string.settings_meal_times_customize),
                    icon = Icons.Outlined.Schedule
                ) { sheet = SettingsSheet.MEAL_TIMES }
                HorizontalDivider()
                ToggleRow(
                    stringResource(R.string.settings_water_tracking),
                    ui.waterTrackingEnabled,
                    icon = Icons.Filled.WaterDrop,
                    onChange = vm::setWaterTrackingEnabled
                )
                if (ui.waterTrackingEnabled) {
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_water_goal),
                        ui.waterUnit.format(ui.waterDailyGoalMl),
                        icon = Icons.Filled.WaterDrop
                    ) { sheet = SettingsSheet.WATER_GOAL }
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_water_unit),
                        if (ui.waterUnit == WaterUnit.MILLILITERS) {
                            stringResource(R.string.settings_water_unit_ml)
                        } else {
                            stringResource(R.string.settings_water_unit_fl_oz)
                        },
                        icon = Icons.Outlined.Straighten
                    ) { sheet = SettingsSheet.WATER_UNIT }
                }
                HorizontalDivider()
                SettingRow(
                    stringResource(R.string.settings_week_starts),
                    if (ui.weekStartsOnMonday) stringResource(R.string.settings_week_monday) else stringResource(R.string.settings_week_sunday),
                    icon = Icons.Outlined.CalendarToday
                ) { sheet = SettingsSheet.WEEK_START }
                HorizontalDivider()
                ToggleRow(stringResource(R.string.settings_notifications), ui.notificationsEnabled, icon = Icons.Outlined.Notifications, onChange = ::onNotificationsToggle)
                if (ui.notificationsEnabled) {
                    HorizontalDivider()
                    NotificationTypeRows(ui = ui, vm = vm)
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_battery_opt),
                        stringResource(R.string.settings_battery_opt_value),
                        icon = Icons.Outlined.BatteryAlert
                    ) { openBatteryOptimizationSettings() }
                }
            }

            // Section 4 — AI Provider (matches iOS Section "AI Provider")
            SectionCard(title = stringResource(R.string.settings_section_ai)) {
                SettingRow(stringResource(R.string.settings_ai_provider), stringResource(ui.selectedAI.displayNameRes), icon = Icons.Outlined.SmartToy) { sheet = SettingsSheet.AI_PROVIDER }
                HorizontalDivider()
                SettingRow(stringResource(R.string.settings_ai_model), ui.selectedModel.ifEmpty { stringResource(R.string.settings_ai_model_unset) }, icon = Icons.Outlined.Tune) { sheet = SettingsSheet.AI_MODEL }
                if (ui.selectedAI.requiresApiKey) {
                    HorizontalDivider()
                    SettingRow(stringResource(R.string.settings_api_key), ui.apiKeyMasked.ifEmpty { stringResource(R.string.settings_not_set) }, icon = Icons.Outlined.Key) { sheet = SettingsSheet.API_KEY }
                }
                if (ui.selectedAI.requiresCustomEndpoint || ui.selectedAI == AIProvider.OLLAMA) {
                    HorizontalDivider()
                    SettingRow(
                        if (ui.selectedAI.requiresCustomEndpoint) stringResource(R.string.settings_base_url) else stringResource(R.string.settings_server_url),
                        stringResource(R.string.settings_tap_to_edit),
                        icon = Icons.Outlined.Link
                    ) { sheet = SettingsSheet.CUSTOM_BASE_URL }
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_request_timeout),
                        stringResource(R.string.settings_seconds_format, ui.aiRequestTimeoutSeconds),
                        icon = Icons.Outlined.Schedule
                    ) { sheet = SettingsSheet.REQUEST_TIMEOUT }
                }
                // Only OpenAI-compatible + Anthropic send a token cap; Gemini is left
                // uncapped, so hide this for Gemini.
                if (ui.selectedAI.apiFormat != AIProvider.ApiFormat.GEMINI) {
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_max_tokens),
                        ui.maxResponseTokens.toString(),
                        icon = Icons.Outlined.Numbers
                    ) { sheet = SettingsSheet.MAX_TOKENS }
                }
            }

            // Section 4b — Custom AI Instructions (matches iOS Section)
            SectionCard(title = stringResource(R.string.settings_section_custom_instructions)) {
                CustomInstructionsBlock(
                    initial = ui.userContext,
                    placeholder = stringResource(R.string.settings_custom_instructions_placeholder),
                    onSave = { vm.setUserContext(it) }
                )
                Text(
                    stringResource(R.string.settings_custom_instructions_footer),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
                )
            }

            // Section 4c — Fallback Provider (matches iOS Section)
            SectionCard(title = stringResource(R.string.settings_section_fallback)) {
                ToggleRow(
                    stringResource(R.string.settings_enable_fallback),
                    ui.fallbackEnabled,
                    icon = Icons.Outlined.Refresh,
                    onChange = { vm.setFallbackEnabled(it) }
                )
                if (ui.fallbackEnabled) {
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_ai_provider),
                        stringResource(ui.fallbackProvider.displayNameRes),
                        icon = Icons.Outlined.SmartToy
                    ) { sheet = SettingsSheet.FALLBACK_PROVIDER }
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_ai_model),
                        ui.fallbackModel.ifEmpty { stringResource(R.string.settings_ai_model_unset) },
                        icon = Icons.Outlined.Tune
                    ) { sheet = SettingsSheet.FALLBACK_MODEL }
                    if (ui.fallbackProvider.requiresApiKey) {
                        HorizontalDivider()
                        SettingRow(
                            stringResource(R.string.settings_api_key),
                            ui.fallbackApiKeyMasked.ifEmpty { stringResource(R.string.settings_not_set) },
                            icon = Icons.Outlined.Key
                        ) { sheet = SettingsSheet.FALLBACK_KEY }
                    }
                    if (ui.fallbackProvider.requiresCustomEndpoint || ui.fallbackProvider == AIProvider.OLLAMA) {
                        HorizontalDivider()
                        SettingRow(
                            if (ui.fallbackProvider.requiresCustomEndpoint) stringResource(R.string.settings_base_url) else stringResource(R.string.settings_server_url),
                            stringResource(R.string.settings_tap_to_edit),
                            icon = Icons.Outlined.Link
                        ) { sheet = SettingsSheet.FALLBACK_BASE_URL }
                        if (!ui.selectedAI.usesConfigurableRequestTimeout) {
                            HorizontalDivider()
                            SettingRow(
                                stringResource(R.string.settings_request_timeout),
                                stringResource(R.string.settings_seconds_format, ui.aiRequestTimeoutSeconds),
                                icon = Icons.Outlined.Schedule
                            ) { sheet = SettingsSheet.REQUEST_TIMEOUT }
                        }
                    }
                    Text(
                        stringResource(R.string.settings_fallback_footer),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
                    )
                }
            }

            // Section 5 — Speech-to-Text (matches iOS Section "Speech-to-Text")
            SectionCard(title = stringResource(R.string.settings_section_speech)) {
                SettingRow(stringResource(R.string.settings_ai_provider), stringResource(ui.selectedSpeech.displayNameRes), icon = Icons.Outlined.Mic) { sheet = SettingsSheet.SPEECH_PROVIDER }
                HorizontalDivider()
                SettingRow(
                    stringResource(R.string.settings_speech_language),
                    stringResource(ui.selectedSpeechLanguage.displayNameRes),
                    icon = Icons.Outlined.Language
                ) { sheet = SettingsSheet.SPEECH_LANGUAGE }
                HorizontalDivider()
                Text(
                    stringResource(ui.selectedSpeech.descriptionRes),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
                )
                if (ui.selectedSpeech.requiresApiKey) {
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_api_key),
                        ui.speechApiKeyMasked.ifEmpty { stringResource(R.string.settings_not_set) },
                        icon = Icons.Outlined.Key
                    ) { sheet = SettingsSheet.SPEECH_KEY }
                }
            }

            // Workout is permanently available. Keep its only two live
            // preferences in the same compact Fud AI settings card.
            SectionCard(title = stringResource(R.string.settings_section_workout)) {
                SettingRow(
                    stringResource(R.string.settings_training_split),
                    ui.workoutSplit.title,
                    icon = Icons.Outlined.FitnessCenter,
                    inlineMenu = true
                ) { sheet = SettingsSheet.WORKOUT_SPLIT }
                HorizontalDivider()
                SettingRow(
                    stringResource(R.string.settings_rpe_scale),
                    ui.workoutRpeScale.title,
                    icon = Icons.Outlined.Speed,
                    inlineMenu = true
                ) { sheet = SettingsSheet.WORKOUT_RPE }
                HorizontalDivider()
                Text(
                    stringResource(R.string.settings_rpe_guide),
                    fontSize = 12.sp,
                    lineHeight = 18.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
                )
            }

            // Section 6 — Health & Data (matches iOS Section "Health & Data")
            SectionCard(title = stringResource(R.string.settings_section_health)) {
                ToggleRow(stringResource(R.string.settings_health_connect), ui.healthConnectEnabled, icon = Icons.Outlined.Favorite, onChange = ::onHealthConnectToggle)
                if (ui.healthConnectEnabled && !ui.workoutHealthWriteGranted) {
                    HorizontalDivider()
                    SettingRow(
                        stringResource(R.string.settings_workout_health_access),
                        stringResource(R.string.settings_grant_permission),
                        icon = Icons.Outlined.LocalFireDepartment
                    ) {
                        pendingHealthPermissionAction = HealthConnectPermissionAction.SYNC
                        healthConnectLauncher.launch(container.health.permissions)
                    }
                }
                HorizontalDivider()
                SettingRow(
                    stringResource(R.string.settings_manage_health_access),
                    stringResource(R.string.settings_permissions),
                    icon = Icons.Outlined.Link,
                    onClick = ::openHealthConnectAccess
                )
                HorizontalDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { showExportSheet = true }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    FudIconBubble(icon = Icons.Outlined.IosShare, size = 22.dp, iconSize = 14.dp, tint = AppColors.Calorie)
                    Spacer(Modifier.width(14.dp))
                    Text(
                        stringResource(R.string.export_diary_title),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                }
                HorizontalDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { showClearFoodDialog = true }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val warning = Color(0xFFFF9500)
                    FudIconBubble(icon = Icons.Outlined.DeleteSweep, size = 22.dp, iconSize = 14.dp, tint = warning)
                    Spacer(Modifier.width(14.dp))
                    Text(
                        stringResource(R.string.settings_clear_food_log),
                        color = warning,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                }
                HorizontalDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { showDeleteDialog = true }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val destructive = Color(0xFFFF3B30)
                    FudIconBubble(icon = Icons.Outlined.DeleteForever, size = 22.dp, iconSize = 14.dp, tint = destructive)
                    Spacer(Modifier.width(14.dp))
                    Text(
                        stringResource(R.string.settings_delete_all_data),
                        color = destructive,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // Section 7 — About (folded in from the former About tab so it's the
            // last section of Settings; tabs are now Home / Progress / Coach / Settings).
            SectionCard(title = stringResource(R.string.nav_about)) {
                AboutSettingsRows(container)
            }

            Spacer(Modifier.height(BottomNavScrollPadding))
        }
    }

    if (showExportSheet) {
        ExportDiarySheet(
            container = container,
            profile = profile,
            onDismiss = { showExportSheet = false },
        )
    }

    sheet?.let { s ->
        SettingsSheets(
            sheet = s,
            ui = ui,
            vm = vm,
            onDismiss = { sheet = null },
            onInvalidGoalWeight = { invalidGoalWeightMessage = it },
            onRebalanceBlocked = { showRebalanceBlockedAlert = true }
        )
    }

    if (showClearFoodDialog) {
        FudGlassDialog(onDismissRequest = { showClearFoodDialog = false }) {
            Text(stringResource(R.string.settings_clear_food_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_clear_food_message),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_clear),
                onPrimary = {
                    vm.clearFoodLog()
                    showClearFoodDialog = false
                },
                dismissText = stringResource(R.string.action_cancel),
                onDismiss = { showClearFoodDialog = false },
                destructive = true
            )
        }
    }

    if (showDeleteDialog) {
        val context = LocalContext.current
        FudGlassDialog(onDismissRequest = { showDeleteDialog = false }) {
            Text(stringResource(R.string.settings_delete_all_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_delete_all_message),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_delete),
                onPrimary = {
                    vm.deleteAllData {
                        showDeleteDialog = false
                        (context as? android.app.Activity)?.recreate()
                    }
                },
                dismissText = stringResource(R.string.action_cancel),
                onDismiss = { showDeleteDialog = false },
                destructive = true
            )
        }
    }

    if (showMaxPinnedAlert) {
        FudGlassDialog(onDismissRequest = { showMaxPinnedAlert = false }) {
            Text(stringResource(R.string.settings_max_pinned_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_max_pinned_message),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { showMaxPinnedAlert = false }
            )
        }
    }

    if (showRebalanceBlockedAlert) {
        FudGlassDialog(onDismissRequest = { showRebalanceBlockedAlert = false }) {
            Text(stringResource(R.string.settings_rebalance_blocked_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_rebalance_blocked_message),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { showRebalanceBlockedAlert = false }
            )
        }
    }

    if (showAdaptiveLockHint) {
        FudGlassDialog(onDismissRequest = { showAdaptiveLockHint = false }) {
            Text(stringResource(R.string.settings_adaptive_locks_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_adaptive_locks_message),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { showAdaptiveLockHint = false }
            )
        }
    }

    if (showDefaultGramsInfo) {
        FudGlassDialog(onDismissRequest = { showDefaultGramsInfo = false }) {
            Text(stringResource(R.string.settings_default_to_grams), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_default_to_grams_info),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { showDefaultGramsInfo = false }
            )
        }
    }

    if (showHealthEnergyGoalsInfo) {
        FudGlassDialog(onDismissRequest = { showHealthEnergyGoalsInfo = false }) {
            Text(stringResource(R.string.settings_energy_goals), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_energy_goals_info),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { showHealthEnergyGoalsInfo = false }
            )
        }
    }

    if (showAdaptiveGoalsInfo) {
        FudGlassDialog(onDismissRequest = { showAdaptiveGoalsInfo = false }) {
            Text(stringResource(R.string.settings_adaptive_goals), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                stringResource(R.string.settings_adaptive_goals_info),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { showAdaptiveGoalsInfo = false }
            )
        }
    }

    val energyAlertTitle = ui.healthEnergyGoalAlertTitle
    val energyAlertMessage = ui.healthEnergyGoalAlertMessage
    if (energyAlertTitle != null && energyAlertMessage != null) {
        FudGlassDialog(onDismissRequest = { vm.dismissHealthEnergyGoalAlert() }) {
            Text(energyAlertTitle, fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                energyAlertMessage,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { vm.dismissHealthEnergyGoalAlert() }
            )
        }
    }

    val adaptiveAlertTitle = ui.adaptiveGoalAlertTitle
    val adaptiveAlertMessage = ui.adaptiveGoalAlertMessage
    if (adaptiveAlertTitle != null && adaptiveAlertMessage != null) {
        FudGlassDialog(onDismissRequest = { vm.dismissAdaptiveGoalAlert() }) {
            Text(adaptiveAlertTitle, fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(
                adaptiveAlertMessage,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { vm.dismissAdaptiveGoalAlert() }
            )
        }
    }

    invalidGoalWeightMessage?.let { msg ->
        FudGlassDialog(onDismissRequest = { invalidGoalWeightMessage = null }) {
            Text(stringResource(R.string.settings_invalid_goal_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(msg, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f))
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { invalidGoalWeightMessage = null }
            )
        }
    }

    permissionDeniedMessage?.let { msg ->
        FudGlassDialog(onDismissRequest = { permissionDeniedMessage = null }) {
            Text(stringResource(R.string.settings_permission_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(msg, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f))
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_ok),
                onPrimary = { permissionDeniedMessage = null }
            )
        }
    }

    if (showHealthPermissionHelp) {
        FudGlassDialog(onDismissRequest = { showHealthPermissionHelp = false }) {
            Text(stringResource(R.string.settings_permission_title), fontSize = 21.sp, fontWeight = FontWeight.Bold)
            Text(healthDeniedMsg, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f))
            FudGlassDialogActions(
                primaryText = stringResource(R.string.settings_manage_health_access),
                onPrimary = {
                    showHealthPermissionHelp = false
                    openHealthConnectAccess()
                },
                dismissText = stringResource(R.string.action_cancel),
                onDismiss = { showHealthPermissionHelp = false }
            )
        }
    }
}

@Composable
private fun NotificationTypeRows(ui: SettingsUiState, vm: SettingsViewModel) {
    Text(
        stringResource(R.string.settings_notification_types),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
    )
    ToggleRow(
        stringResource(R.string.settings_notif_food_reminders),
        ui.streakReminderEnabled,
        icon = Icons.Outlined.LocalDining,
        onChange = vm::setStreakReminderEnabled
    )
    HorizontalDivider()
    ToggleRow(
        stringResource(R.string.settings_notif_daily_summary),
        ui.dailySummaryEnabled,
        icon = Icons.Outlined.GraphicEq,
        onChange = vm::setDailySummaryEnabled
    )
    HorizontalDivider()
    ToggleRow(
        stringResource(R.string.settings_notif_weight_reminder),
        ui.weightReminderEnabled,
        icon = Icons.Outlined.MonitorWeight,
        onChange = vm::setWeightReminderEnabled
    )
    HorizontalDivider()
    ToggleRow(
        stringResource(R.string.settings_notif_body_fat_reminder),
        ui.bodyFatReminderEnabled,
        icon = Icons.Outlined.Percent,
        onChange = vm::setBodyFatReminderEnabled
    )
    if (ui.waterTrackingEnabled) {
        HorizontalDivider()
        ToggleRow(
            stringResource(R.string.settings_notif_water_reminder),
            ui.waterReminderEnabled,
            icon = Icons.Filled.WaterDrop,
            onChange = vm::setWaterReminderEnabled
        )
    }
    HorizontalDivider()
    ToggleRow(
        stringResource(R.string.settings_notif_goal_alerts),
        ui.goalReachedNotificationsEnabled,
        icon = Icons.Outlined.TrackChanges,
        onChange = vm::setGoalReachedNotificationsEnabled
    )
    HorizontalDivider()
    ToggleRow(
        stringResource(R.string.settings_notif_app_updates),
        ui.appUpdateNotificationsEnabled,
        icon = Icons.Outlined.SystemUpdate,
        onChange = vm::setAppUpdateNotificationsEnabled
    )
    val noneSelected = !ui.streakReminderEnabled &&
        !ui.dailySummaryEnabled &&
        !ui.weightReminderEnabled &&
        !ui.bodyFatReminderEnabled &&
        (!ui.waterTrackingEnabled || !ui.waterReminderEnabled) &&
        !ui.goalReachedNotificationsEnabled &&
        !ui.appUpdateNotificationsEnabled
    if (noneSelected) {
        Text(
            stringResource(R.string.settings_notif_none_selected),
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp)
        )
    }
}

@Composable
fun OptionalNutrientGoalsScreen(
    container: AppContainer,
    onBack: () -> Unit
) {
    val vm: SettingsViewModel = viewModel(factory = SettingsViewModel.Factory(container))
    val ui by vm.ui.collectAsState()
    var editing by remember { mutableStateOf<OptionalNutrient?>(null) }

    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                top = 14.dp,
                bottom = BottomNavScrollPadding
            ),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Row(
                    Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(16.dp))
                            .clickable { onBack() }
                            .padding(horizontal = 2.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = null,
                            tint = AppColors.Calorie,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(
                            stringResource(R.string.nav_settings),
                            color = AppColors.Calorie,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            item {
                Text(
                    stringResource(R.string.settings_other_nutrient_goals),
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground
                )
            }
            item {
                FudGlassSurface(
                    modifier = Modifier.fillMaxWidth(),
                    cornerRadius = 22.dp,
                    padding = 0.dp
                ) {
                    Column {
                        OptionalNutrient.values().forEachIndexed { index, nutrient ->
                            OptionalNutrientGoalRow(
                                nutrient = nutrient,
                                value = ui.optionalNutrientGoals.valueFor(nutrient),
                                onClick = { editing = nutrient }
                            )
                            if (index != OptionalNutrient.values().lastIndex) {
                                HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                            }
                        }
                    }
                }
            }

            item {
                Text(
                    "Separate from calorie, protein, carb, and fat goals.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.55f),
                    modifier = Modifier.padding(start = 4.dp, top = 4.dp)
                )
            }
        }
    }

    editing?.let { nutrient ->
        FudGlassDialog(onDismissRequest = { editing = null }) {
            NutritionPickerSheet(
                label = stringResource(nutrient.displayNameRes),
                unit = stringResource(nutrient.unitRes),
                currentValue = ui.optionalNutrientGoals.valueFor(nutrient),
                range = nutrient.pickerRange(),
                step = nutrient.pickerStep(),
                onSave = { value ->
                    vm.setOptionalNutrientGoals(ui.optionalNutrientGoals.withValue(nutrient, value))
                    editing = null
                }
            )
            FudGlassTextButton(
                text = stringResource(R.string.action_cancel),
                onClick = { editing = null },
                modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f)
            )
        }
    }
}

/**
 * Port of iOS CalculationMethodsView. Documents every formula Fud AI uses as the reference its AI
 * goal calculation starts from (BMR, TDEE, calorie target, macro split) plus per-meal estimates,
 * with peer-reviewed sources. Styled to match the rest of Android Settings (glass cards, back row,
 * 28sp title). Reachable from Settings → Goals & Nutrition → Calculation Methods.
 */
@Composable
fun CalculationMethodsScreen(
    onBack: () -> Unit
) {
    Scaffold(containerColor = MaterialTheme.colorScheme.background) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                top = 14.dp,
                bottom = BottomNavScrollPadding
            ),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            item {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(16.dp))
                            .clickable { onBack() }
                            .padding(horizontal = 2.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = null,
                            tint = AppColors.Calorie,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(R.string.nav_settings), color = AppColors.Calorie, fontWeight = FontWeight.SemiBold)
                    }
                }
            }

            item {
                Text(
                    stringResource(R.string.settings_calc_methods),
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.settings_calc_intro),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.62f)
                )
            }

            item {
                CalcMethodSection(stringResource(R.string.settings_calc_sec_bmr)) {
                    CalcFormulaCard(
                        name = stringResource(R.string.settings_calc_mifflin_name),
                        usedWhen = stringResource(R.string.settings_calc_mifflin_used),
                        formula = stringResource(R.string.settings_calc_mifflin_formula),
                        citation = "Mifflin MD, St Jeor ST, et al. (1990). \"A new predictive equation for resting energy expenditure in healthy individuals.\" Am J Clin Nutr 51(2):241–247.",
                        url = "https://pubmed.ncbi.nlm.nih.gov/2305711/"
                    )
                    CalcFormulaCard(
                        name = stringResource(R.string.settings_calc_katch_name),
                        usedWhen = stringResource(R.string.settings_calc_katch_used),
                        formula = stringResource(R.string.settings_calc_katch_formula),
                        citation = "McArdle WD, Katch FI, Katch VL. Exercise Physiology: Nutrition, Energy, and Human Performance, 7th ed. Lippincott Williams & Wilkins, 2010.",
                        url = null
                    )
                }
            }

            item {
                CalcMethodSection(stringResource(R.string.settings_calc_sec_tdee)) {
                    CalcFormulaCard(
                        name = stringResource(R.string.settings_calc_tdee_name),
                        usedWhen = stringResource(R.string.settings_calc_tdee_used),
                        formula = stringResource(R.string.settings_calc_tdee_formula),
                        citation = "Standard PAL (Physical Activity Level) coefficients from FAO/WHO/UNU joint expert consultation on human energy requirements (2001). Also widely used by ACSM and USDA Dietary Guidelines.",
                        url = "https://www.fao.org/3/y5686e/y5686e00.htm"
                    )
                }
            }

            item {
                CalcMethodSection(stringResource(R.string.settings_calc_calorie_target)) {
                    CalcFormulaCard(
                        name = stringResource(R.string.settings_calc_target_name),
                        usedWhen = stringResource(R.string.settings_calc_target_used),
                        formula = stringResource(R.string.settings_calc_target_formula),
                        citation = "Hall KD, et al. (2011). \"Quantification of the effect of energy imbalance on bodyweight.\" Lancet 378(9793):826–837. The classic 3,500-kcal-per-pound rule originates from Wishnofsky M (1958), Am J Clin Nutr 6:542–546.",
                        url = "https://www.thelancet.com/journals/lancet/article/PIIS0140-6736(11)60812-X/fulltext"
                    )
                }
            }

            item {
                CalcMethodSection(stringResource(R.string.settings_calc_macro_split)) {
                    CalcFormulaCard(
                        name = stringResource(R.string.settings_calc_split_name),
                        usedWhen = stringResource(R.string.settings_calc_split_used),
                        formula = stringResource(R.string.settings_calc_split_formula),
                        citation = "Morton RW, et al. (2018). \"A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength.\" Br J Sports Med 52(6):376–384.",
                        url = "https://bjsm.bmj.com/content/52/6/376"
                    )
                }
            }

            item {
                CalcMethodSection(stringResource(R.string.settings_calc_micro_values)) {
                    CalcFormulaCard(
                        name = stringResource(R.string.settings_calc_micro_name),
                        usedWhen = stringResource(R.string.settings_calc_micro_used),
                        formula = null,
                        citation = "Estimates rely on the underlying AI model's training data (USDA FoodData Central, manufacturer panels, scientific literature). Accuracy varies by food, portion-size visibility, and provider model. Always cross-check labels for foods you log frequently.",
                        url = "https://fdc.nal.usda.gov/"
                    )
                }
            }

            item {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(Color(0xFFFF9800).copy(alpha = 0.09f))
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        stringResource(R.string.settings_not_medical_title),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                    Text(
                        stringResource(R.string.settings_not_medical_body),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}

@Composable
private fun CalcMethodSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.padding(start = 4.dp)
        )
        content()
    }
}

@Composable
private fun CalcFormulaCard(
    name: String,
    usedWhen: String,
    formula: String?,
    citation: String,
    url: String?
) {
    val uriHandler = LocalUriHandler.current
    FudGlassSurface(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 18.dp,
        padding = 14.dp
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                name,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                usedWhen,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f)
            )
            if (formula != null) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f))
                        .padding(10.dp)
                ) {
                    Text(
                        formula,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f)
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "SOURCE",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f)
                )
                Text(
                    citation,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
                if (url != null) {
                    Text(
                        "Open source ↗",
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.Calorie,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .clickable { uriHandler.openUri(url) }
                            .padding(vertical = 2.dp)
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsSheets(
    sheet: SettingsSheet,
    ui: SettingsUiState,
    vm: SettingsViewModel,
    onDismiss: () -> Unit,
    onInvalidGoalWeight: (String) -> Unit,
    onRebalanceBlocked: () -> Unit
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val invalidLoseMsg = stringResource(R.string.settings_invalid_goal_lose)
    val invalidGainMsg = stringResource(R.string.settings_invalid_goal_gain)
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = if (isDark) Color(0xF2141416) else Color(0xFFFAF3EE)
    ) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
            when (sheet) {
                SettingsSheet.AI_PROVIDER -> ListSheet(
                    title = stringResource(R.string.sheet_ai_provider),
                    items = AIProvider.values().toList(),
                    label = { stringResource(it.displayNameRes) },
                    selected = { it == ui.selectedAI },
                    onSelect = { vm.selectProvider(it); onDismiss() }
                )
                SettingsSheet.AI_MODEL -> ListSheet(
                    title = stringResource(R.string.sheet_model),
                    items = ui.selectedAI.models,
                    label = { it },
                    selected = { it == ui.selectedModel },
                    onSelect = { vm.selectModel(it); onDismiss() },
                    footer = if (ui.selectedAI.supportsCustomModelName) stringResource(R.string.sheet_model_footer) else null,
                    customField = if (ui.selectedAI.supportsCustomModelName) {
                        { m -> vm.selectModel(m); onDismiss() }
                    } else null
                )
                SettingsSheet.API_KEY -> ApiKeySheet(
                    title = stringResource(R.string.sheet_api_key_format, stringResource(ui.selectedAI.displayNameRes)),
                    placeholder = stringResource(ui.selectedAI.apiKeyPlaceholderRes),
                    onSave = { vm.setApiKey(it); onDismiss() }
                )
                SettingsSheet.CUSTOM_BASE_URL -> {
                    val existing = remember { runBlocking { vm.container.prefs.customBaseUrl(ui.selectedAI).first().orEmpty() } }
                    TextFieldSheet(
                        title = stringResource(R.string.settings_custom_url_title),
                        initial = existing,
                        placeholder = stringResource(R.string.settings_custom_url_placeholder),
                        onSave = { vm.setCustomBaseUrl(ui.selectedAI, it); onDismiss() }
                    )
                }
                SettingsSheet.MAX_TOKENS -> {
                    TextFieldSheet(
                        title = stringResource(R.string.settings_max_tokens),
                        initial = ui.maxResponseTokens.toString(),
                        placeholder = "1024",
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        onSave = { it.trim().toIntOrNull()?.let(vm::setMaxResponseTokens); onDismiss() }
                    )
                }
                SettingsSheet.REQUEST_TIMEOUT -> {
                    TextFieldSheet(
                        title = stringResource(R.string.settings_request_timeout),
                        initial = ui.aiRequestTimeoutSeconds.toString(),
                        placeholder = AIProvider.DEFAULT_REQUEST_TIMEOUT_SECONDS.toString(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        onSave = {
                            it.trim().toIntOrNull()?.let(vm::setAiRequestTimeoutSeconds)
                            onDismiss()
                        }
                    )
                }
                SettingsSheet.SPEECH_PROVIDER -> ListSheet(
                    title = stringResource(R.string.sheet_speech_engine),
                    items = SpeechProvider.values().toList(),
                    label = { stringResource(it.displayNameRes) },
                    selected = { it == ui.selectedSpeech },
                    onSelect = { vm.selectSpeech(it); onDismiss() }
                )
                SettingsSheet.SPEECH_LANGUAGE -> ListSheet(
                    title = stringResource(R.string.sheet_speech_language),
                    items = SpeechLanguage.optionsFor(ui.selectedSpeech),
                    label = { stringResource(it.displayNameRes) },
                    selected = { it == ui.selectedSpeechLanguage },
                    onSelect = { vm.selectSpeechLanguage(it); onDismiss() },
                    subtitle = {
                        when (it) {
                            SpeechLanguage.PROVIDER_AUTO -> stringResource(R.string.speech_language_provider_auto_subtitle)
                            SpeechLanguage.DEVICE -> stringResource(R.string.speech_language_device_subtitle)
                            else -> null
                        }
                    }
                )
                SettingsSheet.SPEECH_KEY -> ApiKeySheet(
                    title = stringResource(R.string.sheet_speech_api_key_format, stringResource(ui.selectedSpeech.displayNameRes)),
                    placeholder = stringResource(ui.selectedSpeech.apiKeyPlaceholderRes),
                    onSave = {
                        // Route through the VM so SettingsUiState.speechApiKeyMasked
                        // updates and the API Key row reflects the new value
                        // (was bypassing the VM and writing straight to KeyStore,
                        // which left the UI showing "Tap to edit" forever).
                        vm.setSpeechApiKey(it)
                        onDismiss()
                    }
                )
                SettingsSheet.WORKOUT_SPLIT -> ListSheet(
                    title = stringResource(R.string.settings_training_split),
                    items = WorkoutSplit.SelectableValues,
                    label = { it.title },
                    selected = { it == ui.workoutSplit },
                    onSelect = { vm.selectWorkoutSplit(it); onDismiss() }
                )
                SettingsSheet.WORKOUT_RPE -> ListSheet(
                    title = stringResource(R.string.settings_rpe_scale),
                    items = WorkoutRpeScale.entries,
                    label = { it.title },
                    selected = { it == ui.workoutRpeScale },
                    onSelect = { vm.selectWorkoutRpeScale(it); onDismiss() },
                    subtitle = { it.inputPlaceholder }
                )
                SettingsSheet.FALLBACK_PROVIDER -> ListSheet(
                    title = stringResource(R.string.sheet_ai_provider),
                    items = AIProvider.values().toList(),
                    label = { stringResource(it.displayNameRes) },
                    selected = { it == ui.fallbackProvider },
                    onSelect = { vm.selectFallbackProvider(it); onDismiss() }
                )
                SettingsSheet.FALLBACK_MODEL -> {
                    // Same provider as primary → exclude primary's selected model so
                    // fallback can't be a literal duplicate config.
                    val opts = if (ui.fallbackProvider == ui.selectedAI)
                        ui.fallbackProvider.models.filter { it != ui.selectedModel }
                    else ui.fallbackProvider.models
                    ListSheet(
                        title = stringResource(R.string.sheet_model),
                        items = opts,
                        label = { it },
                        selected = { it == ui.fallbackModel },
                        onSelect = { vm.selectFallbackModel(it); onDismiss() },
                        footer = if (ui.fallbackProvider.supportsCustomModelName) stringResource(R.string.sheet_model_footer) else null,
                        customField = if (ui.fallbackProvider.supportsCustomModelName) {
                            { m -> vm.selectFallbackModel(m); onDismiss() }
                        } else null
                    )
                }
                SettingsSheet.FALLBACK_KEY -> ApiKeySheet(
                    title = stringResource(R.string.sheet_api_key_format, stringResource(ui.fallbackProvider.displayNameRes)),
                    placeholder = stringResource(ui.fallbackProvider.apiKeyPlaceholderRes),
                    onSave = { vm.setFallbackApiKey(it); onDismiss() }
                )
                SettingsSheet.FALLBACK_BASE_URL -> {
                    val existing = remember { runBlocking { vm.container.prefs.customBaseUrl(ui.fallbackProvider).first().orEmpty() } }
                    TextFieldSheet(
                        title = stringResource(R.string.settings_custom_url_title),
                        initial = existing,
                        placeholder = stringResource(R.string.settings_custom_url_placeholder),
                        onSave = { vm.setCustomBaseUrl(ui.fallbackProvider, it); onDismiss() }
                    )
                }
                SettingsSheet.GENDER -> ListSheet(
                    title = stringResource(R.string.sheet_gender),
                    items = Gender.values().toList(),
                    label = { stringResource(it.displayNameRes) },
                    selected = { it == ui.profile?.gender },
                    onSelect = { g -> vm.updateProfile { it.copy(gender = g) }; onDismiss() },
                    icon = { genderIcon(it) }
                )
                SettingsSheet.HEIGHT -> {
                    val cm = ui.profile?.heightCm?.toInt() ?: 175
                    HeightSheet(
                        current = cm,
                        useMetric = ui.heightMetric,
                        onUnitChange = { metric -> vm.setHeightUnit(if (metric) "cm" else "ftin") },
                        onSave = { newCm -> vm.updateProfile { it.copy(heightCm = newCm.toDouble()) }; onDismiss() }
                    )
                }
                SettingsSheet.WEIGHT -> {
                    val kg = ui.profile?.weightKg ?: 70.0
                    WeightSheet(
                        titleText = stringResource(R.string.sheet_weight),
                        current = kg,
                        useMetric = ui.weightMetric,
                        onUnitChange = { metric -> vm.setWeightUnit(if (metric) "kg" else "lbs") },
                        onSave = { newKg -> vm.saveCurrentWeight(newKg); onDismiss() }
                    )
                }
                SettingsSheet.BODY_FAT -> BodyFatSheet(
                    current = ui.profile?.bodyFatPercentage,
                    // Clearing the current value also clears the goal so a stale
                    // goal doesn't linger on someone who opted out of the
                    // body-fat track entirely.
                    onSave = { bf ->
                        vm.updateProfile {
                            it.copy(
                                bodyFatPercentage = bf,
                                goalBodyFatPercentage = if (bf == null) null else it.goalBodyFatPercentage
                            )
                        }
                        onDismiss()
                    }
                )
                SettingsSheet.GOAL_BODY_FAT -> GoalBodyFatSheet(
                    currentGoal = ui.profile?.goalBodyFatPercentage,
                    currentBodyFat = ui.profile?.bodyFatPercentage,
                    // Goal body fat doesn't feed BMR/TDEE/macro math, so use
                    // updateProfile (no recompute) — editing the goal must
                    // never silently wipe the user's pinned macros.
                    onSave = { goal -> vm.updateProfile { it.copy(goalBodyFatPercentage = goal) }; onDismiss() }
                )
                SettingsSheet.ACTIVITY -> ListSheet(
                    title = stringResource(R.string.sheet_activity_level),
                    items = ActivityLevel.values().toList(),
                    label = { stringResource(it.displayNameRes) },
                    subtitle = { stringResource(it.subtitleRes) },
                    selected = { it == ui.profile?.activityLevel },
                    onSelect = { a -> vm.updateProfile { it.copy(activityLevel = a) }; onDismiss() },
                    icon = { activityIcon(it) }
                )
                SettingsSheet.GOAL -> ListSheet(
                    title = stringResource(R.string.sheet_goal),
                    items = WeightGoal.values().toList(),
                    label = { stringResource(it.displayNameRes) },
                    selected = { it == ui.profile?.goal },
                    icon = { goalIcon(it) },
                    onSelect = { g ->
                        // Mirrors iOS ContentView.swift profile.goal onChange:
                        //   - Switching to MAINTAIN clears weeklyChangeKg + goalWeightKg.
                        //   - Switching to LOSE/GAIN seeds weeklyChangeKg if missing and
                        //     clears goalWeightKg if it now contradicts the new direction.
                        // Then recompute calories+macros from the new goal.
                        vm.updateProfile { p ->
                            when (g) {
                                WeightGoal.MAINTAIN ->
                                    p.copy(goal = g, weeklyChangeKg = null, goalWeightKg = null)
                                else -> {
                                    val gw = p.goalWeightKg
                                    val mismatched = gw != null && (
                                        (g == WeightGoal.LOSE && gw >= p.weightKg) ||
                                        (g == WeightGoal.GAIN && gw <= p.weightKg)
                                    )
                                    p.copy(
                                        goal = g,
                                        weeklyChangeKg = p.weeklyChangeKg ?: 0.5,
                                        goalWeightKg = if (mismatched) null else p.goalWeightKg
                                    )
                                }
                            }
                        }
                        onDismiss()
                    }
                )
                SettingsSheet.GOAL_WEIGHT -> {
                    val kg = ui.profile?.goalWeightKg ?: (ui.profile?.weightKg ?: 70.0)
                    WeightSheet(
                        titleText = stringResource(R.string.sheet_target_weight),
                        current = kg,
                        useMetric = ui.weightMetric,
                        onUnitChange = { metric -> vm.setWeightUnit(if (metric) "kg" else "lbs") },
                        onSave = { newKg ->
                            // Mirrors iOS ContentView.swift case .editGoalWeight: a Lose goal
                            // requires target < current weight; a Gain goal requires target >
                            // current weight. Reject mismatched targets with an alert instead
                            // of silently saving an unreachable goal.
                            val p = ui.profile
                            val current = p?.weightKg
                            val invalid = p != null && current != null && (
                                (p.goal == WeightGoal.LOSE && newKg >= current) ||
                                (p.goal == WeightGoal.GAIN && newKg <= current)
                            )
                            if (invalid) {
                                onInvalidGoalWeight(
                                    if (p!!.goal == WeightGoal.LOSE)
                                        invalidLoseMsg
                                    else
                                        invalidGainMsg
                                )
                            } else {
                                vm.updateProfile { it.copy(goalWeightKg = newKg) }
                                onDismiss()
                            }
                        }
                    )
                }
                SettingsSheet.GOAL_SPEED -> GoalSpeedSheet(
                    current = ui.profile?.weeklyChangeKg ?: 0.5,
                    goal = ui.profile?.goal ?: WeightGoal.MAINTAIN,
                    useMetric = ui.weightMetric,
                    onSave = { kg -> vm.updateProfile { it.copy(weeklyChangeKg = kg) }; onDismiss() }
                )
                SettingsSheet.BIRTHDAY -> BirthdaySheet(
                    current = ui.profile?.birthday ?: Instant.now(),
                    onSave = { newInstant ->
                        vm.updateProfile { it.copy(birthday = newInstant) }
                        onDismiss()
                    }
                )
                SettingsSheet.APPEARANCE -> ListSheet(
                    title = stringResource(R.string.sheet_appearance),
                    items = listOf(
                        "system" to stringResource(R.string.settings_appearance_system),
                        "light" to stringResource(R.string.settings_appearance_light),
                        "dark" to stringResource(R.string.settings_appearance_dark)
                    ),
                    label = { it.second },
                    selected = { it.first == ui.appearanceMode },
                    onSelect = { vm.setAppearanceMode(it.first); onDismiss() },
                    icon = { appearanceIcon(it.first) }
                )
                SettingsSheet.WEEK_START -> ListSheet(
                    title = stringResource(R.string.sheet_week_starts),
                    items = listOf(
                        false to stringResource(R.string.settings_week_sunday),
                        true to stringResource(R.string.settings_week_monday)
                    ),
                    label = { it.second },
                    selected = { it.first == ui.weekStartsOnMonday },
                    onSelect = { vm.setWeekStartsOnMonday(it.first); onDismiss() }
                )
                SettingsSheet.MEAL_TIMES -> MealTimesSheet(
                    current = ui.mealSchedule,
                    onSave = {
                        vm.setMealSchedule(it)
                        onDismiss()
                    }
                )
                SettingsSheet.WATER_GOAL -> WaterGoalSheet(
                    current = ui.waterDailyGoalMl,
                    unit = ui.waterUnit,
                    onSave = {
                        vm.setWaterDailyGoalMl(it)
                        onDismiss()
                    }
                )
                SettingsSheet.WATER_UNIT -> ListSheet(
                    title = stringResource(R.string.settings_water_unit),
                    items = WaterUnit.entries,
                    label = {
                        if (it == WaterUnit.MILLILITERS) {
                            stringResource(R.string.settings_water_unit_ml)
                        } else {
                            stringResource(R.string.settings_water_unit_fl_oz)
                        }
                    },
                    selected = { it == ui.waterUnit },
                    onSelect = { vm.setWaterUnit(it); onDismiss() }
                )
                SettingsSheet.CALORIES -> NutritionPickerSheet(
                    label = stringResource(R.string.macro_calories), unit = stringResource(R.string.unit_kcal),
                    currentValue = ui.profile?.effectiveCalories ?: 2000,
                    range = 800..6000, step = 50,
                    onSave = { v ->
                        vm.editCaloriesGoal(v)
                        onDismiss()
                    },
                    onResetToAuto = if (ui.profile?.caloriesLocked == true) {
                        { vm.resetCaloriesLock(); onDismiss() }
                    } else null
                )
                SettingsSheet.PROTEIN -> NutritionPickerSheet(
                    label = stringResource(R.string.macro_protein), unit = stringResource(R.string.unit_g),
                    currentValue = ui.profile?.effectiveProtein ?: 0,
                    range = 10..500, step = 5,
                    onSave = { v ->
                        vm.editMacroGoal(AutoBalanceMacro.PROTEIN, v) { onRebalanceBlocked() }
                        onDismiss()
                    },
                    onResetToAuto = if (ui.profile?.isMacroLocked(AutoBalanceMacro.PROTEIN) == true) {
                        { vm.resetMacroLock(AutoBalanceMacro.PROTEIN); onDismiss() }
                    } else null
                )
                SettingsSheet.CARBS -> NutritionPickerSheet(
                    label = stringResource(R.string.macro_carbs), unit = stringResource(R.string.unit_g),
                    currentValue = ui.profile?.effectiveCarbs ?: 0,
                    range = 0..800, step = 5,
                    onSave = { v ->
                        vm.editMacroGoal(AutoBalanceMacro.CARBS, v) { onRebalanceBlocked() }
                        onDismiss()
                    },
                    onResetToAuto = if (ui.profile?.isMacroLocked(AutoBalanceMacro.CARBS) == true) {
                        { vm.resetMacroLock(AutoBalanceMacro.CARBS); onDismiss() }
                    } else null
                )
                SettingsSheet.FAT -> NutritionPickerSheet(
                    label = stringResource(R.string.macro_fat), unit = stringResource(R.string.unit_g),
                    currentValue = ui.profile?.effectiveFat ?: 0,
                    range = 10..300, step = 5,
                    onSave = { v ->
                        vm.editMacroGoal(AutoBalanceMacro.FAT, v) { onRebalanceBlocked() }
                        onDismiss()
                    },
                    onResetToAuto = if (ui.profile?.isMacroLocked(AutoBalanceMacro.FAT) == true) {
                        { vm.resetMacroLock(AutoBalanceMacro.FAT); onDismiss() }
                    } else null
                )
                SettingsSheet.OPTIONAL_NUTRIENTS -> OptionalNutrientGoalsSheet(
                    goals = ui.optionalNutrientGoals,
                    onChange = vm::setOptionalNutrientGoals,
                    onDismiss = onDismiss
                )
            }
            Spacer(Modifier.height(14.dp))
        }
    }
}

@Composable
private fun OptionalNutrientGoalsSheet(
    goals: OptionalNutrientGoals,
    onChange: (OptionalNutrientGoals) -> Unit,
    onDismiss: () -> Unit
) {
    var editing by remember { mutableStateOf<OptionalNutrient?>(null) }
    val nutrient = editing

    if (nutrient != null) {
        TextButton(onClick = { editing = null }) {
            Text(stringResource(R.string.settings_other_nutrients), color = AppColors.Calorie)
        }
        Spacer(Modifier.height(4.dp))
        NutritionPickerSheet(
            label = stringResource(nutrient.displayNameRes),
            unit = stringResource(nutrient.unitRes),
            currentValue = goals.valueFor(nutrient),
            range = nutrient.pickerRange(),
            step = nutrient.pickerStep(),
            onSave = { value ->
                onChange(goals.withValue(nutrient, value))
                editing = null
            }
        )
        return
    }

    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(stringResource(R.string.settings_other_nutrient_goals), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Spacer(Modifier.weight(1f))
        TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_done), color = AppColors.Calorie) }
    }
    Text(
        "Separate from calorie, protein, carbs, and fat targets.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
    )
    Spacer(Modifier.height(12.dp))
    LazyColumn(
        Modifier.fillMaxWidth().heightIn(max = 420.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(OptionalNutrient.values().toList()) { item ->
            OptionalNutrientGoalRow(
                nutrient = item,
                value = goals.valueFor(item),
                onClick = { editing = item }
            )
        }
    }
    TextButton(
        onClick = { onChange(OptionalNutrientGoals.Default) },
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(stringResource(R.string.settings_reset_defaults), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
    }
}

@Composable
private fun OptionalNutrientGoalRow(
    nutrient: OptionalNutrient,
    value: Int,
    onClick: () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        FudIconBubble(
            Icons.Outlined.DataUsage,
            size = 22.dp,
            iconSize = 15.dp
        )
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(
                stringResource(nutrient.displayNameRes),
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                stringResource(nutrient.unitRes),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.48f)
            )
        }
        Text(
            "$value${nutrient.unit}",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Spacer(Modifier.width(8.dp))
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun ThemeColorSwatch(themeColor: AppThemeColor, modifier: Modifier = Modifier) {
    Box(
        modifier
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(themeColor.start, themeColor.end)))
    )
}

@Composable
private fun <T> ListSheet(
    title: String,
    items: List<T>,
    label: @Composable (T) -> String,
    selected: (T) -> Boolean,
    onSelect: (T) -> Unit,
    icon: ((T) -> ImageVector?)? = null,
    subtitle: (@Composable (T) -> String?)? = null,
    footer: String? = null,
    customField: ((String) -> Unit)? = null
) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    LazyColumn(Modifier.fillMaxWidth().heightIn(max = 420.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items(items) { item ->
            val isSel = selected(item)
            val rowIcon = icon?.invoke(item)
            val sub = subtitle?.invoke(item)
            val shape = RoundedCornerShape(16.dp)
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(shape)
                    .background(
                        if (isSel) AppColors.Calorie.copy(alpha = 0.13f)
                        else if (isDark) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.38f)
                        else Color(0xFFEDE3DD).copy(alpha = 0.76f)
                    )
                    .background(
                        Brush.verticalGradient(
                            listOf(
                                Color.White.copy(alpha = if (isDark) 0.08f else 0.18f),
                                Color.White.copy(alpha = if (isDark) 0.02f else 0.04f),
                                AppColors.Calorie.copy(alpha = if (isSel) 0.065f else if (isDark) 0.025f else 0.050f)
                            )
                        )
                    )
                    .border(
                        0.7.dp,
                        Brush.linearGradient(
                            listOf(
                                Color.White.copy(alpha = if (isDark) 0.16f else 0.46f),
                                AppColors.Calorie.copy(alpha = if (isSel) 0.22f else if (isDark) 0.08f else 0.16f)
                            )
                        ),
                        shape
                    )
                    .clickable { onSelect(item) }
                    .padding(horizontal = 14.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (rowIcon != null) {
                    FudIconBubble(rowIcon, size = 22.dp, iconSize = 14.dp)
                    Spacer(Modifier.width(14.dp))
                }
                Column(Modifier.weight(1f)) {
                    Text(
                        label(item),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                    if (!sub.isNullOrBlank()) {
                        Spacer(Modifier.height(2.dp))
                        Text(
                            sub,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                }
                if (isSel) {
                    Icon(
                        Icons.Filled.Check,
                        contentDescription = stringResource(R.string.sheet_selected_a11y),
                        tint = AppColors.Calorie,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
    if (customField != null) {
        footer?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
        }
        var custom by remember { mutableStateOf("") }
        Spacer(Modifier.height(8.dp))
        FudGlassTextField(
            value = custom,
            onValueChange = { custom = it },
            placeholder = stringResource(R.string.sheet_any_model_id),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))
        FudGlassPrimaryButton(
            text = stringResource(R.string.action_save),
            onClick = { if (custom.isNotBlank()) customField(custom.trim()) },
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun ApiKeySheet(title: String, placeholder: String, onSave: (String) -> Unit) {
    var value by remember { mutableStateOf("") }
    Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    FudGlassTextField(
        value = value,
        onValueChange = { value = it },
        placeholder = placeholder,
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
        singleLine = true,
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(12.dp))
    FudGlassPrimaryButton(
        text = stringResource(R.string.action_save),
        onClick = { onSave(value) },
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(4.dp))
    TextButton(onClick = { onSave("") }, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.settings_clear_key)) }
}

@Composable
private fun TextFieldSheet(
    title: String,
    initial: String,
    placeholder: String,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    onSave: (String) -> Unit
) {
    var value by remember { mutableStateOf(initial) }
    Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    FudGlassTextField(
        value = value,
        onValueChange = { value = it },
        placeholder = placeholder,
        singleLine = true,
        keyboardOptions = keyboardOptions,
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(12.dp))
    FudGlassPrimaryButton(
        text = stringResource(R.string.action_save),
        onClick = { onSave(value.trim()) },
        modifier = Modifier.fillMaxWidth()
    )
}

@Composable
private fun HeightSheet(current: Int, useMetric: Boolean, onUnitChange: (Boolean) -> Unit, onSave: (Int) -> Unit) {
    var cm by remember(current) { mutableStateOf(current) }
    var metric by remember { mutableStateOf(useMetric) }
    Text(stringResource(R.string.sheet_height), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    UnitToggle(stringResource(R.string.unit_cm), stringResource(R.string.unit_ft_in), metric, { metric = it; onUnitChange(it) }, Modifier.fillMaxWidth())
    Spacer(Modifier.height(20.dp))
    if (metric) NumericWheelPicker(cm, { cm = it }, 100, 250, stringResource(R.string.unit_cm))
    else FeetInchesWheelPicker(cm, { cm = it })
    Spacer(Modifier.height(16.dp))
    GradientSaveButton { onSave(cm) }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun WeightSheet(titleText: String, current: Double, useMetric: Boolean, onUnitChange: (Boolean) -> Unit, onSave: (Double) -> Unit) {
    var kg by remember(current) { mutableStateOf(current) }
    var metric by remember { mutableStateOf(useMetric) }
    Text(titleText, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    UnitToggle(stringResource(R.string.unit_kg), stringResource(R.string.unit_lbs), metric, { metric = it; onUnitChange(it) }, Modifier.fillMaxWidth())
    Spacer(Modifier.height(20.dp))
    if (metric) {
        SplitDecimalWheelPicker(kg, { kg = it }, 30, 250, stringResource(R.string.unit_kg))
    } else {
        SplitDecimalWheelPicker(kg * 2.20462, { lbs -> kg = lbs / 2.20462 }, 66, 551, stringResource(R.string.unit_lbs))
    }
    Spacer(Modifier.height(16.dp))
    GradientSaveButton { onSave(kg) }
    Spacer(Modifier.height(8.dp))
}

private enum class MealBoundary {
    BREAKFAST, LUNCH, DINNER, SNACK
}

@Composable
private fun MealTimesSheet(current: MealSchedule, onSave: (MealSchedule) -> Unit) {
    var schedule by remember(current) { mutableStateOf(current.validatedOrDefault()) }
    var editing by remember { mutableStateOf<MealBoundary?>(null) }
    val context = LocalContext.current
    val formatter = remember(context) { DateTimeFormatter.ofPattern(clockTimePattern(context)) }
    fun formattedTime(minutes: Int): String =
        LocalTime.of(minutes / 60, minutes % 60).format(formatter)

    val selectedBoundary = editing
    if (selectedBoundary == null) {
        Text(
            stringResource(R.string.settings_meal_times),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(6.dp))
        Text(
            stringResource(R.string.settings_meal_times_description),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f)
        )
        Spacer(Modifier.height(16.dp))
        FudGlassSurface(
            modifier = Modifier.fillMaxWidth(),
            cornerRadius = 18.dp,
            padding = 0.dp
        ) {
            Column {
                MealBoundary.values().forEachIndexed { index, boundary ->
                    SettingRow(
                        label = stringResource(boundary.labelRes()),
                        value = formattedTime(boundary.valueIn(schedule))
                    ) { editing = boundary }
                    if (index != MealBoundary.values().lastIndex) HorizontalDivider()
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(
            stringResource(R.string.settings_meal_times_help),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
        )
        Spacer(Modifier.height(16.dp))
        GradientSaveButton { onSave(schedule) }
        FudGlassTextButton(
            text = stringResource(R.string.settings_restore_default_times),
            onClick = { schedule = MealSchedule.Default },
            modifier = Modifier.fillMaxWidth(),
            color = AppColors.Calorie
        )
        Spacer(Modifier.height(8.dp))
    } else {
        val allowed = selectedBoundary.allowedRange(schedule)
        var selectedMinutes by remember(selectedBoundary, schedule) {
            mutableIntStateOf(selectedBoundary.valueIn(schedule))
        }
        val options = remember(allowed, selectedMinutes) {
            ((allowed.first..allowed.last step 15).toList() + selectedMinutes)
                .filter { it in allowed }
                .distinct()
                .sorted()
        }
        val label = stringResource(selectedBoundary.labelRes())
        Text(
            stringResource(R.string.settings_meal_time_edit_format, label),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        Spacer(Modifier.height(16.dp))
        WheelPicker(
            items = options,
            selected = selectedMinutes,
            onSelect = { selectedMinutes = it },
            label = { formattedTime(it) }
        )
        Spacer(Modifier.height(16.dp))
        GradientSaveButton {
            schedule = selectedBoundary.updatedSchedule(schedule, selectedMinutes)
            editing = null
        }
        FudGlassTextButton(
            text = stringResource(R.string.action_cancel),
            onClick = { editing = null },
            modifier = Modifier.fillMaxWidth(),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f)
        )
        Spacer(Modifier.height(8.dp))
    }
}

private fun MealBoundary.labelRes(): Int = when (this) {
    MealBoundary.BREAKFAST -> R.string.settings_breakfast_starts
    MealBoundary.LUNCH -> R.string.settings_lunch_starts
    MealBoundary.DINNER -> R.string.settings_dinner_starts
    MealBoundary.SNACK -> R.string.settings_late_snack_starts
}

private fun MealBoundary.valueIn(schedule: MealSchedule): Int = when (this) {
    MealBoundary.BREAKFAST -> schedule.breakfastStartMinutes
    MealBoundary.LUNCH -> schedule.lunchStartMinutes
    MealBoundary.DINNER -> schedule.dinnerStartMinutes
    MealBoundary.SNACK -> schedule.snackStartMinutes
}

private fun MealBoundary.allowedRange(schedule: MealSchedule): IntRange = when (this) {
    MealBoundary.BREAKFAST -> 0..(schedule.lunchStartMinutes - 15)
    MealBoundary.LUNCH -> (schedule.breakfastStartMinutes + 15)..(schedule.dinnerStartMinutes - 15)
    MealBoundary.DINNER -> (schedule.lunchStartMinutes + 15)..(schedule.snackStartMinutes - 15)
    MealBoundary.SNACK -> (schedule.dinnerStartMinutes + 15)..1439
}

private fun MealBoundary.updatedSchedule(schedule: MealSchedule, minutes: Int): MealSchedule = when (this) {
    MealBoundary.BREAKFAST -> schedule.copy(breakfastStartMinutes = minutes)
    MealBoundary.LUNCH -> schedule.copy(lunchStartMinutes = minutes)
    MealBoundary.DINNER -> schedule.copy(dinnerStartMinutes = minutes)
    MealBoundary.SNACK -> schedule.copy(snackStartMinutes = minutes)
}

@Composable
private fun WaterGoalSheet(current: Int, unit: WaterUnit, onSave: (Int) -> Unit) {
    val initialGoal = if (unit == WaterUnit.MILLILITERS) {
        (((current.coerceIn(50, 10_000) + 25) / 50) * 50).coerceIn(50, 10_000)
    } else {
        (current / WaterUnit.MILLILITERS_PER_FLUID_OUNCE).roundToInt().coerceIn(2, 338)
    }
    var goal by remember(current) { mutableIntStateOf(initialGoal) }
    Text(stringResource(R.string.settings_water_goal), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(20.dp))
    NumericWheelPicker(
        value = goal,
        onValueChange = { goal = it },
        min = if (unit == WaterUnit.MILLILITERS) 50 else 2,
        max = if (unit == WaterUnit.MILLILITERS) 10_000 else 338,
        unit = unit.symbol,
        step = if (unit == WaterUnit.MILLILITERS) 50 else 1
    )
    Spacer(Modifier.height(8.dp))
    Text(
        if (unit == WaterUnit.MILLILITERS) stringResource(R.string.settings_water_goal_wheel_help)
        else stringResource(R.string.settings_water_goal_wheel_help_fl_oz),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
    )
    Spacer(Modifier.height(16.dp))
    GradientSaveButton { onSave(unit.toMilliliters(goal.toDouble())) }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun BodyFatSheet(current: Double?, onSave: (Double?) -> Unit) {
    var pct by remember(current) { mutableStateOf((current ?: 0.20) * 100) }
    Text(stringResource(R.string.sheet_body_fat_percent), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    DecimalWheelPicker(pct, { pct = it }, 5.0, 60.0, 0.5, stringResource(R.string.unit_percent))
    Spacer(Modifier.height(12.dp))
    GradientSaveButton { onSave(pct / 100.0) }
    Spacer(Modifier.height(4.dp))
    TextButton(onClick = { onSave(null) }, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.action_clear)) }
    Spacer(Modifier.height(8.dp))
}

/** Same wheel UX as BodyFatSheet, but framed as a goal — separate, optional,
 *  display-only. Seeds from the existing goal, falling back to the user's
 *  current body fat % so the wheel lands somewhere sensible on first open. */
@Composable
private fun GoalBodyFatSheet(currentGoal: Double?, currentBodyFat: Double?, onSave: (Double?) -> Unit) {
    val seed = currentGoal ?: currentBodyFat ?: 0.15
    var pct by remember(currentGoal) { mutableStateOf(seed * 100) }
    Text(stringResource(R.string.sheet_goal_body_fat), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    if (currentBodyFat != null) {
        Spacer(Modifier.height(4.dp))
        Text(
            stringResource(R.string.sheet_goal_body_fat_currently, (currentBodyFat * 100).toInt()),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
        )
    }
    Spacer(Modifier.height(12.dp))
    DecimalWheelPicker(pct, { pct = it }, 3.0, 60.0, 0.5, stringResource(R.string.unit_percent))
    Spacer(Modifier.height(12.dp))
    GradientSaveButton { onSave(pct / 100.0) }
    Spacer(Modifier.height(4.dp))
    TextButton(onClick = { onSave(null) }, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.action_remove_goal)) }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun GoalSpeedSheet(current: Double, goal: WeightGoal, useMetric: Boolean, onSave: (Double) -> Unit) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    Text(stringResource(R.string.sheet_weekly_change), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    val wUnit = if (useMetric) stringResource(R.string.unit_kg) else stringResource(R.string.unit_lbs)
    val paceRes = if (goal == WeightGoal.LOSE) R.string.settings_pace_loss_format else R.string.settings_pace_gain_format
    val options = listOf(
        Triple(0.25, stringResource(R.string.onboarding_pace_slow), stringResource(paceRes, "${WeightDisplayFormatter.weeklyChangeValue(0.25, useMetric)} $wUnit")),
        Triple(0.5, stringResource(R.string.onboarding_pace_recommended), stringResource(paceRes, "${WeightDisplayFormatter.weeklyChangeValue(0.5, useMetric)} $wUnit")),
        Triple(1.0, stringResource(R.string.onboarding_pace_fast), stringResource(paceRes, "${WeightDisplayFormatter.weeklyChangeValue(1.0, useMetric)} $wUnit"))
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for ((kg, title, subtitle) in options) {
            val isSel = kotlin.math.abs(kg - current) < 0.01
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        if (isSel) AppColors.Calorie.copy(alpha = 0.13f)
                        else if (isDark) MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
                        else Color(0xFFEDE3DD).copy(alpha = 0.78f)
                    )
                    .clickable { onSave(kg) }
                    .padding(horizontal = 14.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
                    Spacer(Modifier.height(2.dp))
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
                if (isSel) {
                    Icon(
                        Icons.Filled.Check,
                        contentDescription = stringResource(R.string.cd_selected),
                        tint = AppColors.Calorie,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
    Spacer(Modifier.height(8.dp))
}

/**
 * Wheel-picker sheet for a single macro / calorie target. Mirrors iOS
 * NutritionPickerSheet exactly: title, wheel picker stepped at the requested
 * step, gradient Save button, optional "Reset to Auto-balance" link when the
 * macro is currently pinned.
 */
@Composable
fun NutritionPickerSheet(
    label: String,
    unit: String,
    currentValue: Int,
    range: IntRange,
    step: Int,
    onSave: (Int) -> Unit,
    onResetToAuto: (() -> Unit)? = null,
    resetLabel: String? = null,
    // Live wheel-selection reporter, for hosts that need the current value
    // before Save (e.g. to convert it when a unit switcher flips).
    onValueChange: ((Int) -> Unit)? = null
) {
    val items = remember(range, step) { (range.first..range.last step step).toList() }
    val snapped = (currentValue / step) * step
    val initial = snapped.coerceIn(range.first, range.last).let { v ->
        items.minByOrNull { kotlin.math.abs(it - v) } ?: items.first()
    }
    var selected by remember(initial) { mutableStateOf(initial) }
    Text(label, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(12.dp))
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        com.apoorvdarshan.calorietracker.ui.components.WheelPicker(
            items = items,
            selected = selected,
            onSelect = { selected = it; onValueChange?.invoke(it) },
            modifier = Modifier.width(120.dp)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            unit,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
    }
    Spacer(Modifier.height(16.dp))
    Box(
        Modifier
            .fillMaxWidth()
            .height(54.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(AppColors.CalorieGradient)
            .clickable { onSave(selected) },
        contentAlignment = Alignment.Center
    ) {
        Text(
            stringResource(R.string.action_save),
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.titleMedium
        )
    }
    if (onResetToAuto != null) {
        Spacer(Modifier.height(4.dp))
        TextButton(
            onClick = onResetToAuto,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                resetLabel ?: stringResource(R.string.settings_reset_autobalance),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun MacrosSheet(
    profile: com.apoorvdarshan.calorietracker.models.UserProfile?,
    onSaveCalories: (Int?) -> Unit,
    onSaveMacro: (AutoBalanceMacro, Int?) -> Unit,
    onClearPin: (AutoBalanceMacro) -> Unit
) {
    profile ?: return
    var caloriesText by remember(profile) { mutableStateOf(profile.effectiveCalories.toString()) }
    var proteinText by remember(profile) { mutableStateOf(profile.effectiveProtein.toString()) }
    var carbsText by remember(profile) { mutableStateOf(profile.effectiveCarbs.toString()) }
    var fatText by remember(profile) { mutableStateOf(profile.effectiveFat.toString()) }
    Text(stringResource(R.string.sheet_macros), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Text(
        stringResource(R.string.settings_macro_pin_hint),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
    )
    Spacer(Modifier.height(12.dp))
    MacroField(stringResource(R.string.macro_calories), caloriesText, { caloriesText = it }, stringResource(R.string.unit_kcal)) {
        caloriesText.toIntOrNull()?.let { onSaveCalories(it) }
    }
    Spacer(Modifier.height(6.dp))
    MacroField(
        label = if (profile.isPinned(AutoBalanceMacro.PROTEIN)) stringResource(R.string.settings_macro_pinned_label_format, stringResource(R.string.autobalance_protein)) else stringResource(R.string.settings_macro_auto_label_format, stringResource(R.string.autobalance_protein)),
        value = proteinText,
        onChange = { proteinText = it },
        unit = stringResource(R.string.unit_g),
        pinned = profile.isPinned(AutoBalanceMacro.PROTEIN),
        onClearPin = { onClearPin(AutoBalanceMacro.PROTEIN) }
    ) { proteinText.toIntOrNull()?.let { onSaveMacro(AutoBalanceMacro.PROTEIN, it) } }
    Spacer(Modifier.height(6.dp))
    MacroField(
        label = if (profile.isPinned(AutoBalanceMacro.CARBS)) stringResource(R.string.settings_macro_pinned_label_format, stringResource(R.string.autobalance_carbs)) else stringResource(R.string.settings_macro_auto_label_format, stringResource(R.string.autobalance_carbs)),
        value = carbsText,
        onChange = { carbsText = it },
        unit = stringResource(R.string.unit_g),
        pinned = profile.isPinned(AutoBalanceMacro.CARBS),
        onClearPin = { onClearPin(AutoBalanceMacro.CARBS) }
    ) { carbsText.toIntOrNull()?.let { onSaveMacro(AutoBalanceMacro.CARBS, it) } }
    Spacer(Modifier.height(6.dp))
    MacroField(
        label = if (profile.isPinned(AutoBalanceMacro.FAT)) stringResource(R.string.settings_macro_pinned_label_format, stringResource(R.string.autobalance_fat)) else stringResource(R.string.settings_macro_auto_label_format, stringResource(R.string.autobalance_fat)),
        value = fatText,
        onChange = { fatText = it },
        unit = stringResource(R.string.unit_g),
        pinned = profile.isPinned(AutoBalanceMacro.FAT),
        onClearPin = { onClearPin(AutoBalanceMacro.FAT) }
    ) { fatText.toIntOrNull()?.let { onSaveMacro(AutoBalanceMacro.FAT, it) } }
}

@Composable
private fun MacroField(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    unit: String,
    pinned: Boolean = false,
    onClearPin: (() -> Unit)? = null,
    onPin: () -> Unit
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        FudGlassTextField(
            value = value,
            onValueChange = onChange,
            placeholder = "$label ($unit)",
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.weight(1f)
        )
        Spacer(Modifier.height(6.dp))
        TextButton(onClick = { if (pinned) onClearPin?.invoke() else onPin() }) {
            Text(if (pinned) stringResource(R.string.action_clear) else stringResource(R.string.action_pin), color = AppColors.Calorie)
        }
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable () -> Unit) {
    // iOS uses sentence-case section titles ("Personal Info", "Goals & Nutrition")
    // in a small grey caption. Match that — no uppercase transform.
    Column {
        Text(
            title,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.55f),
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )
        FudGlassSurface(
            modifier = Modifier.fillMaxWidth(),
            cornerRadius = 18.dp,
            padding = 0.dp
        ) {
            Column(Modifier.padding(vertical = 4.dp)) { content() }
        }
    }
}

@Composable
private fun SettingRow(
    label: String,
    value: String,
    icon: ImageVector? = null,
    // iOS `.menu` Picker rows render a `chevron.up.chevron.down` instead of a
    // right-chevron to signal the inline dropdown affordance. Pass inlineMenu=true
    // for Gender, Weight Goal, and Activity Level.
    inlineMenu: Boolean = false,
    onClick: () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            FudIconBubble(icon = icon, size = 22.dp, iconSize = 14.dp)
            Spacer(Modifier.width(14.dp))
        }
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
        )
        Icon(
            if (inlineMenu) Icons.Filled.UnfoldMore else Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
            modifier = if (inlineMenu) Modifier.size(18.dp) else Modifier
        )
    }
}

@Composable
private fun ActivityLevelSettingRow(
    level: ActivityLevel,
    onClick: () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        FudIconBubble(icon = Icons.AutoMirrored.Outlined.DirectionsRun, size = 22.dp, iconSize = 14.dp)
        Spacer(Modifier.width(14.dp))
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(end = 12.dp)
        ) {
            Text(
                stringResource(R.string.settings_activity_level),
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Text(
            stringResource(level.displayNameRes),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Icon(
            Icons.Filled.UnfoldMore,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
            modifier = Modifier.size(18.dp)
        )
    }
}

/**
 * A goal row (calories or a macro). Tapping the row opens the value picker. The lock glyph is a
 * READ-ONLY indicator (Filled.Lock pink when locked, Outlined.LockOpen gray when not) — saving a
 * value locks it; the picker's "Reset to Auto-balance" releases it. Dimmed while Adaptive is on.
 */
@Composable
private fun LockableGoalRow(
    label: String,
    value: String,
    icon: ImageVector,
    locked: Boolean,
    lockEnabled: Boolean,
    onClick: () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        FudIconBubble(icon = icon, size = 22.dp, iconSize = 14.dp)
        Spacer(Modifier.width(14.dp))
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Spacer(Modifier.width(10.dp))
        Icon(
            if (locked) Icons.Filled.Lock else Icons.Outlined.LockOpen,
            contentDescription = stringResource(
                if (locked) R.string.settings_macro_locked else R.string.settings_macro_unlocked
            ),
            tint = when {
                !lockEnabled -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.25f)
                locked -> AppColors.Calorie
                else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f)
            },
            modifier = Modifier.size(18.dp)
        )
    }
}

/**
 * Multi-line text editor with a Save row at the bottom that pulses brand pink
 * when the current text differs from the persisted value, mirrors iOS Custom
 * AI Instructions section.
 */
@Composable
private fun CustomInstructionsBlock(
    initial: String,
    placeholder: String,
    onSave: (String) -> Unit
) {
    var text by remember(initial) { mutableStateOf(initial) }
    var saved by remember(initial) { mutableStateOf(initial) }
    val hasChanges = text != saved
    Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp)) {
        FudGlassTextField(
            value = text,
            onValueChange = { text = it },
            placeholder = placeholder,
            modifier = Modifier.fillMaxWidth().heightIn(min = 110.dp),
            singleLine = false,
            minLines = 4,
            maxLines = 6
        )
        Spacer(Modifier.height(8.dp))
        TextButton(
            onClick = {
                onSave(text)
                saved = text.trim()
                text = saved
            },
            enabled = hasChanges,
            modifier = Modifier.fillMaxWidth()
        ) {
            Icon(
                Icons.Filled.Check,
                contentDescription = null,
                tint = if (hasChanges) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                stringResource(R.string.settings_save),
                color = if (hasChanges) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun ToggleRow(
    label: String,
    checked: Boolean,
    icon: ImageVector? = null,
    onChange: (Boolean) -> Unit
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            FudIconBubble(icon = icon, size = 22.dp, iconSize = 14.dp)
            Spacer(Modifier.width(14.dp))
        }
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun ToggleRowWithInfo(
    label: String,
    checked: Boolean,
    icon: ImageVector? = null,
    onInfo: () -> Unit,
    onChange: (Boolean) -> Unit,
    enabled: Boolean = true
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            FudIconBubble(icon = icon, size = 22.dp, iconSize = 14.dp)
            Spacer(Modifier.width(14.dp))
        }
        Text(
            label,
            modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        IconButton(onClick = onInfo, modifier = Modifier.size(36.dp)) {
            Icon(
                Icons.Outlined.Info,
                contentDescription = stringResource(R.string.action_info),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
                modifier = Modifier.size(18.dp)
            )
        }
        Switch(checked = checked, onCheckedChange = onChange, enabled = enabled)
    }
}

@Composable
private fun EnergyBurnGoalsRow(
    checked: Boolean,
    applying: Boolean,
    needsHealthConnect: Boolean,
    onInfo: () -> Unit,
    onChange: (Boolean) -> Unit
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        FudIconBubble(icon = Icons.Outlined.LocalFireDepartment, size = 22.dp, iconSize = 14.dp)
        Spacer(Modifier.width(14.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                stringResource(R.string.settings_energy_goals),
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            if (needsHealthConnect) {
                Text(
                    stringResource(R.string.settings_needs_health_connect),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                )
            }
        }
        if (applying) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                strokeWidth = 2.dp,
                color = AppColors.Calorie
            )
            Spacer(Modifier.width(14.dp))
        }
        IconButton(onClick = onInfo, modifier = Modifier.size(36.dp)) {
            Icon(
                Icons.Outlined.Info,
                contentDescription = stringResource(R.string.action_info),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
                modifier = Modifier.size(18.dp)
            )
        }
        Switch(checked = checked, onCheckedChange = onChange, enabled = !applying)
    }
}

@Composable
private fun AdaptiveGoalsRow(
    checked: Boolean,
    applying: Boolean,
    onInfo: () -> Unit,
    onChange: (Boolean) -> Unit
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        FudIconBubble(icon = Icons.Outlined.TrackChanges, size = 22.dp, iconSize = 14.dp)
        Spacer(Modifier.width(14.dp))
        Text(
            stringResource(R.string.settings_adaptive_goals),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f)
        )
        if (applying) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                strokeWidth = 2.dp,
                color = AppColors.Calorie
            )
            Spacer(Modifier.width(14.dp))
        }
        IconButton(onClick = onInfo, modifier = Modifier.size(36.dp)) {
            Icon(
                Icons.Outlined.Info,
                contentDescription = stringResource(R.string.action_info),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
                modifier = Modifier.size(18.dp)
            )
        }
        Switch(checked = checked, onCheckedChange = onChange, enabled = !applying)
    }
}

private fun feetInchesLabel(cm: Int): String {
    // Round to the nearest inch — truncating shows 5'6" for a 170 cm / 5'7" pick.
    val totalInches = Math.round(cm / 2.54).toInt()
    val feet = totalInches / 12
    val inches = totalInches % 12
    return "$feet' $inches\""
}

private fun optionalNutrientSummary(goals: OptionalNutrientGoals): String =
    "Fiber ${goals.fiber}g, Sodium ${goals.sodium}mg"

private fun OptionalNutrient.pickerRange(): IntRange = when (this) {
    OptionalNutrient.SUGAR -> 0..200
    OptionalNutrient.ADDED_SUGAR -> 0..100
    OptionalNutrient.FIBER -> 0..100
    OptionalNutrient.SATURATED_FAT -> 0..80
    OptionalNutrient.CHOLESTEROL -> 0..1000
    OptionalNutrient.SODIUM -> 0..5000
    OptionalNutrient.POTASSIUM -> 0..7000
    OptionalNutrient.TRANS_FAT -> 0..10
    OptionalNutrient.CALCIUM -> 300..2000
    OptionalNutrient.IRON -> 5..45
    OptionalNutrient.MAGNESIUM -> 100..800
    OptionalNutrient.ZINC -> 3..40
    OptionalNutrient.VITAMIN_A -> 300..3000
    OptionalNutrient.VITAMIN_C -> 20..500
    OptionalNutrient.VITAMIN_D -> 5..100
    OptionalNutrient.VITAMIN_B12 -> 1..20
    OptionalNutrient.VITAMIN_E -> 5..100
    OptionalNutrient.VITAMIN_K -> 30..300
    OptionalNutrient.FOLATE -> 100..1000
    OptionalNutrient.OMEGA3 -> 0..10
}

private fun OptionalNutrient.pickerStep(): Int = when (this) {
    OptionalNutrient.FIBER,
    OptionalNutrient.SATURATED_FAT,
    OptionalNutrient.TRANS_FAT,
    OptionalNutrient.IRON,
    OptionalNutrient.ZINC,
    OptionalNutrient.VITAMIN_D,
    OptionalNutrient.VITAMIN_B12,
    OptionalNutrient.VITAMIN_E,
    OptionalNutrient.OMEGA3 -> 1
    OptionalNutrient.CHOLESTEROL -> 25
    OptionalNutrient.SODIUM,
    OptionalNutrient.POTASSIUM,
    OptionalNutrient.CALCIUM,
    OptionalNutrient.VITAMIN_A,
    OptionalNutrient.FOLATE -> 50
    OptionalNutrient.MAGNESIUM -> 25
    OptionalNutrient.VITAMIN_C,
    OptionalNutrient.VITAMIN_K -> 10
    OptionalNutrient.SUGAR,
    OptionalNutrient.ADDED_SUGAR -> 5
}

private val birthdayFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("MMM d, yyyy", Locale.US)

private fun birthdayDisplay(profile: UserProfile): String {
    val date = profile.birthday.atZone(ZoneId.systemDefault()).toLocalDate()
    return "${date.format(birthdayFormatter)} (age ${profile.age})"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BirthdaySheet(current: Instant, onSave: (Instant) -> Unit) {
    // Material3 DatePicker stores selection as UTC-midnight millis. We store
    // birthdays as a local-zone Instant. Round-trip both sides through the
    // user's local date to avoid an off-by-one when the user is east of UTC.
    val localDate = current.atZone(ZoneId.systemDefault()).toLocalDate()
    var pickedDate by remember(current) { mutableStateOf(localDate) }
    Text(stringResource(R.string.sheet_birthday), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    Spacer(Modifier.height(8.dp))
    DateWheelPicker(
        selected = pickedDate,
        onSelect = { pickedDate = it },
        maxYear = LocalDate.now().year,
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(12.dp))
    GradientSaveButton {
        val newInstant = pickedDate.atStartOfDay(ZoneId.systemDefault()).toInstant()
        onSave(newInstant)
    }
    Spacer(Modifier.height(8.dp))
}

// Closest Material mappings for the iOS SF Symbols used in picker rows.
private fun genderIcon(g: Gender): ImageVector = when (g) {
    Gender.MALE -> Icons.Outlined.Male
    Gender.FEMALE -> Icons.Outlined.Female
    Gender.OTHER -> Icons.Outlined.Wc
}

private fun activityIcon(a: ActivityLevel): ImageVector = when (a) {
    ActivityLevel.SEDENTARY -> Icons.Outlined.SelfImprovement
    ActivityLevel.LIGHT -> Icons.AutoMirrored.Outlined.DirectionsWalk
    ActivityLevel.MODERATE -> Icons.AutoMirrored.Outlined.DirectionsRun
    ActivityLevel.ACTIVE -> Icons.Outlined.LocalDining
    ActivityLevel.VERY_ACTIVE -> Icons.Outlined.FitnessCenter
    ActivityLevel.EXTRA_ACTIVE -> Icons.Outlined.SportsMartialArts
}

private fun goalIcon(g: WeightGoal): ImageVector = when (g) {
    WeightGoal.LOSE -> Icons.AutoMirrored.Filled.TrendingDown
    WeightGoal.MAINTAIN -> Icons.AutoMirrored.Filled.TrendingFlat
    WeightGoal.GAIN -> Icons.AutoMirrored.Outlined.TrendingUp
}

private fun appearanceIcon(key: String): ImageVector = when (key) {
    "light" -> Icons.Outlined.LightMode
    "dark" -> Icons.Outlined.DarkMode
    else -> Icons.Outlined.SettingsBrightness
}

/**
 * Pink-gradient capsule "Save" button matching the iOS picker sheets
 * (`LinearGradient(colors: AppColors.calorieGradient)` over a 14dp rounded
 * rectangle, white semibold label).
 */
@Composable
private fun GradientSaveButton(
    text: String? = null,
    enabled: Boolean = true,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val brush = Brush.linearGradient(listOf(AppColors.CalorieStart, AppColors.CalorieEnd))
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(if (enabled) brush else Brush.linearGradient(listOf(AppColors.Calorie.copy(alpha = 0.4f), AppColors.Calorie.copy(alpha = 0.4f))))
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color.White.copy(alpha = 0.24f),
                        Color.White.copy(alpha = 0.04f)
                    )
                )
            )
            .border(0.7.dp, Color.White.copy(alpha = 0.22f), shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text ?: stringResource(R.string.action_save), color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
    }
}
