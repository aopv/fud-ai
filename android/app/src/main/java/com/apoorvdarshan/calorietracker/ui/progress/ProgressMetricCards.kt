package com.apoorvdarshan.calorietracker.ui.progress

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ListAlt
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.HeartRateEntry
import com.apoorvdarshan.calorietracker.models.HeartRateSource
import com.apoorvdarshan.calorietracker.models.WorkoutSession
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialog
import com.apoorvdarshan.calorietracker.ui.components.FudGlassDialogActions
import com.apoorvdarshan.calorietracker.ui.components.FudGlassSurface
import com.apoorvdarshan.calorietracker.ui.components.FudGlassTextButton
import com.apoorvdarshan.calorietracker.ui.components.FudIconBubble
import com.apoorvdarshan.calorietracker.ui.theme.AppColors
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlin.math.roundToInt

@Composable
internal fun WorkoutProgressSection(entries: List<WorkoutSession>) {
    val dailyBurns = remember(entries) { preferredDailyWorkoutBurns(entries) }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            stringResource(R.string.progress_workout_section),
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold
        )
        if (dailyBurns.isEmpty()) {
            ProgressEmptyText(stringResource(R.string.progress_workout_no_range))
        } else {
            val total = dailyBurns.sumOf(Pair<LocalDate, Int>::second)
            ProgressStatRow(
                listOf(
                    stringResource(R.string.progress_workout_stat_total) to
                        stringResource(R.string.kcal_value_format, total),
                    stringResource(R.string.progress_workout_stat_average) to
                        stringResource(
                            R.string.kcal_value_format,
                            dailyBurns.map(Pair<LocalDate, Int>::second).average().roundToInt()
                        ),
                    stringResource(R.string.progress_workout_stat_latest) to
                        stringResource(R.string.kcal_value_format, dailyBurns.last().second),
                    stringResource(R.string.progress_workout_stat_days) to dailyBurns.size.toString()
                )
            )
            WorkoutBurnChart(dailyBurns)
        }
    }
}

/**
 * Chooses one reliable calculated-burn snapshot per day. Local/Health Connect restore races can
 * briefly leave duplicate snapshots; the higher sync version wins, then the later completion.
 */
internal fun preferredDailyWorkoutBurns(entries: List<WorkoutSession>): List<Pair<LocalDate, Int>> =
    entries.mapNotNull { session ->
        val date = runCatching { LocalDate.parse(session.diaryDateKey) }.getOrNull()
        val calories = session.caloriesBurned?.takeIf { it in 1..5_000 }
        if (date == null || calories == null) null else date to session
    }.groupBy(Pair<LocalDate, WorkoutSession>::first)
        .mapNotNull { (date, values) ->
            values.map(Pair<LocalDate, WorkoutSession>::second)
                .maxWithOrNull(preferredWorkoutBurnComparator)
                ?.caloriesBurned
                ?.let { date to it }
        }
        .sortedBy(Pair<LocalDate, Int>::first)

private val preferredWorkoutBurnComparator =
    compareBy<WorkoutSession> { it.healthSyncVersion ?: 0 }
        .thenBy(WorkoutSession::completedAt)

@Composable
internal fun HeartRateProgressSection(
    entries: List<HeartRateEntry>,
    onMeasure: () -> Unit,
    onLogManual: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            stringResource(R.string.progress_heart_rate_section),
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold
        )
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            FudGlassTextButton(
                text = stringResource(R.string.progress_heart_rate_measure),
                onClick = onMeasure,
                modifier = Modifier.weight(1f).heightIn(min = 48.dp)
            )
            FudGlassTextButton(
                text = stringResource(R.string.progress_heart_rate_log_manual),
                onClick = onLogManual,
                modifier = Modifier.weight(1f).heightIn(min = 48.dp),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.78f)
            )
        }
        if (entries.isEmpty()) {
            ProgressEmptyText(stringResource(R.string.progress_heart_rate_no_range))
        } else {
            val bpms = entries.map(HeartRateEntry::bpm)
            ProgressStatRow(
                listOf(
                    stringResource(R.string.progress_heart_rate_stat_latest) to
                        stringResource(R.string.progress_bpm_format, entries.maxBy(HeartRateEntry::date).bpm),
                    stringResource(R.string.progress_stat_average) to
                        stringResource(R.string.progress_bpm_format, bpms.average().roundToInt()),
                    stringResource(R.string.progress_heart_rate_stat_min) to
                        stringResource(R.string.progress_bpm_format, bpms.min()),
                    stringResource(R.string.progress_heart_rate_stat_max) to
                        stringResource(R.string.progress_bpm_format, bpms.max())
                )
            )
            HeartRateChart(entries)
        }
        Text(
            stringResource(R.string.progress_heart_rate_disclaimer),
            fontSize = 12.sp,
            lineHeight = 17.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
        )
    }
}

@Composable
private fun ProgressEmptyText(text: String) {
    Box(
        Modifier.fillMaxWidth().padding(vertical = 24.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text,
            fontSize = 15.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
        )
    }
}

@Composable
private fun ProgressStatRow(items: List<Pair<String, String>>) {
    val useTwoRows = shouldUseTwoRowProgressStats(LocalDensity.current.fontScale)
    val rows = if (useTwoRows) items.chunked(2) else listOf(items)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        rows.forEach { rowItems ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                rowItems.forEach { (label, value) ->
                    ProgressStatItem(
                        label = label,
                        value = value,
                        allowLabelWrap = useTwoRows,
                        modifier = Modifier.weight(1f)
                    )
                }
                repeat((if (useTwoRows) 2 else items.size) - rowItems.size) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

internal fun shouldUseTwoRowProgressStats(fontScale: Float): Boolean = fontScale >= 1.2f

@Composable
private fun ProgressStatItem(
    label: String,
    value: String,
    allowLabelWrap: Boolean,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.clip(RoundedCornerShape(10.dp))
            .background(AppColors.Calorie.copy(alpha = 0.055f))
            .padding(horizontal = 4.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(
            value,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center
        )
        Text(
            label,
            maxLines = if (allowLabelWrap) 2 else 1,
            overflow = TextOverflow.Ellipsis,
            fontSize = 10.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun WorkoutBurnChart(values: List<Pair<LocalDate, Int>>) {
    val maxValue = values.maxOf(Pair<LocalDate, Int>::second).coerceAtLeast(1).toFloat()
    val grid = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.09f)
    val secondary = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
    val dateFormatter = remember {
        DateTimeFormatter.ofLocalizedDate(FormatStyle.SHORT).withLocale(Locale.getDefault())
    }
    val chartDescription = stringResource(
        R.string.progress_workout_chart_description,
        dateFormatter.format(values.first().first),
        dateFormatter.format(values.last().first),
        values.sumOf(Pair<LocalDate, Int>::second),
        values.last().second
    )
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(
            Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(10.dp))
                .background(AppColors.Calorie.copy(alpha = 0.025f))
                .semantics { contentDescription = chartDescription }
        ) {
            repeat(5) { index ->
                val y = size.height * index / 4f
                drawLine(grid, Offset(0f, y), Offset(size.width, y), strokeWidth = 1f)
            }
            val slots = values.size.coerceAtLeast(1)
            val slotWidth = size.width / slots
            val barWidth = (slotWidth * 0.58f).coerceAtMost(48.dp.toPx()).coerceAtLeast(3f)
            values.forEachIndexed { index, (_, calories) ->
                val height = size.height * calories / maxValue
                val left = slotWidth * index + (slotWidth - barWidth) / 2f
                drawRoundRect(
                    brush = Brush.verticalGradient(listOf(AppColors.CalorieEnd, AppColors.CalorieStart)),
                    topLeft = Offset(left, size.height - height),
                    size = Size(barWidth, height),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(8f, 8f)
                )
            }
        }
        Row(Modifier.fillMaxWidth()) {
            Text(dateFormatter.format(values.first().first), fontSize = 11.sp, color = secondary)
            Spacer(Modifier.weight(1f))
            if (values.size > 1) {
                Text(dateFormatter.format(values.last().first), fontSize = 11.sp, color = secondary)
            }
        }
    }
}

@Composable
private fun HeartRateChart(entries: List<HeartRateEntry>) {
    val sorted = remember(entries) { entries.sortedBy(HeartRateEntry::date) }
    val min = (sorted.minOf(HeartRateEntry::bpm) - 8).coerceAtLeast(HeartRateEntry.MIN_PLAUSIBLE_BPM)
    val max = (sorted.maxOf(HeartRateEntry::bpm) + 8).coerceAtMost(HeartRateEntry.MAX_PLAUSIBLE_BPM)
    val span = (max - min).coerceAtLeast(1)
    val start = sorted.first().date.toEpochMilli()
    val end = sorted.last().date.toEpochMilli()
    val timeSpan = (end - start).coerceAtLeast(1L)
    val grid = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.09f)
    val secondary = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
    val zone = remember { ZoneId.systemDefault() }
    val showTimes = remember(sorted.first().date, sorted.last().date, zone) {
        shouldUseHeartRateTimeLabels(sorted.first().date, sorted.last().date, zone)
    }
    val dateFormatter = remember(zone) {
        DateTimeFormatter.ofLocalizedDate(FormatStyle.SHORT)
            .withLocale(Locale.getDefault())
            .withZone(zone)
    }
    val timeFormatter = remember(zone) {
        DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
            .withLocale(Locale.getDefault())
            .withZone(zone)
    }
    val accessibilityFormatter = remember(showTimes, zone) {
        if (showTimes) {
            DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
                .withLocale(Locale.getDefault())
                .withZone(zone)
        } else {
            dateFormatter
        }
    }
    val visualFormatter = if (showTimes) timeFormatter else dateFormatter
    val chartDescription = stringResource(
        R.string.progress_heart_rate_chart_description,
        accessibilityFormatter.format(sorted.first().date),
        accessibilityFormatter.format(sorted.last().date),
        sorted.maxBy(HeartRateEntry::date).bpm,
        sorted.minOf(HeartRateEntry::bpm),
        sorted.maxOf(HeartRateEntry::bpm)
    )
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(Modifier.fillMaxWidth().height(180.dp)) {
            Canvas(
                Modifier.weight(1f).fillMaxSize().clip(RoundedCornerShape(10.dp))
                    .background(AppColors.Calorie.copy(alpha = 0.025f))
                    .semantics { contentDescription = chartDescription }
            ) {
                repeat(5) { index ->
                    val y = size.height * index / 4f
                    drawLine(grid, Offset(0f, y), Offset(size.width, y), strokeWidth = 1f)
                }
                val points = sorted.map { entry ->
                    val x = if (sorted.size == 1) size.width / 2f
                        else ((entry.date.toEpochMilli() - start).toDouble() / timeSpan * size.width).toFloat()
                    val y = size.height - ((entry.bpm - min).toFloat() / span * size.height)
                    Offset(x, y)
                }
                if (points.size > 1) {
                    val path = Path().apply {
                        moveTo(points.first().x, points.first().y)
                        points.drop(1).forEach { lineTo(it.x, it.y) }
                    }
                    drawPath(path, AppColors.Calorie, style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4f))
                }
                points.forEach { point -> drawCircle(AppColors.Calorie, radius = 5f, center = point) }
            }
            Column(
                Modifier.width(40.dp).fillMaxSize().padding(start = 5.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Text(max.toString(), fontSize = 11.sp, color = secondary)
                Text(((max + min) / 2).toString(), fontSize = 11.sp, color = secondary)
                Text(min.toString(), fontSize = 11.sp, color = secondary)
            }
        }
        Row(Modifier.fillMaxWidth().padding(end = 40.dp)) {
            Text(visualFormatter.format(sorted.first().date), fontSize = 11.sp, color = secondary)
            Spacer(Modifier.weight(1f))
            if (sorted.size > 1) {
                Text(visualFormatter.format(sorted.last().date), fontSize = 11.sp, color = secondary)
            }
        }
    }
}

internal fun shouldUseHeartRateTimeLabels(first: Instant, last: Instant, zone: ZoneId): Boolean =
    first.atZone(zone).toLocalDate() == last.atZone(zone).toLocalDate()

@Composable
internal fun HeartRateHistoryLink(count: Int, onClick: () -> Unit) {
    FudGlassSurface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        cornerRadius = 18.dp,
        padding = 14.dp
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            FudIconBubble(Icons.AutoMirrored.Filled.ListAlt, size = 28.dp, iconSize = 16.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    stringResource(R.string.progress_heart_rate_history),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    pluralStringResource(
                        R.plurals.progress_history_count_format,
                        count,
                        count
                    ),
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                )
            }
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

@Composable
internal fun ManualHeartRateDialog(
    value: String,
    onValueChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onSave: (Int) -> Unit
) {
    val bpm = value.toIntOrNull()
    val valid = bpm in HeartRateEntry.MIN_PLAUSIBLE_BPM..HeartRateEntry.MAX_PLAUSIBLE_BPM
    FudGlassDialog(onDismissRequest = onDismiss) {
        Text(
            stringResource(R.string.progress_heart_rate_manual_title),
            fontSize = 21.sp,
            fontWeight = FontWeight.Bold
        )
        OutlinedTextField(
            value = value,
            onValueChange = { next ->
                if (next.length <= 3 && next.all(Char::isDigit)) onValueChange(next)
            },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.progress_heart_rate_bpm_label)) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            supportingText = { Text(stringResource(R.string.progress_heart_rate_manual_range)) }
        )
        FudGlassDialogActions(
            primaryText = stringResource(R.string.action_save),
            onPrimary = { bpm?.let(onSave) },
            primaryEnabled = valid,
            dismissText = stringResource(R.string.action_cancel),
            onDismiss = onDismiss
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AllHeartRateHistorySheet(
    entries: List<HeartRateEntry>,
    onDelete: (HeartRateEntry) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val listState = rememberLazyListState()
    var pendingDelete by remember { mutableStateOf<HeartRateEntry?>(null) }
    val formatter = remember {
        DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
            .withLocale(Locale.getDefault()).withZone(ZoneId.systemDefault())
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = state) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.progress_heart_rate_history),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.action_done), color = AppColors.Calorie)
                }
            }
            Spacer(Modifier.height(12.dp))
            FudGlassSurface(Modifier.fillMaxWidth(), cornerRadius = 22.dp, padding = 0.dp) {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 560.dp).padding(vertical = 4.dp),
                    state = listState
                ) {
                    items(entries.sortedByDescending(HeartRateEntry::date), key = HeartRateEntry::id) { entry ->
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            FudIconBubble(Icons.Filled.Favorite, size = 34.dp, iconSize = 18.dp)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    stringResource(R.string.progress_bpm_format, entry.bpm),
                                    fontSize = 17.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                                val source = when (entry.source) {
                                    HeartRateSource.CAMERA -> stringResource(R.string.progress_heart_rate_source_camera)
                                    HeartRateSource.MANUAL -> stringResource(R.string.progress_heart_rate_source_manual)
                                }
                                Text(
                                    stringResource(
                                        R.string.progress_heart_rate_history_detail,
                                        source,
                                        formatter.format(entry.date)
                                    ),
                                    fontSize = 13.sp,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                                )
                                entry.quality?.let { quality ->
                                    Text(
                                        stringResource(
                                            R.string.progress_heart_rate_quality_format,
                                            (quality * 100).roundToInt()
                                        ),
                                        fontSize = 12.sp,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.48f)
                                    )
                                }
                            }
                            IconButton(onClick = { pendingDelete = entry }) {
                                Icon(
                                    Icons.Filled.Delete,
                                    contentDescription = stringResource(R.string.action_delete),
                                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.42f)
                                )
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    pendingDelete?.let { entry ->
        FudGlassDialog(onDismissRequest = { pendingDelete = null }) {
            Text(
                stringResource(R.string.progress_heart_rate_delete_title),
                fontSize = 21.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(8.dp))
            Text(
                stringResource(
                    R.string.progress_heart_rate_delete_message,
                    entry.bpm,
                    formatter.format(entry.date)
                ),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.72f)
            )
            FudGlassDialogActions(
                primaryText = stringResource(R.string.action_delete),
                onPrimary = {
                    onDelete(entry)
                    pendingDelete = null
                },
                dismissText = stringResource(R.string.action_cancel),
                onDismiss = { pendingDelete = null },
                destructive = true
            )
        }
    }
}
