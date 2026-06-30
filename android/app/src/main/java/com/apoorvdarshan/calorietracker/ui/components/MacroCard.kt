package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.models.MacroValueFormatter
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

/**
 * A single macro shown as a vertical fill bar (rounded tube that fills bottom-up toward the goal),
 * with the value above and the name + goal beneath. Port of iOS `MacroVerticalBar`.
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
    val animated by animateFloatAsState(
        targetValue = progress,
        animationSpec = spring(dampingRatio = 0.78f, stiffness = 60f),
        label = "macroFill"
    )
    val firstColor = gradientColors.firstOrNull() ?: AppColors.Calorie

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Value (gradient), above the bar
        Text(
            MacroValueFormatter.string(current),
            style = TextStyle(
                brush = Brush.verticalGradient(gradientColors),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )

        // Vertical fill bar (rounded tube, fills bottom-up)
        Box(
            modifier = Modifier.size(width = 16.dp, height = 74.dp),
            contentAlignment = Alignment.BottomCenter
        ) {
            Box(
                Modifier
                    .fillMaxSize()
                    .clip(CircleShape)
                    .background(firstColor.copy(alpha = 0.12f))
            )
            val fillHeight = (74.dp * animated).coerceAtLeast(16.dp)
            Box(
                Modifier
                    .width(16.dp)
                    .height(fillHeight)
                    .shadow(
                        elevation = 5.dp,
                        shape = CircleShape,
                        ambientColor = firstColor.copy(alpha = 0.4f),
                        spotColor = firstColor.copy(alpha = 0.4f)
                    )
                    .clip(CircleShape)
                    .background(Brush.verticalGradient(gradientColors))
            )
        }

        // Name
        Text(
            label,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f),
            maxLines = 1
        )
        // Goal
        Text(
            "/$goal$unit",
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f),
            maxLines = 1
        )
    }
}
