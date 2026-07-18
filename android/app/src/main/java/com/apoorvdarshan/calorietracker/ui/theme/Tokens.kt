package com.apoorvdarshan.calorietracker.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.dp

/**
 * Compact visual tokens shared by the Android UI.
 *
 * Keeping these values named prevents each screen from inventing a slightly
 * different version of the same warm, rounded Fud AI surface.
 */
object FudSpacing {
    val hairline = 1.dp
    val compact = 6.dp
    val small = 8.dp
    val medium = 12.dp
    val regular = 16.dp
    val large = 20.dp
    val extraLarge = 24.dp
}

object FudRadii {
    val compact = 10.dp
    val small = 14.dp
    val medium = 18.dp
    val large = 20.dp
    val extraLarge = 24.dp
    val sheet = 28.dp
}

object FudElevation {
    val resting = 6.dp
    val raised = 10.dp
    val floating = 16.dp
}

object FudSizing {
    /** Android's recommended minimum interactive target. */
    val minimumTouchTarget = 48.dp
    val controlHeight = 52.dp
}

val FudShapes = Shapes(
    extraSmall = RoundedCornerShape(FudRadii.compact),
    small = RoundedCornerShape(FudRadii.small),
    medium = RoundedCornerShape(FudRadii.medium),
    large = RoundedCornerShape(FudRadii.extraLarge),
    extraLarge = RoundedCornerShape(FudRadii.sheet)
)

internal val LocalFudColors = staticCompositionLocalOf {
    fudSemanticColors(themeColor = AppThemeColor.FUD_PINK, isDark = false)
}

/** Additional app-specific tokens that Material's ColorScheme does not express. */
object FudTheme {
    val colors: FudSemanticColors
        @Composable
        @ReadOnlyComposable
        get() = LocalFudColors.current

    val shapes: Shapes
        get() = FudShapes
}
