package com.apoorvdarshan.calorietracker.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private fun lightColors(themeColor: AppThemeColor) = lightColorScheme(
    primary = AppColors.NeoCobalt,
    onPrimary = AppColors.OnDark,
    secondary = AppColors.NeoAcid,
    onSecondary = AppColors.NeoInk,
    tertiary = AppColors.NeoCobalt,
    onTertiary = AppColors.OnDark,
    background = AppColors.AppBackgroundLight,
    onBackground = AppColors.OnLight,
    surface = AppColors.AppCardLight,
    onSurface = AppColors.OnLight,
    surfaceVariant = AppColors.AppCardLight,
    onSurfaceVariant = AppColors.MutedLight,
    outline = AppColors.DividerLight
)

private fun darkColors(themeColor: AppThemeColor) = darkColorScheme(
    primary = AppColors.NeoCobalt,
    onPrimary = AppColors.OnDark,
    secondary = AppColors.NeoAcid,
    onSecondary = AppColors.NeoInk,
    tertiary = AppColors.NeoCobalt,
    onTertiary = AppColors.OnDark,
    background = AppColors.AppBackgroundDark,
    onBackground = AppColors.OnDark,
    surface = AppColors.AppCardDark,
    onSurface = AppColors.OnDark,
    surfaceVariant = AppColors.AppCardDark,
    onSurfaceVariant = AppColors.MutedDark,
    outline = AppColors.DividerDark
)

@Composable
fun FudAITheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    themeColor: AppThemeColor = AppThemeColor.FUD_PINK,
    content: @Composable () -> Unit
) {
    AppColors.setThemeColor(themeColor)
    val colorScheme = if (darkTheme) darkColors(themeColor) else lightColors(themeColor)
    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
