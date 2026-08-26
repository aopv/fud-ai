package com.apoorvdarshan.calorietracker.ui.theme

import androidx.annotation.StringRes
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
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
    /**
     * Fud AI's Kitchen Table palette. The legacy Neo* aliases remain so feature
     * screens can adopt the new presentation without changing their contracts.
     */
    private val LightKitchenBone = Color(0xFFF4E8D2)
    private val LightKitchenPaper = Color(0xFFFFF8EA)
    private val LightKitchenEspresso = Color(0xFF2C1E19)
    private val LightKitchenTomato = Color(0xFFB8412F)
    private val LightKitchenCobalt = Color(0xFF315BA9)
    private val LightKitchenHerb = Color(0xFF4F7252)
    private val LightKitchenBrass = Color(0xFFC7A24A)

    // Dark mode keeps the same table-and-receipt hierarchy, only at night:
    // roast canvas, lifted brown paper, cream ink, and brighter stamp pigments.
    private val DarkKitchenBone = Color(0xFF251C18)
    private val DarkKitchenPaper = Color(0xFF352923)
    private val DarkKitchenEspresso = Color(0xFFF4E6D0)
    private val DarkKitchenTomato = Color(0xFFE36A50)
    private val DarkKitchenCobalt = Color(0xFF82A6ED)
    private val DarkKitchenHerb = Color(0xFF91B38B)
    private val DarkKitchenBrass = Color(0xFFDDB866)

    /** Stable light cream for ink placed on tomato controls and camera chrome. */
    val KitchenCream = LightKitchenPaper

    private var darkKitchen = false

    val KitchenBone: Color
        get() = if (darkKitchen) DarkKitchenBone else LightKitchenBone
    val KitchenPaper: Color
        get() = if (darkKitchen) DarkKitchenPaper else LightKitchenPaper
    val KitchenEspresso: Color
        get() = if (darkKitchen) DarkKitchenEspresso else LightKitchenEspresso
    val KitchenTomato: Color
        get() = if (darkKitchen) DarkKitchenTomato else LightKitchenTomato
    val KitchenCobalt: Color
        get() = if (darkKitchen) DarkKitchenCobalt else LightKitchenCobalt
    val KitchenHerb: Color
        get() = if (darkKitchen) DarkKitchenHerb else LightKitchenHerb
    val KitchenBrass: Color
        get() = if (darkKitchen) DarkKitchenBrass else LightKitchenBrass
    val KitchenRoast = Color(0xFF1F1714)
    val KitchenRoastPaper = Color(0xFF2A211D)

    val NeoCobalt: Color
        get() = KitchenCobalt
    val NeoAcid: Color
        get() = KitchenBrass
    val NeoInk: Color
        get() = KitchenEspresso
    val NeoPaper: Color
        get() = KitchenBone

    private var activeThemeColor: AppThemeColor = AppThemeColor.FUD_PINK

    fun setThemeColor(themeColor: AppThemeColor) {
        activeThemeColor = themeColor
    }

    fun setDarkTheme(enabled: Boolean) {
        darkKitchen = enabled
    }

    val ThemeColor: AppThemeColor
        get() = activeThemeColor

    val CalorieStart: Color
        get() = KitchenTomato

    val CalorieEnd: Color
        get() = Color(0xFFC1533B)

    val Calorie: Color
        get() = CalorieStart

    val Protein: Color
        get() = KitchenHerb

    val Carbs: Color
        get() = KitchenBrass

    val Fat: Color
        get() = KitchenCobalt

    val CalorieGradient: Brush
        get() = Brush.linearGradient(listOf(CalorieStart, CalorieEnd))

    val AppBackgroundLight = LightKitchenBone
    val AppBackgroundDark = KitchenRoast

    val AppCardLight = LightKitchenPaper
    val AppCardDark = KitchenRoastPaper

    val OnLight = KitchenEspresso
    val OnDark = Color(0xFFF8ECD8)

    val MutedLight = Color(0xFF76675D)
    val MutedDark = Color(0xFFB9AA9D)

    val DividerLight = Color(0xFFD8C7AF)
    val DividerDark = Color(0xFF4B3B34)
}
