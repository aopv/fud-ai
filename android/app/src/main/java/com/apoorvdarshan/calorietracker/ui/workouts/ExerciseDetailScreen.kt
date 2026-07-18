package com.apoorvdarshan.calorietracker.ui.workouts

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.FormatListNumbered
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.ui.navigation.BottomNavScrollPadding
import com.apoorvdarshan.calorietracker.data.ExerciseItem
import com.apoorvdarshan.calorietracker.ui.workouts.AnimatedExerciseImage

private val HERO_HEIGHT = 294.dp

@Composable
fun ExerciseDetailScreen(item: ExerciseItem, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val colors = workoutsColors()
    var showMetrics by remember { mutableStateOf(false) }

    Column(modifier.fillMaxSize().background(colors.background).statusBarsPadding()) {
        // Top bar: back (start) + centered title
        Box(
            Modifier.fillMaxWidth().background(colors.background).padding(vertical = 8.dp, horizontal = 8.dp),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .size(48.dp)
                    .clickable { onBack() },
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(colors.card)
                        .border(0.7.dp, colors.hairline, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.back),
                        tint = colors.accent,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
            Text(
                item.name,
                color = colors.charcoal,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 52.dp)
            )
        }

        // Pinned hero over scrollable instructions (mirrors the iOS ZStack).
        Box(Modifier.fillMaxSize()) {
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = BottomNavScrollPadding)
            ) {
                item(key = "herospace") { Spacer(Modifier.height(HERO_HEIGHT)) }
                item(key = "instructions") {
                    InstructionSection(item.instructions, Modifier.padding(horizontal = 20.dp, vertical = 24.dp))
                }
                item(key = "pad") { Spacer(Modifier.size(40.dp)) }
            }

            Hero(item = item, showMetrics = showMetrics, onToggle = { showMetrics = !showMetrics })
        }
    }
}

@Composable
private fun Hero(item: ExerciseItem, showMetrics: Boolean, onToggle: () -> Unit) {
    val colors = workoutsColors()
    val heroShape = RoundedCornerShape(20.dp)
    Box(
        Modifier
            .fillMaxWidth()
            .height(HERO_HEIGHT)
            .shadow(
                elevation = 6.dp,
                shape = heroShape,
                ambientColor = Color.Black.copy(alpha = if (colors.isDark) 0.28f else 0.10f),
                spotColor = Color.Black.copy(alpha = if (colors.isDark) 0.28f else 0.10f)
            )
            .clip(heroShape)
            .background(colors.panel)
            .border(0.8.dp, colors.hairline, heroShape)
    ) {
        AnimatedExerciseImage(item.imagePaths, Modifier.fillMaxSize(), fallbackLabel = item.name)

        AnimatedVisibility(
            visible = showMetrics,
            modifier = Modifier.matchParentSize(),
            enter = fadeIn(tween(280)),
            exit = fadeOut(tween(280))
        ) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)))
        }

        AnimatedVisibility(
            visible = showMetrics,
            modifier = Modifier.align(Alignment.TopStart),
            enter = slideInHorizontally(tween(280)) { it } + fadeIn(tween(280)),
            exit = slideOutHorizontally(tween(280)) { it } + fadeOut(tween(280))
        ) {
            MetricGrid(item, Modifier.padding(start = 24.dp, top = 8.dp, end = 84.dp))
        }

        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(12.dp)
                .size(48.dp)
                .clickable { onToggle() },
            contentAlignment = Alignment.Center
        ) {
            Box(
                Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(colors.card.copy(alpha = 0.94f))
                .border(0.8.dp, colors.hairline, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Filled.Info,
                    contentDescription = stringResource(if (showMetrics) R.string.hide_details else R.string.show_details),
                    tint = colors.accent,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

@Composable
private fun MetricGrid(item: ExerciseItem, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MetricCard(stringResource(R.string.label_level), item.level, Icons.Filled.BarChart, 1, 15.sp, Modifier.weight(1f))
            MetricCard(stringResource(R.string.label_category), item.category, Icons.Filled.Tag, 1, 15.sp, Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MetricCard(stringResource(R.string.label_force), item.force, Icons.Filled.SwapHoriz, 1, 15.sp, Modifier.weight(1f))
            MetricCard(stringResource(R.string.label_mechanic), item.mechanic, Icons.Filled.Settings, 1, 15.sp, Modifier.weight(1f))
        }
        MetricCard(stringResource(R.string.label_primary), item.primaryMusclesTitle, Icons.Filled.GpsFixed, 2, 14.sp, Modifier.fillMaxWidth())
        MetricCard(stringResource(R.string.label_secondary), item.secondaryMusclesTitle, Icons.Filled.GpsFixed, 3, 13.sp, Modifier.fillMaxWidth())
        MetricCard(stringResource(R.string.label_equipment), item.equipment, Icons.Filled.FitnessCenter, 2, 14.sp, Modifier.fillMaxWidth())
    }
}

@Composable
private fun MetricCard(title: String, value: String, icon: ImageVector, valueMaxLines: Int, valueSize: androidx.compose.ui.unit.TextUnit, modifier: Modifier = Modifier) {
    val colors = workoutsColors()
    val labelColor = colors.accent
    val fill = colors.card.copy(alpha = if (colors.isDark) 0.90f else 0.94f)
    val cardShape = RoundedCornerShape(14.dp)
    Column(
        modifier
            .shadow(
                elevation = 4.dp,
                shape = cardShape,
                ambientColor = Color.Black.copy(alpha = if (colors.isDark) 0.25f else 0.08f),
                spotColor = Color.Black.copy(alpha = if (colors.isDark) 0.25f else 0.08f)
            )
            .clip(cardShape)
            .background(fill)
            .border(0.7.dp, colors.hairline, cardShape)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(icon, null, tint = labelColor, modifier = Modifier.size(11.dp))
            Text(
                title,
                color = labelColor,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1
            )
        }
        Text(
            value,
            color = colors.charcoal,
            fontSize = valueSize,
            fontWeight = FontWeight.SemiBold,
            maxLines = valueMaxLines,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun InstructionSection(instructions: List<String>, modifier: Modifier = Modifier) {
    val colors = workoutsColors()
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(colors.accent.copy(alpha = 0.12f))
                    .border(0.6.dp, colors.accent.copy(alpha = 0.18f), RoundedCornerShape(10.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.FormatListNumbered, null, tint = colors.accent, modifier = Modifier.size(18.dp))
            }
            Text(
                stringResource(R.string.instructions),
                color = colors.charcoal,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.weight(1f))
            Box(
                Modifier.clip(CircleShape).background(colors.secondaryAccent.copy(alpha = 0.12f)).padding(horizontal = 9.dp, vertical = 4.dp)
            ) {
                Text(
                    "${instructions.size}",
                    color = colors.secondaryAccent,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            instructions.forEachIndexed { index, instruction ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(colors.card)
                        .background(colors.accent.copy(alpha = 0.018f))
                        .border(0.7.dp, colors.hairline, RoundedCornerShape(18.dp))
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(13.dp)
                ) {
                    Box(
                        Modifier
                            .size(28.dp)
                            .shadow(5.dp, CircleShape, clip = false)
                            .clip(CircleShape)
                            .background(colors.accent),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "${index + 1}",
                            color = colors.onAccent,
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Text(
                        instruction,
                        color = colors.charcoal,
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}
