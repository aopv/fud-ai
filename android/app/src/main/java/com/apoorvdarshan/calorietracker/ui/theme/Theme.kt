package com.apoorvdarshan.calorietracker.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp

private fun lightColors(themeColor: AppThemeColor): ColorScheme {
    val accent = themeColor.start
    val accentEnd = themeColor.end
    return lightColorScheme(
        primary = themeColor.start,
        onPrimary = AppColors.contentColorFor(accent),
        primaryContainer = lerp(AppColors.CanvasLight, accent, 0.16f),
        onPrimaryContainer = AppColors.OnLight,
        secondary = accentEnd,
        onSecondary = AppColors.contentColorFor(accentEnd),
        secondaryContainer = lerp(AppColors.CanvasLight, accentEnd, 0.13f),
        onSecondaryContainer = AppColors.OnLight,
        tertiary = accent,
        onTertiary = AppColors.contentColorFor(accent),
        tertiaryContainer = lerp(AppColors.SurfaceLight, accent, 0.10f),
        onTertiaryContainer = AppColors.OnLight,
        background = AppColors.AppBackgroundLight,
        onBackground = AppColors.OnLight,
        surface = AppColors.AppCardLight,
        onSurface = AppColors.OnLight,
        surfaceVariant = AppColors.SurfaceMutedLight,
        onSurfaceVariant = AppColors.MutedLight,
        surfaceTint = Color.Transparent,
        inverseSurface = AppColors.OnLight,
        inverseOnSurface = AppColors.OnDark,
        inversePrimary = accentEnd,
        outline = AppColors.DividerLight,
        outlineVariant = AppColors.DividerLight.copy(alpha = 0.68f),
        scrim = Color.Black,
        error = AppColors.ErrorLight,
        onError = AppColors.OnErrorLight,
        errorContainer = AppColors.ErrorContainerLight,
        onErrorContainer = AppColors.OnErrorContainerLight,
        surfaceDim = AppColors.SurfaceDimLight,
        surfaceBright = AppColors.SurfaceBrightLight,
        surfaceContainerLowest = AppColors.SurfaceBrightLight,
        surfaceContainerLow = AppColors.SurfaceRaisedLight,
        surfaceContainer = AppColors.SurfaceContainerLight,
        surfaceContainerHigh = AppColors.SurfaceContainerHighLight,
        surfaceContainerHighest = AppColors.SurfaceContainerHighestLight
    )
}

private fun darkColors(themeColor: AppThemeColor): ColorScheme {
    val accent = themeColor.start
    val accentEnd = themeColor.end
    return darkColorScheme(
        primary = themeColor.start,
        onPrimary = AppColors.contentColorFor(accent),
        primaryContainer = lerp(AppColors.SurfaceDark, accent, 0.24f),
        onPrimaryContainer = AppColors.OnDark,
        secondary = accentEnd,
        onSecondary = AppColors.contentColorFor(accentEnd),
        secondaryContainer = lerp(AppColors.SurfaceDark, accentEnd, 0.21f),
        onSecondaryContainer = AppColors.OnDark,
        tertiary = accent,
        onTertiary = AppColors.contentColorFor(accent),
        tertiaryContainer = lerp(AppColors.SurfaceDark, accent, 0.18f),
        onTertiaryContainer = AppColors.OnDark,
        background = AppColors.AppBackgroundDark,
        onBackground = AppColors.OnDark,
        surface = AppColors.AppCardDark,
        onSurface = AppColors.OnDark,
        surfaceVariant = AppColors.SurfaceMutedDark,
        onSurfaceVariant = AppColors.MutedDark,
        surfaceTint = Color.Transparent,
        inverseSurface = AppColors.OnDark,
        inverseOnSurface = AppColors.OnLight,
        inversePrimary = accentEnd,
        outline = AppColors.DividerDark,
        outlineVariant = AppColors.DividerDark.copy(alpha = 0.70f),
        scrim = Color.Black,
        error = AppColors.ErrorDark,
        onError = AppColors.OnErrorDark,
        errorContainer = AppColors.ErrorContainerDark,
        onErrorContainer = AppColors.OnErrorContainerDark,
        surfaceDim = AppColors.CanvasDark,
        surfaceBright = AppColors.SurfaceBrightDark,
        surfaceContainerLowest = AppColors.SurfaceLowestDark,
        surfaceContainerLow = AppColors.SurfaceLowDark,
        surfaceContainer = AppColors.SurfaceDark,
        surfaceContainerHigh = AppColors.SurfaceRaisedDark,
        surfaceContainerHighest = AppColors.SurfaceMutedDark
    )
}

@Composable
fun FudAITheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    themeColor: AppThemeColor = AppThemeColor.FUD_PINK,
    content: @Composable () -> Unit
) {
    AppColors.setThemeColor(themeColor)
    val colorScheme = if (darkTheme) darkColors(themeColor) else lightColors(themeColor)
    val semanticColors = fudSemanticColors(themeColor = themeColor, isDark = darkTheme)
    CompositionLocalProvider(LocalFudColors provides semanticColors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            shapes = FudShapes,
            content = content
        )
    }
}
