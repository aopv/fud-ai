package com.apoorvdarshan.calorietracker.ui.theme

import androidx.annotation.StringRes
import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.apoorvdarshan.calorietracker.R

enum class AppThemeColor(
    val key: String,
    @param:StringRes val displayNameRes: Int,
    val start: Color,
    val end: Color
) {
    FUD_PINK("fudPink", R.string.theme_color_fud_pink, Color(0xFFFF375F), Color(0xFFFF6B8A)),
    RED("red", R.string.theme_color_red, Color(0xFFFF3B30), Color(0xFFFF6961)),
    ORANGE("orange", R.string.theme_color_orange, Color(0xFFFF9500), Color(0xFFFFB340)),
    GREEN("green", R.string.theme_color_green, Color(0xFF34C759), Color(0xFF62D46F)),
    MINT("mint", R.string.theme_color_mint, Color(0xFF00C7BE), Color(0xFF66D4CF)),
    TEAL("teal", R.string.theme_color_teal, Color(0xFF30B0C7), Color(0xFF64D2FF)),
    BLUE("blue", R.string.theme_color_blue, Color(0xFF0A84FF), Color(0xFF5EAEFF)),
    PURPLE("purple", R.string.theme_color_purple, Color(0xFFAF52DE), Color(0xFFBF5AF2)),
    YELLOW("yellow", R.string.theme_color_yellow, Color(0xFFFFCC00), Color(0xFFFFD60A)),
    CORAL("coral", R.string.theme_color_coral, Color(0xFFFF7F50), Color(0xFFFFA382)),
    ROSE_GOLD("roseGold", R.string.theme_color_rose_gold, Color(0xFFC9807C), Color(0xFFE8B4B0)),
    MOCHA_BROWN("mochaBrown", R.string.theme_color_mocha_brown, Color(0xFFA2845E), Color(0xFFC9A57E)),
    INDIGO("indigo", R.string.theme_color_indigo, Color(0xFF5856D6), Color(0xFF7D7AFF)),
    LAVENDER("lavender", R.string.theme_color_lavender, Color(0xFFB57EDC), Color(0xFFD0A9F5)),
    SKY_CYAN("skyCyan", R.string.theme_color_sky_cyan, Color(0xFF32ADE6), Color(0xFF70CFFF)),
    GRAPHITE("graphite", R.string.theme_color_graphite, Color(0xFF8E8E93), Color(0xFFB8B8BE)),
    BABY_PINK("babyPink", R.string.theme_color_baby_pink, Color(0xFFFF8FAB), Color(0xFFFFB3C6)),
    LIME("lime", R.string.theme_color_lime, Color(0xFFA0D911), Color(0xFFC3E956));

    companion object {
        const val DEFAULT_KEY = "fudPink"

        fun fromKey(key: String?): AppThemeColor =
            values().firstOrNull { it.key == key } ?: FUD_PINK
    }
}

object AppColors {
    private var activeThemeColor: AppThemeColor = AppThemeColor.FUD_PINK

    fun setThemeColor(themeColor: AppThemeColor) {
        activeThemeColor = themeColor
    }

    val ThemeColor: AppThemeColor
        get() = activeThemeColor

    val CalorieStart: Color
        get() = activeThemeColor.start

    val CalorieEnd: Color
        get() = activeThemeColor.end

    val Calorie: Color
        get() = CalorieStart

    val Protein: Color
        get() = CalorieStart

    val Carbs: Color
        get() = CalorieStart

    val Fat: Color
        get() = CalorieStart

    val CalorieGradient: Brush
        get() = Brush.linearGradient(listOf(CalorieStart, CalorieEnd))

    // Core canvas and surface palette. The light colors intentionally retain
    // Fud AI's warm, food-adjacent paper tint; dark surfaces stay neutral so
    // user-selected accent colors remain clear.
    val CanvasLight = Color(0xFFF3ECE6)
    val CanvasDark = Color(0xFF0C0C0C)

    val SurfaceLight = Color(0xFFFFFFFF)
    val SurfaceDark = Color(0xFF1C1C1E)

    val SurfaceRaisedLight = Color(0xFFFAF6F2)
    val SurfaceRaisedDark = Color(0xFF232327)

    val SurfaceMutedLight = Color(0xFFEDE3DD)
    val SurfaceMutedDark = Color(0xFF29292E)

    val SheetLight = Color(0xFFFAF3EE)
    val SheetDark = Color(0xFF141416)

    val AppBackgroundLight = CanvasLight
    val AppBackgroundDark = CanvasDark

    val AppCardLight = SurfaceLight
    val AppCardDark = SurfaceDark

    val OnLight = Color(0xFF1C1C1E)
    val OnDark = Color(0xFFF2F2F7)

    val MutedLight = Color(0xFF6F6966)
    val MutedDark = Color(0xFFAAA6AD)

    val DividerLight = Color(0xFFE2D8D2)
    val DividerDark = Color(0xFF343439)

    val ErrorLight = Color(0xFFB42318)
    val ErrorDark = Color(0xFFFF6B63)
    val OnErrorLight = Color.White
    val OnErrorDark = Color(0xFF3B0503)
    val ErrorContainerLight = Color(0xFFFFE9E6)
    val ErrorContainerDark = Color(0xFF5B1D19)
    val OnErrorContainerLight = Color(0xFF6B1510)
    val OnErrorContainerDark = Color(0xFFFFDAD6)

    val SurfaceDimLight = Color(0xFFE9DFD9)
    val SurfaceBrightLight = Color(0xFFFFFBF8)
    val SurfaceContainerLight = Color(0xFFF5EDE8)
    val SurfaceContainerHighLight = Color(0xFFEFE5DF)
    val SurfaceContainerHighestLight = Color(0xFFE9DED8)

    val SurfaceBrightDark = Color(0xFF303034)
    val SurfaceLowestDark = Color(0xFF09090A)
    val SurfaceLowDark = Color(0xFF161618)

    val OnAccent: Color
        get() = contentColorForGradient(CalorieStart, CalorieEnd)

    /** Chooses the higher-contrast app foreground for an arbitrary accent. */
    fun contentColorFor(background: Color): Color {
        val darkContrast = contrastRatio(background, OnLight)
        val lightContrast = contrastRatio(background, OnDark)
        return if (darkContrast >= lightContrast) OnLight else OnDark
    }

    /** Chooses one foreground that remains legible across both gradient stops. */
    fun contentColorForGradient(start: Color, end: Color): Color {
        val darkMinimum = minOf(contrastRatio(start, OnLight), contrastRatio(end, OnLight))
        val lightMinimum = minOf(contrastRatio(start, OnDark), contrastRatio(end, OnDark))
        return if (darkMinimum >= lightMinimum) OnLight else OnDark
    }

    private fun contrastRatio(a: Color, b: Color): Float {
        val lighter = maxOf(a.luminance(), b.luminance())
        val darker = minOf(a.luminance(), b.luminance())
        return (lighter + 0.05f) / (darker + 0.05f)
    }
}

@Immutable
data class FudSemanticColors(
    val isDark: Boolean,
    val canvas: Color,
    val surface: Color,
    val surfaceRaised: Color,
    val surfaceMuted: Color,
    val sheet: Color,
    val glassBase: Color,
    val glassHighlight: Color,
    val glassBorder: Color,
    val field: Color,
    val divider: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val accent: Color,
    val accentEnd: Color,
    val onAccent: Color,
    val shadow: Color,
    val error: Color
)

internal fun fudSemanticColors(themeColor: AppThemeColor, isDark: Boolean): FudSemanticColors {
    val primaryText = if (isDark) AppColors.OnDark else AppColors.OnLight
    return FudSemanticColors(
        isDark = isDark,
        canvas = if (isDark) AppColors.CanvasDark else AppColors.CanvasLight,
        surface = if (isDark) AppColors.SurfaceDark else AppColors.SurfaceLight,
        surfaceRaised = if (isDark) AppColors.SurfaceRaisedDark else AppColors.SurfaceRaisedLight,
        surfaceMuted = if (isDark) AppColors.SurfaceMutedDark else AppColors.SurfaceMutedLight,
        sheet = if (isDark) AppColors.SheetDark else AppColors.SheetLight,
        glassBase = if (isDark) Color(0xE817171B) else Color(0xFAFAF4EF),
        glassHighlight = Color.White.copy(alpha = if (isDark) 0.09f else 0.42f),
        glassBorder = Color.White.copy(alpha = if (isDark) 0.16f else 0.72f),
        field = if (isDark) Color(0xCC252529) else Color(0xE8EDE3DD),
        divider = if (isDark) AppColors.DividerDark else AppColors.DividerLight,
        textPrimary = primaryText,
        textSecondary = if (isDark) AppColors.MutedDark else AppColors.MutedLight,
        textTertiary = primaryText.copy(alpha = if (isDark) 0.48f else 0.46f),
        accent = themeColor.start,
        accentEnd = themeColor.end,
        onAccent = AppColors.contentColorForGradient(themeColor.start, themeColor.end),
        shadow = Color.Black.copy(alpha = if (isDark) 0.34f else 0.12f),
        error = if (isDark) AppColors.ErrorDark else AppColors.ErrorLight
    )
}
