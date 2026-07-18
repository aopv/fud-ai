package com.apoorvdarshan.calorietracker.ui.workouts

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

/**
 * Workouts theme bridge — the exercise library is ported from Delts
 * (github.com/apoorvdarshan/delts), whose screens read a small resolved palette
 * (`LocalDeltsColors.current`). This file re-implements that exact field surface
 * on top of Fud AI's theme (AppColors + the user-selectable accent), so the ported
 * screens render with Fud AI's default look while keeping their code unchanged.
 */
data class WorkoutsColors(
    val background: Color,
    val charcoal: Color,
    val card: Color,
    val panel: Color,
    val hairline: Color,
    val accent: Color,
    val secondaryAccent: Color,
    val onAccent: Color,
    val mutedText: Color,
    val isDark: Boolean
)

@Composable
fun workoutsColors(): WorkoutsColors {
    val scheme = MaterialTheme.colorScheme
    val isDark = scheme.background.luminance() < 0.5f

    return WorkoutsColors(
        background = scheme.background,
        charcoal = scheme.onSurface,
        card = scheme.surfaceContainerLow,
        panel = scheme.surfaceContainerHigh,
        hairline = scheme.outlineVariant,
        accent = AppColors.Calorie,
        secondaryAccent = scheme.secondary,
        onAccent = AppColors.OnAccent,
        mutedText = scheme.onSurfaceVariant,
        isDark = isDark
    )
}
