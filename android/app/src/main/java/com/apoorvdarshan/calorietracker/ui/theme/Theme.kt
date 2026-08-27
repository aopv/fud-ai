package com.apoorvdarshan.calorietracker.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

private fun lightColors(themeColor: AppThemeColor) = lightColorScheme(
    primary = AppColors.KitchenTomato,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFF4C8B7),
    onPrimaryContainer = AppColors.KitchenEspresso,
    secondary = AppColors.KitchenCobalt,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFDCE5F8),
    onSecondaryContainer = AppColors.KitchenEspresso,
    tertiary = AppColors.KitchenHerb,
    onTertiary = AppColors.OnDark,
    tertiaryContainer = Color(0xFFDCE8D9),
    onTertiaryContainer = AppColors.KitchenEspresso,
    background = AppColors.AppBackgroundLight,
    onBackground = AppColors.OnLight,
    surface = AppColors.AppCardLight,
    onSurface = AppColors.OnLight,
    surfaceVariant = Color(0xFFF0E2CC),
    onSurfaceVariant = AppColors.MutedLight,
    surfaceContainer = Color(0xFFF7ECD9),
    surfaceContainerHigh = Color(0xFFFFF9ED),
    surfaceContainerHighest = AppColors.KitchenPaper,
    outline = Color(0xFFBDA98F),
    outlineVariant = AppColors.DividerLight
)

private fun darkColors(themeColor: AppThemeColor) = darkColorScheme(
    primary = AppColors.KitchenTomato,
    onPrimary = AppColors.KitchenRoast,
    primaryContainer = Color(0xFF71372C),
    onPrimaryContainer = AppColors.OnDark,
    secondary = AppColors.KitchenCobalt,
    onSecondary = AppColors.KitchenRoast,
    secondaryContainer = Color(0xFF263B68),
    onSecondaryContainer = AppColors.OnDark,
    tertiary = AppColors.KitchenHerb,
    onTertiary = AppColors.KitchenRoast,
    tertiaryContainer = Color(0xFF304533),
    onTertiaryContainer = AppColors.OnDark,
    background = AppColors.AppBackgroundDark,
    onBackground = AppColors.OnDark,
    surface = AppColors.AppCardDark,
    onSurface = AppColors.OnDark,
    surfaceVariant = Color(0xFF352A25),
    onSurfaceVariant = AppColors.MutedDark,
    surfaceContainer = Color(0xFF251C19),
    surfaceContainerHigh = Color(0xFF30251F),
    surfaceContainerHighest = Color(0xFF382B25),
    outline = Color(0xFF806D60),
    outlineVariant = AppColors.DividerDark
)

private val KitchenShapes = Shapes(
    extraSmall = RoundedCornerShape(2.dp),
    small = RoundedCornerShape(4.dp),
    medium = RoundedCornerShape(6.dp),
    large = RoundedCornerShape(10.dp),
    extraLarge = RoundedCornerShape(14.dp)
)

@Composable
fun FudAITheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    themeColor: AppThemeColor = AppThemeColor.FUD_PINK,
    content: @Composable () -> Unit
) {
    AppColors.setThemeColor(themeColor)
    AppColors.setDarkTheme(darkTheme)
    val colorScheme = if (darkTheme) darkColors(themeColor) else lightColors(themeColor)
    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = KitchenShapes,
        content = content
    )
}
