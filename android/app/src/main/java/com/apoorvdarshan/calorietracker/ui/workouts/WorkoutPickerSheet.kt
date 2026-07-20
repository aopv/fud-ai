@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.apoorvdarshan.calorietracker.ui.workouts

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EventRepeat
import androidx.compose.material.icons.filled.FilterAltOff
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.data.ExerciseItem
import com.apoorvdarshan.calorietracker.data.ExerciseRepository
import com.apoorvdarshan.calorietracker.data.ExerciseSort
import com.apoorvdarshan.calorietracker.models.WorkoutSplitGroup
import com.apoorvdarshan.calorietracker.ui.components.FudGlassSurface
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextButton
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

internal enum class WorkoutPickerSource {
    DATASET,
    SAVED
}

internal data class WorkoutPickerRequest(
    val title: String,
    val muscles: Set<String>,
    val initialSource: WorkoutPickerSource
) {
    val contextId: String
        get() = buildString {
            append(title.lowercase(Locale.US).replace(Regex("[^a-z0-9]+"), "-"))
            if (muscles.isNotEmpty()) append(":" + muscles.sorted().joinToString("|"))
        }

    val isSavedContext: Boolean
        get() = initialSource == WorkoutPickerSource.SAVED && title == "Saved exercises"

    companion object {
        fun all() = WorkoutPickerRequest("All exercises", emptySet(), WorkoutPickerSource.DATASET)
        fun saved() = WorkoutPickerRequest("Saved exercises", emptySet(), WorkoutPickerSource.SAVED)
        fun forSplit(title: String, groups: List<WorkoutSplitGroup>) = WorkoutPickerRequest(
            title = title,
            muscles = groups.flatMapTo(mutableSetOf()) { it.muscles },
            initialSource = WorkoutPickerSource.DATASET
        )
        fun group(group: WorkoutSplitGroup) = WorkoutPickerRequest(
            title = group.title,
            muscles = group.muscles,
            initialSource = WorkoutPickerSource.DATASET
        )
    }
}

@Composable
internal fun WorkoutPickerSheet(
    request: WorkoutPickerRequest,
    repository: ExerciseRepository,
    selectedExerciseIds: Set<String>,
    savedExerciseIds: Set<String>,
    initialSource: WorkoutPickerSource,
    initialFilterState: WorkoutPickerFilterState,
    onSourceChange: (WorkoutPickerSource) -> Unit,
    onFilterStateChange: (WorkoutPickerFilterState) -> Unit,
    onToggleExercise: (ExerciseItem) -> Unit,
    onToggleSaved: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var source by remember(request.contextId, initialSource) {
        mutableStateOf(if (request.isSavedContext) WorkoutPickerSource.SAVED else initialSource)
    }
    var filter by remember(request.contextId) { mutableStateOf(initialFilterState) }
    val focus = LocalFocusManager.current
    val keyboard = LocalSoftwareKeyboardController.current
    val listState = rememberLazyListState()

    LaunchedEffect(listState.isScrollInProgress) {
        if (listState.isScrollInProgress) {
            keyboard?.hide()
            focus.clearFocus()
        }
    }

    fun updateFilter(transform: (WorkoutPickerFilterState) -> WorkoutPickerFilterState) {
        val next = transform(filter)
        filter = next
        onFilterStateChange(next)
    }

    val items = remember(
        repository,
        source,
        filter,
        savedExerciseIds
    ) {
        repository.filtered(
            levels = filter.level?.let(::setOf).orEmpty(),
            equipment = filter.equipment?.let(::setOf).orEmpty(),
            primaryMuscles = filter.primaryMuscle?.let(::setOf).orEmpty(),
            secondaryMuscles = emptySet(),
            forces = emptySet(),
            mechanics = emptySet(),
            categories = emptySet(),
            sort = ExerciseSort.NAME,
            searchText = filter.search
        ).filter { item ->
            val matchesSource = source == WorkoutPickerSource.DATASET || item.id in savedExerciseIds
            val matchesContext = request.muscles.isEmpty() ||
                item.primaryMuscles.any(request.muscles::contains) ||
                item.secondaryMuscles.any(request.muscles::contains)
            matchesSource && matchesContext
        }
    }
    val muscleOptions = remember(repository, request.muscles) {
        if (request.muscles.isEmpty()) repository.availablePrimaryMuscles
        else repository.availablePrimaryMuscles.filter(request.muscles::contains)
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = MaterialTheme.colorScheme.background,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .navigationBarsPadding()
                .background(workoutsColors().background)
        ) {
            PickerHeader(title = request.title, count = items.size, onDismiss = onDismiss)

            Column(
                modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 14.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (!request.isSavedContext) {
                    PickerSourceControl(
                        source = source,
                        onSelect = {
                            focus.clearFocus()
                            source = it
                            onSourceChange(it)
                        }
                    )
                }

                SearchPill(
                    value = filter.search,
                    onValueChange = { value -> updateFilter { it.copy(search = value) } }
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(9.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    FilterPill(
                        title = "Muscle",
                        icon = Icons.Filled.FitnessCenter,
                        selected = filter.primaryMuscle?.let(::setOf).orEmpty(),
                        emptyDisplay = "All ${muscleOptions.size}",
                        options = muscleOptions,
                        glyphFor = { muscleGlyphAsset(it) },
                        onSelect = { selected -> updateFilter { it.copy(primaryMuscle = selected.firstOrNull()) } }
                    )
                    FilterPill(
                        title = "Equipment",
                        icon = Icons.Filled.FitnessCenter,
                        selected = filter.equipment?.let(::setOf).orEmpty(),
                        emptyDisplay = "All ${repository.availableEquipment.size}",
                        options = repository.availableEquipment,
                        onSelect = { selected -> updateFilter { it.copy(equipment = selected.firstOrNull()) } }
                    )
                    FilterPill(
                        title = "Level",
                        icon = Icons.Filled.Storage,
                        selected = filter.level?.let(::setOf).orEmpty(),
                        emptyDisplay = "All",
                        options = repository.availableLevels,
                        onSelect = { selected -> updateFilter { it.copy(level = selected.firstOrNull()) } }
                    )
                    val hasFilters = filter.search.isNotEmpty() || filter.primaryMuscle != null ||
                        filter.equipment != null || filter.level != null
                    if (hasFilters) {
                        CapsuleButton(
                            text = "Clear",
                            icon = Icons.Filled.FilterAltOff,
                            tint = AppColors.Calorie,
                            enabled = true,
                            active = true
                        ) {
                            focus.clearFocus()
                            updateFilter { WorkoutPickerFilterState() }
                        }
                    }
                }
            }

            PickerResultsHeader(
                count = items.size,
                source = source,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
            )

            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxWidth().weight(1f),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 28.dp)
            ) {
                if (items.isEmpty()) {
                    item(key = "empty-picker") {
                        PickerEmptyState(source = source)
                    }
                } else {
                    items(items.take(120), key = { it.id }) { item ->
                        ExerciseRow(
                            item = item,
                            onClick = { onToggleExercise(item) },
                            trailingContent = {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(2.dp)
                                ) {
                                    IconButton(onClick = { onToggleSaved(item.id) }, modifier = Modifier.size(36.dp)) {
                                        Icon(
                                            if (item.id in savedExerciseIds) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                                            contentDescription = if (item.id in savedExerciseIds) "Unsave exercise" else "Save exercise",
                                            tint = if (item.id in savedExerciseIds) AppColors.Calorie else workoutsColors().mutedText,
                                            modifier = Modifier.size(20.dp)
                                        )
                                    }
                                    Box(
                                        modifier = Modifier
                                            .size(34.dp)
                                            .clip(CircleShape)
                                            .background(
                                                if (item.id in selectedExerciseIds) AppColors.Calorie
                                                else workoutsColors().panel.copy(alpha = 0.52f)
                                            )
                                            .clickable { onToggleExercise(item) },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            if (item.id in selectedExerciseIds) Icons.Filled.Check else Icons.Filled.AddCircle,
                                            contentDescription = if (item.id in selectedExerciseIds) "Remove from day" else "Add to day",
                                            tint = if (item.id in selectedExerciseIds) androidx.compose.ui.graphics.Color.White else workoutsColors().mutedText,
                                            modifier = Modifier.size(if (item.id in selectedExerciseIds) 18.dp else 23.dp)
                                        )
                                    }
                                }
                            }
                        )
                        HorizontalDivider(
                            color = workoutsColors().hairline.copy(alpha = 0.28f),
                            thickness = 0.5.dp,
                            modifier = Modifier.padding(start = 144.dp, end = 20.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PickerHeader(title: String, count: Int, onDismiss: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 20.dp, top = 16.dp, end = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                title,
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = 21.sp,
                fontWeight = FontWeight.ExtraBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                "$count ${if (count == 1) "exercise" else "exercises"}",
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.52f),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        FudGlassTextButton(text = "Done", onClick = onDismiss)
    }
}

@Composable
private fun PickerResultsHeader(
    count: Int,
    source: WorkoutPickerSource,
    modifier: Modifier = Modifier
) {
    val colors = workoutsColors()
    Row(modifier = modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        Column(Modifier.weight(1f)) {
            Text(
                "$count ${if (count == 1) "exercise" else "exercises"}",
                color = colors.charcoal,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                if (source == WorkoutPickerSource.SAVED) "Saved" else "Name",
                color = colors.mutedText,
                fontSize = 12.sp
            )
        }
        Text(
            "Tap + to add",
            color = colors.mutedText,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(top = 3.dp)
        )
    }
}

@Composable
private fun PickerSourceControl(
    source: WorkoutPickerSource,
    onSelect: (WorkoutPickerSource) -> Unit,
    modifier: Modifier = Modifier
) {
    FudGlassSurface(modifier = modifier.fillMaxWidth(), cornerRadius = 18.dp, padding = 4.dp) {
        Row(Modifier.fillMaxWidth()) {
            listOf(
                WorkoutPickerSource.DATASET to "Dataset",
                WorkoutPickerSource.SAVED to "Saved"
            ).forEach { (option, label) ->
                val selected = source == option
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (selected) AppColors.Calorie.copy(alpha = 0.14f) else androidx.compose.ui.graphics.Color.Transparent)
                        .clickable { onSelect(option) }
                        .padding(vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(
                        if (option == WorkoutPickerSource.DATASET) Icons.Filled.Storage else Icons.Filled.Bookmark,
                        contentDescription = null,
                        tint = if (selected) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.48f),
                        modifier = Modifier.size(17.dp)
                    )
                    Spacer(Modifier.width(7.dp))
                    Text(
                        label,
                        color = if (selected) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun PickerEmptyState(source: WorkoutPickerSource) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 54.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(9.dp)
    ) {
        Icon(
            if (source == WorkoutPickerSource.SAVED) Icons.Filled.BookmarkBorder else Icons.Filled.FitnessCenter,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
            modifier = Modifier.size(38.dp)
        )
        Text(
            if (source == WorkoutPickerSource.SAVED) "No saved exercises" else "No matching exercises",
            color = MaterialTheme.colorScheme.onSurface,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            if (source == WorkoutPickerSource.SAVED) {
                "Bookmark exercises from the dataset to keep them here."
            } else {
                "Try clearing one or more filters."
            },
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.52f),
            fontSize = 13.sp
        )
    }
}

@Composable
internal fun WorkoutCopySheet(
    targetDate: LocalDate,
    days: List<WorkoutCopyDayUi>,
    onCopy: (LocalDate) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Copy from day", fontSize = 21.sp, fontWeight = FontWeight.ExtraBold)
                    Text(
                        "Add a previous plan to ${selectedDateTitle(targetDate)}",
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.54f),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Filled.Close, contentDescription = "Close copy picker")
                }
            }
            if (days.isEmpty()) {
                Text(
                    "No earlier workout days to copy.",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f),
                    modifier = Modifier.fillMaxWidth().padding(vertical = 38.dp),
                    fontSize = 14.sp
                )
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 460.dp),
                    verticalArrangement = Arrangement.spacedBy(9.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 24.dp)
                ) {
                    items(days, key = { it.date }) { day ->
                        FudGlassSurface(
                            modifier = Modifier.fillMaxWidth().clickable { onCopy(day.date) },
                            cornerRadius = 18.dp,
                            padding = 13.dp
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(11.dp)) {
                                Icon(Icons.Filled.EventRepeat, contentDescription = null, tint = AppColors.Calorie)
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                    Text(
                                        day.date.format(DateTimeFormatter.ofPattern("EEE, MMM d", Locale.getDefault())),
                                        color = MaterialTheme.colorScheme.onSurface,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        day.exerciseNames.take(3).joinToString().let {
                                            if (day.exerciseNames.size > 3) "$it +${day.exerciseNames.size - 3}" else it
                                        },
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.52f),
                                        fontSize = 12.sp,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                                Text(
                                    "${day.exerciseNames.size}",
                                    color = AppColors.Calorie,
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.ExtraBold
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
