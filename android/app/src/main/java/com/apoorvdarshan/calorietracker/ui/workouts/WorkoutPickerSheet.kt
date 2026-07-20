@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.apoorvdarshan.calorietracker.ui.workouts

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EventRepeat
import androidx.compose.material.icons.filled.FilterAltOff
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
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

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = MaterialTheme.colorScheme.background,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier.fillMaxSize().navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            PickerHeader(title = request.title, count = items.size, onDismiss = onDismiss)

            if (!request.isSavedContext) {
                PickerSourceControl(
                    source = source,
                    onSelect = {
                        focus.clearFocus()
                        source = it
                        onSourceChange(it)
                    },
                    modifier = Modifier.padding(horizontal = 18.dp)
                )
            }

            PickerSearchField(
                value = filter.search,
                onValueChange = { value -> updateFilter { it.copy(search = value) } },
                modifier = Modifier.padding(horizontal = 18.dp)
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 18.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                PickerFilterMenu(
                    label = "Muscle",
                    value = filter.primaryMuscle ?: "All",
                    options = listOf<String?>(null) + repository.availablePrimaryMuscles,
                    optionLabel = { it ?: "All muscles" },
                    onSelect = { value -> updateFilter { it.copy(primaryMuscle = value) } }
                )
                PickerFilterMenu(
                    label = "Equipment",
                    value = filter.equipment ?: "All",
                    options = listOf<String?>(null) + repository.availableEquipment,
                    optionLabel = { it ?: "All equipment" },
                    onSelect = { value -> updateFilter { it.copy(equipment = value) } }
                )
                PickerFilterMenu(
                    label = "Level",
                    value = filter.level ?: "All",
                    options = listOf<String?>(null) + repository.availableLevels,
                    optionLabel = { it ?: "All levels" },
                    onSelect = { value -> updateFilter { it.copy(level = value) } }
                )
                val hasFilters = filter.search.isNotEmpty() || filter.primaryMuscle != null ||
                    filter.equipment != null || filter.level != null
                if (hasFilters) {
                    Row(
                        modifier = Modifier
                            .heightIn(min = 44.dp)
                            .clip(CircleShape)
                            .background(AppColors.Calorie.copy(alpha = 0.1f))
                            .clickable {
                                focus.clearFocus()
                                updateFilter { WorkoutPickerFilterState() }
                            }
                            .padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(5.dp)
                    ) {
                        Icon(Icons.Filled.FilterAltOff, contentDescription = null, tint = AppColors.Calorie, modifier = Modifier.size(16.dp))
                        Text("Clear", color = AppColors.Calorie, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.48f))

            LazyColumn(
                modifier = Modifier.fillMaxWidth().weight(1f),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    start = 18.dp,
                    end = 18.dp,
                    bottom = 28.dp
                ),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                if (items.isEmpty()) {
                    item(key = "empty-picker") {
                        PickerEmptyState(source = source)
                    }
                } else {
                    items(items.take(120), key = { it.id }) { item ->
                        PickerExerciseRow(
                            item = item,
                            selected = item.id in selectedExerciseIds,
                            saved = item.id in savedExerciseIds,
                            onToggle = { onToggleExercise(item) },
                            onToggleSaved = { onToggleSaved(item.id) }
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
        IconButton(onClick = onDismiss) {
            Icon(Icons.Filled.Close, contentDescription = "Close exercise picker")
        }
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
private fun PickerSearchField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.38f))
            .border(0.7.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.52f), shape)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.Search, contentDescription = null, tint = AppColors.Calorie, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = TextStyle(
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            ),
            cursorBrush = SolidColor(AppColors.Calorie),
            modifier = Modifier.weight(1f),
            decorationBox = { inner ->
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) {
                        Text(
                            "Search exercises",
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    inner()
                }
            }
        )
        if (value.isNotEmpty()) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "Clear search",
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.size(19.dp).clip(CircleShape).clickable { onValueChange("") }
            )
        }
    }
}

@Composable
private fun <T> PickerFilterMenu(
    label: String,
    value: String,
    options: List<T>,
    optionLabel: (T) -> String,
    onSelect: (T) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .heightIn(min = 44.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.34f))
                .border(0.6.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f), RoundedCornerShape(16.dp))
                .clickable { expanded = true }
                .padding(horizontal = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            Column {
                Text(label.uppercase(), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.43f), fontSize = 9.sp, fontWeight = FontWeight.Bold)
                Text(value, color = MaterialTheme.colorScheme.onSurface, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1)
            }
            Icon(Icons.Filled.KeyboardArrowDown, contentDescription = null, modifier = Modifier.size(16.dp))
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.heightIn(max = 360.dp),
            containerColor = workoutsColors().card,
            shape = RoundedCornerShape(16.dp)
        ) {
            options.forEach { option ->
                val title = optionLabel(option)
                val selected = title == value ||
                    (value == "All" && title.startsWith("All ")) ||
                    (value == "All exercises" && title == "All exercises")
                DropdownMenuItem(
                    text = { Text(title, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal) },
                    onClick = {
                        onSelect(option)
                        expanded = false
                    },
                    trailingIcon = if (selected) {
                        { Icon(Icons.Filled.Check, contentDescription = null, tint = AppColors.Calorie) }
                    } else null
                )
            }
        }
    }
}

@Composable
private fun PickerExerciseRow(
    item: ExerciseItem,
    selected: Boolean,
    saved: Boolean,
    onToggle: () -> Unit,
    onToggleSaved: () -> Unit
) {
    FudGlassSurface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onToggle),
        cornerRadius = 20.dp,
        padding = 12.dp
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(
                Modifier
                    .size(68.dp)
                    .clip(RoundedCornerShape(15.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.38f))
                    .border(0.6.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f), RoundedCornerShape(15.dp))
            ) {
                AnimatedExerciseImage(item.imagePaths, Modifier.fillMaxSize())
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(
                    item.name,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    "${item.primaryMusclesTitle} · ${item.equipment}",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.52f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            IconButton(onClick = onToggleSaved, modifier = Modifier.size(38.dp)) {
                Icon(
                    if (saved) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                    contentDescription = if (saved) "Unsave exercise" else "Save exercise",
                    tint = if (saved) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    modifier = Modifier.size(20.dp)
                )
            }
            Icon(
                if (selected) Icons.Filled.CheckCircle else Icons.Filled.AddCircle,
                contentDescription = if (selected) "Remove from day" else "Add to day",
                tint = if (selected) AppColors.Calorie else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.34f),
                modifier = Modifier.size(25.dp)
            )
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
