package com.apoorvdarshan.calorietracker.ui.workouts

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.runtime.setValue
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
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

private const val WORKOUT_WEEKS = 53
private const val CURRENT_WORKOUT_WEEK = WORKOUT_WEEKS - 1

@Composable
internal fun WorkoutDiaryScreen(
    state: WorkoutDiaryUiState,
    exerciseRepository: ExerciseRepository,
    viewModel: WorkoutsViewModel,
    modifier: Modifier = Modifier,
    weekStartsOnMonday: Boolean = true,
    onShowLibrary: () -> Unit
) {
    var pickerRequest by remember { mutableStateOf<WorkoutPickerRequest?>(null) }
    var copySheetVisible by remember { mutableStateOf(false) }
    var addMenuExpanded by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()
    val focusManager = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    val exerciseCardBounds = remember { mutableStateMapOf<UUID, androidx.compose.ui.geometry.Rect>() }
    var diaryRootOrigin by remember { mutableStateOf(Offset.Zero) }

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
            .background(MaterialTheme.colorScheme.background)
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
                start = 16.dp,
                top = 8.dp,
                end = 16.dp,
                bottom = BottomNavScrollPadding + 76.dp
            ),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item(key = "workout-week-strip") {
                WorkoutWeekStrip(
                    selectedDate = state.selectedDate,
                    workoutCounts = state.workoutCounts,
                    onSelect = {
                        dismissKeyboard()
                        viewModel.selectDate(it)
                    },
                    weekStartsOnMonday = weekStartsOnMonday,
                    modifier = Modifier.padding(top = 2.dp, bottom = 4.dp)
                )
            }

            item(key = "workout-burn") {
                WorkoutBurnHero(
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

            item(key = "workout-day-title") {
                WorkoutDayHeader(
                    selectedDate = state.selectedDate,
                    workoutCount = state.exercises.size,
                    modifier = Modifier
                        .workoutDaySwipe(
                            selectedDate = state.selectedDate,
                            onMove = {
                                dismissKeyboard()
                                viewModel.moveDate(it)
                            }
                        )
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) { dismissKeyboard() }
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

            item(key = "workout-extra-space") { Spacer(Modifier.height(24.dp)) }
        }

        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .navigationBarsPadding()
                .padding(end = 24.dp, bottom = 100.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(CircleShape)
                    .background(AppColors.Calorie)
                    .clickable(role = Role.Button) {
                        dismissKeyboard()
                        addMenuExpanded = true
                    }
                    .semantics { contentDescription = "Add workout" },
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(30.dp))
            }

            SheetGlassDropdownMenu(
                expanded = addMenuExpanded,
                onDismissRequest = { addMenuExpanded = false },
                modifier = Modifier.heightIn(max = 520.dp),
                menuWidth = 236.dp
            ) {
                if (state.splitGroups.isEmpty()) {
                    SheetGlassDropdownMenuItem(
                        label = "All exercises",
                        leadingContent = { WorkoutMenuGlyph(workoutMenuGlyphAsset("All exercises", emptySet())) },
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
                    label = "Copy from day",
                    leadingIcon = Icons.Filled.ContentCopy,
                    onClick = {
                        addMenuExpanded = false
                        copySheetVisible = true
                    }
                )
                SheetGlassDropdownMenuItem(
                    label = "Saved",
                    leadingIcon = Icons.Filled.Bookmark,
                    onClick = {
                        addMenuExpanded = false
                        pickerRequest = WorkoutPickerRequest.saved()
                    }
                )
            }
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
                text = "Log reps first",
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
                FudGlassTextButton(text = "OK", onClick = viewModel::dismissNotice)
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
private fun WorkoutBurnHero(
    state: WorkoutDiaryUiState,
    onCalculate: () -> Unit,
    onShowLibrary: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth().padding(top = 18.dp, bottom = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(22.dp)
    ) {
        Box(modifier = Modifier.fillMaxWidth().height(176.dp)) {
            WorkoutLogBurnButton(
                isCalculating = state.isCalculatingBurn,
                onCalculate = onCalculate,
                modifier = Modifier.align(Alignment.Center)
            )
            WorkoutModeToggleButton(
                mode = com.apoorvdarshan.calorietracker.models.WorkoutTabMode.LOG,
                onToggle = onShowLibrary,
                modifier = Modifier.align(Alignment.TopEnd)
            )
        }

        FudGlassSurface(
            modifier = Modifier.fillMaxWidth(),
            cornerRadius = 26.dp,
            padding = 10.dp
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                WorkoutMetric(
                    label = "Sets",
                    value = state.performedSetCount.toString(),
                    icon = Icons.Filled.Checklist,
                    active = state.performedSetCount > 0,
                    modifier = Modifier.weight(1f)
                )
                MetricDivider()
                WorkoutMetric(
                    label = "Workouts",
                    value = state.exercises.size.toString(),
                    icon = Icons.Filled.FitnessCenter,
                    active = state.exercises.isNotEmpty(),
                    modifier = Modifier.weight(1f)
                )
                MetricDivider()
                WorkoutMetric(
                    label = "Reps",
                    value = state.repCount.toString(),
                    icon = Icons.Filled.Repeat,
                    active = state.repCount > 0,
                    modifier = Modifier.weight(1f)
                )
                MetricDivider()
                WorkoutMetric(
                    label = "Burn",
                    value = state.caloriesBurned?.let { "$it kcal" } ?: "-- kcal",
                    icon = Icons.Filled.LocalFireDepartment,
                    active = state.caloriesBurned != null,
                    modifier = Modifier.weight(1f)
                )
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
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.88f else 1f,
        animationSpec = tween(durationMillis = 120),
        label = "workout-burn-press"
    )
    Box(
        modifier = modifier
            .size(176.dp)
            .scale(scale)
            .clickable(
                enabled = !isCalculating,
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = onCalculate
            )
            .semantics {
                contentDescription = if (isCalculating) {
                    "Calculating calorie burn"
                } else {
                    "Calculate calorie burn"
                }
            },
        contentAlignment = Alignment.Center
    ) {
        Image(
            painter = painterResource(R.drawable.timer_button_red),
            contentDescription = null,
            modifier = Modifier.fillMaxSize()
        )
        Column(
            modifier = Modifier.size(156.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            if (isCalculating) {
                CircularProgressIndicator(
                    modifier = Modifier.size(27.dp),
                    color = Color.White,
                    strokeWidth = 2.5.dp
                )
            } else {
                Icon(
                    Icons.Filled.LocalFireDepartment,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(27.dp)
                )
            }
            Spacer(Modifier.height(5.dp))
            Text(
                text = if (isCalculating) "Calculating…" else "Calculate",
                color = Color.White,
                fontSize = if (isCalculating) 18.sp else 22.sp,
                fontWeight = FontWeight.Black,
                maxLines = 1
            )
            Text(
                text = "CALORIE BURN",
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 9.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 0.4.sp,
                maxLines = 1
            )
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
        modifier = modifier.padding(horizontal = 7.dp, vertical = 7.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
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
            fontSize = 24.sp,
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
            .height(44.dp)
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.46f))
    )
}

@Composable
private fun WorkoutDayHeader(
    selectedDate: LocalDate,
    workoutCount: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.CalendarMonth, contentDescription = null, tint = AppColors.Calorie, modifier = Modifier.size(19.dp))
        Spacer(Modifier.width(8.dp))
        Text(
            text = selectedDateTitle(selectedDate),
            color = MaterialTheme.colorScheme.onSurface,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "$workoutCount ${if (workoutCount == 1) "workout" else "workouts"}",
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
    FudGlassSurface(
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onAdd),
        cornerRadius = 20.dp,
        padding = 14.dp
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Icon(Icons.Filled.Add, contentDescription = null, tint = AppColors.Calorie, modifier = Modifier.size(28.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    "No workouts logged",
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    "Use + to pick $splitTitle exercises for this day",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
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
    FudGlassSurface(
        modifier = modifier.fillMaxWidth(),
        cornerRadius = 24.dp,
        padding = 0.dp
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onOpen),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.42f))
                        .border(
                            0.7.dp,
                            MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f),
                            RoundedCornerShape(16.dp)
                        )
                ) {
                    AnimatedExerciseImage(exercise.imagePaths, Modifier.fillMaxSize())
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Text(
                        exercise.name,
                        color = MaterialTheme.colorScheme.onSurface,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        buildString {
                            append(exercise.primaryMuscles.joinToString().ifBlank { "Unspecified" })
                            append(" · ")
                            append(exercise.equipment)
                        },
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.57f),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = "Open exercise instructions",
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.34f),
                    modifier = Modifier.size(20.dp)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Filled.Checklist, contentDescription = null, tint = AppColors.Calorie, modifier = Modifier.size(17.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    "Sets",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.weight(1f))
                IconButton(
                    onClick = { onSetCount(exercise.sets.size - 1) },
                    enabled = exercise.sets.size > 1,
                    modifier = Modifier.size(34.dp)
                ) {
                    Icon(Icons.Filled.Remove, contentDescription = "Remove set", modifier = Modifier.size(18.dp))
                }
                Text(
                    "${exercise.sets.size} ${if (exercise.sets.size == 1) "set" else "sets"}",
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.width(54.dp)
                )
                IconButton(
                    onClick = { onSetCount(exercise.sets.size + 1) },
                    enabled = exercise.sets.size < 12,
                    modifier = Modifier.size(34.dp)
                ) {
                    Icon(Icons.Filled.Add, contentDescription = "Add blank set", modifier = Modifier.size(18.dp))
                }
                IconButton(onClick = onToggleSaved, modifier = Modifier.size(36.dp)) {
                    Icon(
                        if (isSaved) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                        contentDescription = if (isSaved) "Unsave exercise" else "Save exercise",
                        tint = if (isSaved) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.48f),
                        modifier = Modifier.size(19.dp)
                    )
                }
                IconButton(onClick = onRemove, modifier = Modifier.size(36.dp)) {
                    Icon(
                        Icons.Filled.DeleteOutline,
                        contentDescription = "Remove exercise",
                        tint = MaterialTheme.colorScheme.error.copy(alpha = 0.82f),
                        modifier = Modifier.size(19.dp)
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
        modifier = Modifier.fillMaxWidth().padding(vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        Text(
            "Set ${index + 1}",
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            modifier = Modifier.width(47.dp)
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
            placeholder = "Reps",
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
    val shape = RoundedCornerShape(11.dp)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = true,
        textStyle = TextStyle(
            color = MaterialTheme.colorScheme.onSurface,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        ),
        cursorBrush = SolidColor(AppColors.Calorie),
        keyboardOptions = KeyboardOptions(
            keyboardType = keyboardType,
            imeAction = ImeAction.Next
        ),
        keyboardActions = keyboardActions,
        modifier = modifier
            .height(39.dp)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.62f))
            .border(0.6.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), shape)
            .padding(horizontal = 7.dp),
        decorationBox = { inner ->
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                if (value.isEmpty()) {
                    Text(
                        placeholder,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
                        fontSize = 12.sp,
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

    LaunchedEffect(targetWeek) {
        if (state.firstVisibleItemIndex != targetWeek) state.animateScrollToItem(targetWeek)
    }

    BoxWithConstraints(modifier.fillMaxWidth()) {
        val pageWidth = maxWidth
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
            .alpha(if (enabled) 1f else 0.32f)
            .clickable(
                enabled = enabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
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
                    isSelected -> Color.White
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
