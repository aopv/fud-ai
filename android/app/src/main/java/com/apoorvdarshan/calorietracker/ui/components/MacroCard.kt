package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.models.MacroValueFormatter
import com.apoorvdarshan.calorietracker.ui.navigation.LocalLaunchFillEpoch
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

/**
 * A single macro shown as a vertical fill bar (rounded tube that fills bottom-up toward the goal),
 * with the value above and the name + remaining/over status beneath. Port of iOS
 * `MacroVerticalBar`.
 */
@Composable
fun MacroCard(
    label: String,
    current: Double,
    goal: Int,
    unit: String = "g",
    modifier: Modifier = Modifier,
    gradientColors: List<Color> = listOf(AppColors.CalorieStart, AppColors.CalorieEnd)
) {
    val progress = if (goal > 0) (current.toFloat() / goal).coerceIn(0f, 1f) else 0f
    // Fill-from-zero on app open (see CalorieHero). Saveable lastEpoch survives tab
    // switches so only a real app-open replays the fill; tab returns snap.
    val epoch = LocalLaunchFillEpoch.current
    var lastEpoch by rememberSaveable { mutableIntStateOf(0) }
    val animatable = remember { Animatable(if (lastEpoch == epoch) progress else 0f) }
    LaunchedEffect(epoch, progress) {
        val spec = spring<Float>(dampingRatio = 0.85f, stiffness = 55f)
        if (lastEpoch != epoch) {
            animatable.snapTo(0f)
            animatable.animateTo(progress, spec)
            lastEpoch = epoch
        } else {
            animatable.animateTo(progress, spec)
        }
    }
    val animated = animatable.value
    val firstColor = gradientColors.firstOrNull() ?: AppColors.Calorie
    val goalValue = goal.toDouble()
    val statusText = when {
        goal <= 0 -> "No goal"
        current == goalValue -> "Goal reached"
        current < goalValue -> "${MacroValueFormatter.string(goalValue - current)}$unit left"
        else -> "${MacroValueFormatter.string(current - goalValue)}$unit over"
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(0.66f)
                .height(8.dp)
                .clip(CircleShape)
                .background(firstColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.CenterStart
        ) {
            Box(
                Modifier
                    .fillMaxWidth(animated)
                    .fillMaxHeight()
                    .clip(CircleShape)
                    .background(Brush.horizontalGradient(gradientColors))
            )
        }

        Text(
            MacroValueFormatter.string(current),
            style = TextStyle(
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )

        // Name + status — a tight pair (iOS groups them in an inner VStack(spacing: 1)
        // inside the outer VStack(spacing: 10)).
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(1.dp)
        ) {
            Text(
                label,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
            Text(
                statusText,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                color = if (goal > 0 && current > goal) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                },
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
        }
    }
}
