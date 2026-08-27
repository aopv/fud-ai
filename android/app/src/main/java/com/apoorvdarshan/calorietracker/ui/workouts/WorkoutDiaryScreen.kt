package com.apoorvdarshan.calorietracker.ui.workouts

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.DeleteOutline
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.data.ExerciseRepository
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.PlannedExercise
import com.apoorvdarshan.calorietracker.models.PlannedSet
import com.apoorvdarshan.calorietracker.models.WorkoutWeightUnit
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialog
import com.apoorvdarshan.calorietracker.ui.components.FudGlassSurface
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextButton
import com.apoorvdarshan.calorietracker.ui.components.KitchenReceiptRule
import com.apoorvdarshan.calorietracker.ui.home.SheetGlassDropdownMenu
import com.apoorvdarshan.calorietracker.ui.home.SheetGlassDropdownMenuItem
import com.apoorvdarshan.calorietracker.ui.navigation.BottomNavScrollPadding
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import coil.compose.AsyncImage
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.flow.collect

private const val WORKOUT_WEEKS = 53
private const val CURRENT_WORKOUT_WEEK = WORKOUT_WEEKS - 1

@Composable
internal fun WorkoutDiaryScreen(
    state: WorkoutDiaryUiState,
    exerciseRepository: ExerciseRepository,
    viewModel: WorkoutsViewModel,
    modifier: Modifier = Modifier,
    weekStartsOnMonday: Boolean = true,
    initialSheet: String? = null,
    onShowLibrary: () -> Unit
) {
    var pickerRequest by remember(initialSheet) {
        mutableStateOf(if (initialSheet == "add") WorkoutPickerRequest.all() else null)
    }
    var copySheetVisible by remember(initialSheet) { mutableStateOf(initialSheet == "copy") }
    var addMenuExpanded by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    val addWorkoutLabel = stringResource(R.string.workout_add_workout)
    val allExercisesLabel = stringResource(R.string.workout_menu_all_exercises)
    val copyFromDayLabel = stringResource(R.string.workout_menu_copy_from_day)
    val savedLabel = stringResource(R.string.workout_menu_saved)
    val exerciseCardBounds = remember { mutableStateMapOf<UUID, androidx.compose.ui.geometry.Rect>() }
    var diaryRootOrigin by remember { mutableStateOf(Offset.Zero) }
    val firstDayOfWeek = remember(weekStartsOnMonday) {
        if (weekStartsOnMonday) DayOfWeek.MONDAY else DayOfWeek.SUNDAY
    }
    var visibleWeekStart by remember(weekStartsOnMonday, state.selectedDate) {
        mutableStateOf(startOfWeek(state.selectedDate, firstDayOfWeek))
    }

    fun dismissKeyboard() {
        focusManager.clearFocus()
        keyboard?.hide()
    }

    LaunchedEffect(listState.isScrollInProgress) {
        if (listState.isScrollInProgress) dismissKeyboard()
    }

    LaunchedEffect(state.exercises.map { it.id }) {
        exerciseCardBounds.keys.retainAll(state.exercises.mapTo(mutableSetOf()) { it.id })
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Transparent)
            .onGloballyPositioned { diaryRootOrigin = it.boundsInRoot().topLeft }
            .pointerInput(diaryRootOrigin) {
                // Observe completed pointers without consuming them, so set
                // fields, buttons, scrolling, and day swipes keep their normal
                // input behavior.
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent(PointerEventPass.Final)
                        event.changes.firstOrNull { it.previousPressed && !it.pressed }?.let { change ->
                            // Match iOS: blank screen chrome dismisses input,
                            // while the whole exercise card preserves focus.
                            val rootPosition = change.position + diaryRootOrigin
                            if (exerciseCardBounds.values.none { it.contains(rootPosition) }) {
                                dismissKeyboard()
                            }
                        }
                    }
                }
            }
    ) {
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 12.dp,
                top = 3.dp,
                end = 12.dp,
                bottom = BottomNavScrollPadding + 10.dp
            ),
            verticalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            item(key = "workout-masthead") {
                WorkoutWeekHeader(
                    weekStart = visibleWeekStart,
                    weekStartsOnMonday = weekStartsOnMonday
                )
            }

            item(key = "workout-week-strip") {
                WorkoutWeekStrip(
                    selectedDate = state.selectedDate,
                    workoutCounts = state.workoutCounts,
                    onSelect = {
                        dismissKeyboard()
                        viewModel.selectDate(it)
                    },
                    onVisibleWeekChange = { visibleWeekStart = it },
                    onSettledWeekChange = { settledWeekStart ->
                        val selectedWeekStart = startOfWeek(state.selectedDate, firstDayOfWeek)
                        if (settledWeekStart != selectedWeekStart) {
                            val selectedDayOffset = ChronoUnit.DAYS
                                .between(selectedWeekStart, state.selectedDate)
                                .coerceIn(0, 6)
                            viewModel.selectDate(settledWeekStart.plusDays(selectedDayOffset))
                        }
                    },
                    weekStartsOnMonday = weekStartsOnMonday,
                    modifier = Modifier.padding(bottom = 1.dp)
                )
            }

            item(key = "workout-burn") {
                WorkoutUtilityStrip(
                    state = state,
                    onShowLibrary = onShowLibrary,
                    onCalculate = {
                        dismissKeyboard()
                        viewModel.calculateBurn()
                    },
                    modifier = Modifier.workoutDaySwipe(
                        selectedDate = state.selectedDate,
                        onMove = {
                            dismissKeyboard()
                            viewModel.moveDate(it)
                        }
                    )
                )
            }

            if (state.exercises.isEmpty()) {
                item(key = "workout-empty") {
                    WorkoutEmptyState(
                        splitTitle = state.preferences.split.title,
                        onAdd = { addMenuExpanded = true },
                        modifier = Modifier.workoutDaySwipe(
                            selectedDate = state.selectedDate,
                            onMove = { viewModel.moveDate(it) }
                        )
                    )
                }
            } else {
                items(state.exercises, key = { it.id }) { exercise ->
                    WorkoutExerciseCard(
                        exercise = exercise,
                        modifier = Modifier.onGloballyPositioned { coordinates ->
                            exerciseCardBounds[exercise.id] = coordinates.boundsInRoot()
                        },
                        weightUnit = state.weightUnit,
                        rpePlaceholder = state.preferences.rpeScale.inputPlaceholder,
                        isSaved = exercise.itemId in state.savedExerciseIds,
                        onOpen = { viewModel.openDiaryExercise(exercise) },
                        onToggleSaved = { viewModel.toggleSaved(exercise.itemId) },
                        onRemove = {
                            dismissKeyboard()
                            viewModel.removeExercise(exercise.id)
                        },
                        onSetCount = { viewModel.setSetCount(exercise.id, it) },
                        onWeight = { setId, value -> viewModel.updateWeight(exercise.id, setId, value) },
                        onReps = { setId, value -> viewModel.updateReps(exercise.id, setId, value) },
                        onRpe = { setId, value -> viewModel.updateRpe(exercise.id, setId, value) }
                    )
                }
            }

            item(key = "workout-add-action") {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(Color.Transparent)
                            .border(1.2.dp, AppColors.KitchenTomato, RoundedCornerShape(3.dp))
                            .clickable(role = Role.Button) {
                                dismissKeyboard()
                                addMenuExpanded = true
                            }
                            .semantics { contentDescription = addWorkoutLabel },
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(Icons.Filled.Add, contentDescription = null, tint = AppColors.KitchenTomato, modifier = Modifier.size(16.dp))
                            Text(
                                addWorkoutLabel.uppercase(Locale.getDefault()),
                                color = AppColors.KitchenTomato,
                                style = MaterialTheme.typography.labelLarge,
                                fontWeight = FontWeight.Black
                            )
                        }
                    }

                    SheetGlassDropdownMenu(
                        expanded = addMenuExpanded,
                        onDismissRequest = { addMenuExpanded = false },
                        modifier = Modifier.heightIn(max = 520.dp),
                        menuWidth = 236.dp
                    ) {
                        if (state.splitGroups.isEmpty()) {
                            SheetGlassDropdownMenuItem(
                                label = allExercisesLabel,
                                leadingContent = { WorkoutMenuGlyph(workoutMenuGlyphAsset(allExercisesLabel, emptySet())) },
                                onClick = {
                                    addMenuExpanded = false
                                    pickerRequest = WorkoutPickerRequest.all()
                                }
                            )
                        } else {
                            state.splitGroups.forEach { group ->
                                SheetGlassDropdownMenuItem(
                                    label = group.title,
                                    leadingContent = {
                                        WorkoutMenuGlyph(workoutMenuGlyphAsset(group.title, group.muscles))
                                    },
                                    onClick = {
                                        addMenuExpanded = false
                                        pickerRequest = WorkoutPickerRequest.group(group)
                                    }
                                )
                            }
                        }
                        HorizontalDivider(color = workoutsColors().hairline.copy(alpha = 0.45f))
                        SheetGlassDropdownMenuItem(
                            label = copyFromDayLabel,
                            leadingIcon = Icons.Filled.ContentCopy,
                            onClick = {
                                addMenuExpanded = false
                                copySheetVisible = true
                            }
                        )
                        SheetGlassDropdownMenuItem(
                            label = savedLabel,
                            leadingIcon = Icons.Filled.Bookmark,
                            onClick = {
                                addMenuExpanded = false
                                pickerRequest = WorkoutPickerRequest.saved()
                            }
                        )
                    }
                }
            }

            item(key = "workout-extra-space") { Spacer(Modifier.height(4.dp)) }
        }
    }

    pickerRequest?.let { request ->
        WorkoutPickerSheet(
            request = request,
            repository = exerciseRepository,
            selectedExerciseIds = state.exercises.mapTo(mutableSetOf()) { it.itemId },
            savedExerciseIds = state.savedExerciseIds,
            initialSource = if (request.isSavedContext) WorkoutPickerSource.SAVED else viewModel.pickerSource(),
            initialFilterState = viewModel.pickerFilter(request.contextId),
            preferredEquipment = state.preferences.equipment,
            hidePrimaryFilter = request.muscles.isNotEmpty() &&
                state.preferences.split in setOf(
                    com.apoorvdarshan.calorietracker.models.WorkoutSplit.FULL_BODY,
                    com.apoorvdarshan.calorietracker.models.WorkoutSplit.CUSTOM
                ),
            onSourceChange = viewModel::setPickerSource,
            onFilterStateChange = { viewModel.setPickerFilter(request.contextId, it) },
            onToggleExercise = viewModel::toggleExercise,
            onToggleSaved = viewModel::toggleSaved,
            onDismiss = { pickerRequest = null }
        )
    }

    if (copySheetVisible) {
        WorkoutCopySheet(
            targetDate = state.selectedDate,
            days = state.copyDays,
            onCopy = {
                viewModel.copyPlan(it)
                copySheetVisible = false
            },
            onDismiss = { copySheetVisible = false }
        )
    }

    state.notice?.let { message ->
        FudGlassDialog(onDismissRequest = viewModel::dismissNotice) {
            Text(
                text = stringResource(R.string.workout_log_reps_first),
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = message,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f),
                fontSize = 15.sp,
                lineHeight = 21.sp
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                FudGlassTextButton(text = stringResource(R.string.action_ok), onClick = viewModel::dismissNotice)
            }
        }
    }
}

@Composable
private fun WorkoutMenuGlyph(asset: String) {
    AsyncImage(
        model = asset,
        contentDescription = null,
        colorFilter = ColorFilter.tint(AppColors.Calorie),
        modifier = Modifier.size(20.dp)
    )
}

private fun workoutMenuGlyphAsset(title: String, muscles: Set<String>): String {
    if (muscles.size == 1) return muscleGlyphAsset(muscles.first())
    val key = when {
        title.contains("push", ignoreCase = true) -> "group_push"
        title.contains("pull", ignoreCase = true) -> "group_pull"
        title.contains("upper", ignoreCase = true) -> "group_upper"
        title.contains("lower", ignoreCase = true) ||
            title.contains("leg", ignoreCase = true) ||
            title.contains("quad", ignoreCase = true) ||
            title.contains("hamstring", ignoreCase = true) -> "group_lower"
        title.contains("core", ignoreCase = true) || title.contains("ab", ignoreCase = true) -> "abs"
        title.contains("arm", ignoreCase = true) ||
            title.contains("bicep", ignoreCase = true) ||
            title.contains("tricep", ignoreCase = true) -> "group_arms"
        title.contains("back", ignoreCase = true) ||
            title.contains("lat", ignoreCase = true) ||
            title.contains("trap", ignoreCase = true) -> "group_back"
        title.contains("chest", ignoreCase = true) -> "chest"
        title.contains("shoulder", ignoreCase = true) -> "shoulders"
        else -> "generic"
    }
    return "file:///android_asset/muscle/muscle_icon_$key.png"
}

@Composable
private fun WorkoutWeekHeader(weekStart: LocalDate, weekStartsOnMonday: Boolean) {
    val firstDay = remember(weekStartsOnMonday) {
        if (weekStartsOnMonday) DayOfWeek.MONDAY else DayOfWeek.SUNDAY
    }
    val currentWeekStart = remember(firstDay) { startOfWeek(LocalDate.now(), firstDay) }
    val end = weekStart.plusDays(6)
    val rangeFormatter = remember { DateTimeFormatter.ofPattern("MMM d", Locale.getDefault()) }
    val monthFormatter = remember { DateTimeFormatter.ofPattern("MMMM yyyy", Locale.getDefault()) }
    val title = if (weekStart == currentWeekStart) {
        stringResource(R.string.workout_this_week)
    } else {
        weekStart.format(monthFormatter)
    }
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 2.dp, bottom = 1.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(1.dp)
    ) {
        Text(
            title,
            fontSize = 21.sp,
            lineHeight = 23.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.KitchenEspresso
        )
        Text(
            "${weekStart.format(rangeFormatter)} – ${end.format(rangeFormatter)}",
            fontSize = 10.sp,
            lineHeight = 12.sp,
            color = AppColors.KitchenEspresso.copy(alpha = 0.68f)
        )
    }
}

@Composable
private fun WorkoutUtilityStrip(
    state: WorkoutDiaryUiState,
    onCalculate: () -> Unit,
    onShowLibrary: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth().heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .background(AppColors.KitchenPaper, RoundedCornerShape(3.dp))
                .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.20f), RoundedCornerShape(3.dp))
                .clickable(enabled = !state.isCalculatingBurn, onClick = onCalculate)
                .padding(horizontal = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            if (state.isCalculatingBurn) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    color = AppColors.KitchenTomato,
                    strokeWidth = 2.dp
                )
            } else {
                Icon(
                    Icons.Filled.LocalFireDepartment,
                    contentDescription = null,
                    tint = AppColors.KitchenTomato,
                    modifier = Modifier.size(17.dp)
                )
            }
            Text(
                if (state.caloriesBurned != null) {
                    "${state.caloriesBurned} ${stringResource(R.string.unit_kcal)}"
                } else {
                    stringResource(R.string.workout_calculate_burn)
                },
                modifier = Modifier.weight(1f),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = AppColors.KitchenEspresso
            )
            if (state.exercises.isNotEmpty()) {
                Text(
                    "${state.exercises.size}",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Black,
                    color = AppColors.KitchenTomato
                )
            }
        }
        WorkoutModeToggleButton(
            mode = com.apoorvdarshan.calorietracker.models.WorkoutTabMode.LOG,
            onToggle = onShowLibrary
        )
    }
}

@Composable
private fun WorkoutBurnHero(
    state: WorkoutDiaryUiState,
    onCalculate: () -> Unit,
    onShowLibrary: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth().padding(top = 6.dp, bottom = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            WorkoutModeToggleButton(
                mode = com.apoorvdarshan.calorietracker.models.WorkoutTabMode.LOG,
                onToggle = onShowLibrary
            )
        }
        WorkoutLogBurnButton(
            isCalculating = state.isCalculatingBurn,
            onCalculate = onCalculate,
            modifier = Modifier.fillMaxWidth()
        )

        if (state.exercises.isNotEmpty() || state.performedSetCount > 0 || state.caloriesBurned != null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .shadow(3.dp, RoundedCornerShape(4.dp))
                    .clip(RoundedCornerShape(4.dp))
                    .background(AppColors.KitchenPaper)
                    .border(
                        1.dp,
                        AppColors.KitchenEspresso.copy(alpha = 0.20f),
                        RoundedCornerShape(4.dp)
                    )
                    .padding(5.dp)
            ) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    WorkoutMetric(stringResource(R.string.workout_metric_sets), state.performedSetCount.toString(), Icons.Filled.Checklist, state.performedSetCount > 0, Modifier.weight(1f))
                    MetricDivider()
                    WorkoutMetric(stringResource(R.string.workout_metric_workouts), state.exercises.size.toString(), Icons.Filled.FitnessCenter, state.exercises.isNotEmpty(), Modifier.weight(1f))
                    MetricDivider()
                    WorkoutMetric(stringResource(R.string.workout_metric_reps), state.repCount.toString(), Icons.Filled.Repeat, state.repCount > 0, Modifier.weight(1f))
                    MetricDivider()
                    WorkoutMetric(
                        stringResource(R.string.workout_metric_burn),
                        state.caloriesBurned?.let { "$it ${stringResource(R.string.unit_kcal)}" }
                            ?: "-- ${stringResource(R.string.unit_kcal)}",
                        Icons.Filled.LocalFireDepartment,
                        state.caloriesBurned != null,
                        Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun WorkoutLogBurnButton(
    isCalculating: Boolean,
    onCalculate: () -> Unit,
    modifier: Modifier = Modifier
) {
    val burnDescription = stringResource(
        if (isCalculating) R.string.workout_calculating_burn_a11y
        else R.string.workout_calculate_burn_a11y
    )
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.985f else 1f,
        animationSpec = tween(durationMillis = 120),
        label = "workout-burn-press"
    )
    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 76.dp)
            .scale(scale)
            .shadow(
                6.dp,
                RoundedCornerShape(4.dp),
                ambientColor = Color.Black.copy(alpha = 0.12f),
                spotColor = Color.Black.copy(alpha = 0.12f)
            )
            .clip(RoundedCornerShape(4.dp))
            .background(AppColors.KitchenPaper)
            .border(
                1.dp,
                AppColors.KitchenEspresso.copy(alpha = 0.22f),
                RoundedCornerShape(4.dp)
            )
            .clickable(
                enabled = !isCalculating,
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = onCalculate
            )
            .semantics {
                contentDescription = burnDescription
            },
        contentAlignment = Alignment.Center
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 76.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .width(56.dp)
                    .heightIn(min = 76.dp)
                    .background(AppColors.KitchenTomato),
                contentAlignment = Alignment.Center
            ) {
                if (isCalculating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(28.dp),
                        color = Color.White,
                        strokeWidth = 2.5.dp
                    )
                } else {
                    Icon(
                        Icons.Filled.LocalFireDepartment,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(25.dp)
                    )
                }
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 13.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Text(
                    text = stringResource(R.string.workout_calorie_burn_label).uppercase(Locale.getDefault()),
                    color = MaterialTheme.colorScheme.secondary,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Black,
                    letterSpacing = 0.7.sp,
                    maxLines = 1
                )
                KitchenReceiptRule()
                Text(
                    text = stringResource(
                        if (isCalculating) R.string.workout_calculating else R.string.workout_calculate
                    ),
                    color = MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Black,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun WorkoutMetric(
    label: String,
    value: String,
    icon: ImageVector,
    active: Boolean,
    modifier: Modifier = Modifier
) {
    val color = if (active) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
    Column(
        modifier = modifier.padding(horizontal = 5.dp, vertical = 5.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(14.dp))
            Text(
                text = label,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
        }
        Text(
            text = value,
            color = color,
            fontSize = 18.sp,
            fontWeight = FontWeight.ExtraBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun MetricDivider() {
    Box(
        Modifier
            .width(1.dp)
            .height(34.dp)
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.46f))
    )
}

@Composable
private fun WorkoutDayHeader(
    selectedDate: LocalDate,
    workoutCount: Int,
    modifier: Modifier = Modifier
) {
    val today = LocalDate.now()
    val dateTitle = when (selectedDate) {
        today -> stringResource(R.string.workout_today)
        today.plusDays(1) -> stringResource(R.string.workout_tomorrow)
        today.minusDays(1) -> stringResource(R.string.workout_yesterday)
        else -> selectedDate.format(DateTimeFormatter.ofPattern("EEEE, MMM d", Locale.getDefault()))
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.CalendarMonth, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(19.dp))
        Spacer(Modifier.width(8.dp))
        Text(
            text = dateTitle,
            color = MaterialTheme.colorScheme.onSurface,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = pluralStringResource(R.plurals.workout_count, workoutCount, workoutCount),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun WorkoutEmptyState(
    splitTitle: String,
    onAdd: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .shadow(3.dp, RoundedCornerShape(3.dp))
            .clip(RoundedCornerShape(3.dp))
            .background(AppColors.KitchenPaper)
            .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.24f), RoundedCornerShape(3.dp))
            .clickable(onClick = onAdd)
            .padding(horizontal = 13.dp, vertical = 10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            Icon(Icons.Filled.Add, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    stringResource(R.string.workout_empty_title),
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    stringResource(R.string.workout_empty_body_format, splitTitle),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .offset(x = (-18).dp)
                .size(10.dp)
                .background(MaterialTheme.colorScheme.background, CircleShape)
        )
        Box(
            Modifier
                .align(Alignment.CenterEnd)
                .offset(x = 18.dp)
                .size(10.dp)
                .background(MaterialTheme.colorScheme.background, CircleShape)
        )
    }
}

@Composable
private fun WorkoutExerciseCard(
    exercise: PlannedExercise,
    modifier: Modifier = Modifier,
    weightUnit: WorkoutWeightUnit,
    rpePlaceholder: String,
    isSaved: Boolean,
    onOpen: () -> Unit,
    onToggleSaved: () -> Unit,
    onRemove: () -> Unit,
    onSetCount: (Int) -> Unit,
    onWeight: (UUID, String) -> Unit,
    onReps: (UUID, String) -> Unit,
    onRpe: (UUID, String) -> Unit
) {
    val fallbackWorkoutLabel = stringResource(R.string.workout_fallback_label)
    val unspecifiedLabel = stringResource(R.string.workout_unspecified)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .shadow(4.dp, RoundedCornerShape(3.dp))
            .clip(RoundedCornerShape(3.dp))
            .background(AppColors.KitchenPaper)
            .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.24f), RoundedCornerShape(3.dp))
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 11.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp)
                    .clickable(onClick = onOpen),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.42f))
                        .border(
                            1.dp,
                            MaterialTheme.colorScheme.outlineVariant,
                            RoundedCornerShape(2.dp)
                        )
                ) {
                    AnimatedExerciseImage(exercise.imagePaths, Modifier.fillMaxSize())
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(
                        exercise.primaryMuscles.firstOrNull()?.uppercase(Locale.getDefault())
                            ?: fallbackWorkoutLabel.uppercase(Locale.getDefault()),
                        color = AppColors.KitchenTomato,
                        fontSize = 7.sp,
                        lineHeight = 8.sp,
                        letterSpacing = 0.7.sp,
                        fontWeight = FontWeight.Black,
                        maxLines = 1
                    )
                    Text(
                        exercise.name,
                        color = MaterialTheme.colorScheme.onSurface,
                        fontSize = 15.sp,
                        lineHeight = 17.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        buildString {
                            append(exercise.primaryMuscles.joinToString().ifBlank { unspecifiedLabel })
                            append(" · ")
                            append(exercise.equipment)
                        },
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.57f),
                        fontSize = 9.sp,
                        lineHeight = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = stringResource(R.string.workout_open_exercise_a11y),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.34f),
                    modifier = Modifier.size(16.dp)
                )
            }

            KitchenReceiptRule()

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.Checklist, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(
                    stringResource(R.string.workout_sets_label),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.weight(1f))
                IconButton(
                    onClick = { onSetCount(exercise.sets.size - 1) },
                    enabled = exercise.sets.size > 1,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(Icons.Filled.Remove, contentDescription = stringResource(R.string.workout_remove_set_a11y), modifier = Modifier.size(15.dp))
                }
                Text(
                    pluralStringResource(R.plurals.workout_set_count, exercise.sets.size, exercise.sets.size),
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(46.dp)
                )
                IconButton(
                    onClick = { onSetCount(exercise.sets.size + 1) },
                    enabled = exercise.sets.size < 12,
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.workout_add_set_a11y), modifier = Modifier.size(15.dp))
                }
                IconButton(onClick = onToggleSaved, modifier = Modifier.size(48.dp)) {
                    Icon(
                        if (isSaved) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                        contentDescription = stringResource(
                            if (isSaved) R.string.workout_unsave_exercise_a11y
                            else R.string.workout_save_exercise_a11y
                        ),
                        tint = if (isSaved) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.48f),
                        modifier = Modifier.size(16.dp)
                    )
                }
                IconButton(onClick = onRemove, modifier = Modifier.size(48.dp)) {
                    Icon(
                        Icons.Filled.DeleteOutline,
                        contentDescription = stringResource(R.string.workout_remove_exercise_a11y),
                        tint = MaterialTheme.colorScheme.error.copy(alpha = 0.82f),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            Column {
                exercise.sets.forEachIndexed { index, set ->
                    WorkoutSetRow(
                        index = index,
                        set = set,
                        weightUnit = weightUnit,
                        rpePlaceholder = set.rpeScale?.inputPlaceholder ?: rpePlaceholder,
                        onWeight = { onWeight(set.id, it) },
                        onReps = { onReps(set.id, it) },
                        onRpe = { onRpe(set.id, it) }
                    )
                    if (index < exercise.sets.lastIndex) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 54.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
                            thickness = 0.6.dp
                        )
                    }
                }
            }
        }
        Box(
            Modifier
                .align(Alignment.CenterStart)
                .offset(x = (-5).dp)
                .size(10.dp)
                .background(MaterialTheme.colorScheme.background, CircleShape)
                .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.18f), CircleShape)
        )
        Box(
            Modifier
                .align(Alignment.CenterEnd)
                .offset(x = 5.dp)
                .size(10.dp)
                .background(MaterialTheme.colorScheme.background, CircleShape)
                .border(1.dp, AppColors.KitchenEspresso.copy(alpha = 0.18f), CircleShape)
        )
    }
}

@Composable
private fun WorkoutSetRow(
    index: Int,
    set: PlannedSet,
    weightUnit: WorkoutWeightUnit,
    rpePlaceholder: String,
    onWeight: (String) -> Unit,
    onReps: (String) -> Unit,
    onRpe: (String) -> Unit
) {
    val focusManager = LocalFocusManager.current
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        Text(
            stringResource(R.string.workout_set_number_format, index + 1),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            modifier = Modifier.width(36.dp)
        )
        WorkoutSetField(
            value = set.displayWeight(weightUnit),
            onValueChange = onWeight,
            placeholder = weightUnit.storageValue,
            keyboardType = KeyboardType.Decimal,
            modifier = Modifier.weight(1f)
        )
        WorkoutSetField(
            value = set.reps,
            onValueChange = onReps,
            placeholder = stringResource(R.string.workout_reps_placeholder),
            keyboardType = KeyboardType.Number,
            modifier = Modifier.weight(1f)
        )
        WorkoutSetField(
            value = set.rpe,
            onValueChange = onRpe,
            placeholder = rpePlaceholder,
            keyboardType = KeyboardType.Decimal,
            modifier = Modifier.weight(1f),
            keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() })
        )
    }
}

@Composable
private fun WorkoutSetField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardType: KeyboardType,
    modifier: Modifier = Modifier,
    keyboardActions: KeyboardActions = KeyboardActions.Default
) {
    val shape = RoundedCornerShape(2.dp)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = TextStyle(
            color = MaterialTheme.colorScheme.onSurface,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        ),
        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
        keyboardOptions = KeyboardOptions(
            keyboardType = keyboardType,
            imeAction = ImeAction.Next
        ),
        keyboardActions = keyboardActions,
        modifier = modifier
            .heightIn(min = 48.dp)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.62f))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, shape)
            .padding(horizontal = 4.dp),
        decorationBox = { inner ->
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                if (value.isEmpty()) {
                    Text(
                        placeholder,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                        fontSize = 9.sp,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        maxLines = 1
                    )
                }
                inner()
            }
        }
    )
}

@Composable
private fun WorkoutWeekStrip(
    selectedDate: LocalDate,
    workoutCounts: Map<LocalDate, Int>,
    onSelect: (LocalDate) -> Unit,
    onVisibleWeekChange: (LocalDate) -> Unit,
    onSettledWeekChange: (LocalDate) -> Unit,
    weekStartsOnMonday: Boolean,
    modifier: Modifier = Modifier
) {
    val firstDay = remember(weekStartsOnMonday) {
        if (weekStartsOnMonday) DayOfWeek.MONDAY else DayOfWeek.SUNDAY
    }
    val today = remember { LocalDate.now() }
    val currentWeekStart = remember(today, firstDay) { startOfWeek(today, firstDay) }
    val targetWeek = remember(selectedDate, currentWeekStart, firstDay) {
        val selectedStart = startOfWeek(selectedDate, firstDay)
        val difference = ChronoUnit.WEEKS.between(currentWeekStart, selectedStart).toInt()
        (CURRENT_WORKOUT_WEEK + difference).coerceIn(0, CURRENT_WORKOUT_WEEK)
    }
    val state = rememberLazyListState(initialFirstVisibleItemIndex = targetWeek)
    val fling = rememberSnapFlingBehavior(lazyListState = state)
    val currentOnVisibleWeekChange by rememberUpdatedState(onVisibleWeekChange)
    val currentOnSettledWeekChange by rememberUpdatedState(onSettledWeekChange)

    LaunchedEffect(targetWeek) {
        if (state.firstVisibleItemIndex != targetWeek) state.animateScrollToItem(targetWeek)
    }

    LaunchedEffect(state, currentWeekStart) {
        var wasScrolling = false
        snapshotFlow { state.firstVisibleItemIndex to state.isScrollInProgress }.collect { (weekIndex, scrolling) ->
            val visibleStart = currentWeekStart.plusWeeks(
                (weekIndex - CURRENT_WORKOUT_WEEK).toLong()
            )
            currentOnVisibleWeekChange(
                visibleStart
            )
            if (scrolling) {
                wasScrolling = true
            } else if (wasScrolling) {
                wasScrolling = false
                currentOnSettledWeekChange(visibleStart)
            }
        }
    }

    BoxWithConstraints(modifier.fillMaxWidth()) {
        val pageWidth = maxWidth.coerceAtLeast(336.dp)
        LazyRow(state = state, flingBehavior = fling, modifier = Modifier.fillMaxWidth()) {
            items((0 until WORKOUT_WEEKS).toList()) { weekIndex ->
                val weekStart = currentWeekStart.plusWeeks((weekIndex - CURRENT_WORKOUT_WEEK).toLong())
                Row(Modifier.width(pageWidth)) {
                    repeat(7) { dayIndex ->
                        val date = weekStart.plusDays(dayIndex.toLong())
                        WorkoutDayTile(
                            date = date,
                            isSelected = date == selectedDate,
                            isToday = date == today,
                            count = workoutCounts[date] ?: 0,
                            // The visible days in the current week are all
                            // selectable for planning, including tomorrow.
                            // Horizontal forward swipes remain capped at today.
                            enabled = true,
                            onClick = { onSelect(date) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun WorkoutDayTile(
    date: LocalDate,
    isSelected: Boolean,
    isToday: Boolean,
    count: Int,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .heightIn(min = 48.dp)
            .alpha(if (enabled) 1f else 0.32f)
            .semantics(mergeDescendants = true) { selected = isSelected }
            .clickable(
                enabled = enabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                role = Role.Tab,
                onClick = onClick
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        Text(
            date.dayOfWeek.getDisplayName(java.time.format.TextStyle.NARROW, Locale.getDefault()),
            color = if (isSelected) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.42f),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium
        )
        Box(
            modifier = Modifier
                .size(36.dp)
                .then(
                    when {
                        isSelected -> Modifier
                            .shadow(6.dp, CircleShape, ambientColor = AppColors.Calorie.copy(alpha = 0.3f))
                            .clip(CircleShape)
                            .background(Brush.linearGradient(listOf(AppColors.CalorieStart, AppColors.CalorieEnd)))
                        isToday -> Modifier.border(1.5.dp, AppColors.Calorie.copy(alpha = 0.35f), CircleShape)
                        else -> Modifier
                    }
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                date.dayOfMonth.toString(),
                color = when {
                    isSelected -> MaterialTheme.colorScheme.onPrimary
                    isToday -> AppColors.Calorie
                    else -> MaterialTheme.colorScheme.onSurface
                },
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        Box(
            Modifier
                .size(4.dp)
                .clip(CircleShape)
                .background(if (count > 0) AppColors.Calorie else Color.Transparent)
        )
    }
}

private fun Modifier.workoutDaySwipe(
    selectedDate: LocalDate,
    onMove: (Long) -> Unit
): Modifier = pointerInput(selectedDate) {
    var accumulated = 0f
    val threshold = 80.dp.toPx()
    detectHorizontalDragGestures(
        onDragStart = { accumulated = 0f },
        onDragCancel = { accumulated = 0f },
        onHorizontalDrag = { change, amount ->
            accumulated += amount
            change.consume()
        },
        onDragEnd = {
            when {
                accumulated > threshold -> onMove(-1L)
                accumulated < -threshold && selectedDate.isBefore(LocalDate.now()) -> onMove(1L)
            }
            accumulated = 0f
        }
    )
}

private fun startOfWeek(date: LocalDate, firstDay: DayOfWeek): LocalDate {
    val daysBack = ((date.dayOfWeek.value - firstDay.value) + 7) % 7
    return date.minusDays(daysBack.toLong())
}

internal fun selectedDateTitle(date: LocalDate, today: LocalDate = LocalDate.now()): String = when (date) {
    today -> "Today"
    today.plusDays(1) -> "Tomorrow"
    today.minusDays(1) -> "Yesterday"
    else -> date.format(DateTimeFormatter.ofPattern("EEEE, MMM d", Locale.getDefault()))
}
