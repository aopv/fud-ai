package com.apoorvdarshan.calorietracker.widget

import android.content.Context
import android.content.res.Resources
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.apoorvdarshan.calorietracker.MainActivity
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.data.PreferencesStore
import com.apoorvdarshan.calorietracker.models.MacroValueFormatter
import com.apoorvdarshan.calorietracker.models.WidgetNutrient
import com.apoorvdarshan.calorietracker.models.WidgetSnapshot
import kotlinx.coroutines.flow.first

class CalorieAppWidget : GlanceAppWidget() {

    override val sizeMode: SizeMode = SizeMode.Responsive(
        setOf(SMALL_SIZE, MEDIUM_SIZE)
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Never let a data-read failure leave the widget stuck on the loading layout — fall back to
        // an empty snapshot so provideContent always runs and the widget renders.
        val snapshot = runCatching {
            PreferencesStore(context).widgetSnapshot.first()?.takeUnless { it.isStale }
        }.getOrNull() ?: WidgetSnapshot.empty()

        provideContent {
            GlanceTheme {
                CalorieWidgetContent(snapshot)
            }
        }
    }

    companion object {
        val SMALL_SIZE = DpSize(140.dp, 140.dp)
        val MEDIUM_SIZE = DpSize(280.dp, 140.dp)
    }
}

class CalorieWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CalorieAppWidget()
}

@Composable
private fun CalorieWidgetContent(snapshot: WidgetSnapshot) {
    val size = LocalSize.current
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(WidgetTheme.backgroundProvider)
            .cornerRadius(22.dp)
            .padding(14.dp)
            .clickable(actionStartActivity<MainActivity>())
    ) {
        if (size.width < CalorieAppWidget.MEDIUM_SIZE.width) {
            CalorieSmall(snapshot)
        } else {
            CalorieMedium(snapshot)
        }
    }
}

@Composable
private fun CalorieSmall(snapshot: WidgetSnapshot) {
    Column(modifier = GlanceModifier.fillMaxSize()) {
        WidgetHeader(iconRes = R.drawable.ic_widget_flame, label = "Today")
        Box(
            modifier = GlanceModifier.fillMaxWidth().defaultWeight(),
            contentAlignment = Alignment.Center
        ) {
            SpeedometerWithCenter(
                progress = snapshot.calorieProgress.toFloat(),
                gaugeWidthDp = 104,
                strokeDp = 9,
                startHex = snapshot.themeStartHex,
                endHex = snapshot.themeEndHex,
                centerLarge = snapshot.calories.toString(),
                centerSmall = "/ ${snapshot.calorieGoal}"
            )
        }
        Text(
            text = "${snapshot.caloriesRemaining} kcal left",
            style = TextStyle(
                color = WidgetTheme.themeTextProvider(snapshot.themeStartHex),
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp
            )
        )
    }
}

@Composable
private fun CalorieMedium(snapshot: WidgetSnapshot) {
    Row(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            SpeedometerWithCenter(
                progress = snapshot.calorieProgress.toFloat(),
                gaugeWidthDp = 108,
                strokeDp = 9,
                startHex = snapshot.themeStartHex,
                endHex = snapshot.themeEndHex,
                centerLarge = snapshot.calories.toString(),
                centerSmall = "/ ${snapshot.calorieGoal}"
            )
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(
                text = "${snapshot.caloriesRemaining} kcal left",
                style = TextStyle(
                    color = WidgetTheme.themeTextProvider(snapshot.themeStartHex),
                    fontWeight = FontWeight.Medium,
                    fontSize = 11.sp
                )
            )
        }
        Spacer(modifier = GlanceModifier.width(10.dp))
        Box(modifier = GlanceModifier.defaultWeight()) {
            NutrientBarsRow(snapshot, barHeightDp = 44)
        }
    }
}

// ─── Shared building blocks ────────────────────────────────────────────────

@Composable
internal fun WidgetHeader(iconRes: Int, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Image(
            provider = ImageProvider(iconRes),
            contentDescription = null,
            modifier = GlanceModifier.size(12.dp)
        )
        Spacer(modifier = GlanceModifier.width(4.dp))
        Text(
            text = label,
            style = TextStyle(
                color = WidgetTheme.secondaryTextProvider,
                fontWeight = FontWeight.Medium,
                fontSize = 12.sp
            )
        )
    }
}

/**
 * Home-style dashed speedometer with the readout inside the dome. The gauge
 * bitmap is gaugeWidth x (0.58 * gaugeWidth); texts are centered over it.
 */
@Composable
internal fun SpeedometerWithCenter(
    progress: Float,
    gaugeWidthDp: Int,
    strokeDp: Int,
    startHex: Int?,
    endHex: Int?,
    centerLarge: String,
    centerSmall: String
) {
    val density = Resources.getSystem().displayMetrics.density
    val sizePx = (gaugeWidthDp * density).toInt().coerceAtLeast(1)
    val bitmap = speedometerBitmap(
        diameterPx = sizePx,
        progress = progress,
        strokeWidthPx = strokeDp * density,
        startRgb = WidgetTheme.themeStart(startHex),
        endRgb = WidgetTheme.themeEnd(endHex)
    )
    val gaugeHeightDp = (gaugeWidthDp * 0.58f).toInt()
    val centerLargeFontSize = if (centerLarge.length > 5) 15.sp else 19.sp

    Box(
        modifier = GlanceModifier.size(gaugeWidthDp.dp, gaugeHeightDp.dp),
        contentAlignment = Alignment.Center
    ) {
        Image(
            provider = ImageProvider(bitmap),
            contentDescription = null,
            modifier = GlanceModifier.fillMaxSize()
        )
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = centerLarge,
                style = TextStyle(
                    color = WidgetTheme.themeTextProvider(startHex),
                    fontWeight = FontWeight.Bold,
                    fontSize = centerLargeFontSize
                )
            )
            Text(
                text = centerSmall,
                style = TextStyle(
                    color = WidgetTheme.secondaryTextProvider,
                    fontSize = 10.sp
                )
            )
        }
    }
}

/** The user's 4 selected Home nutrients as vertical fill tubes, like the app's Home bars. */
@Composable
internal fun NutrientBarsRow(
    snapshot: WidgetSnapshot,
    barHeightDp: Int,
    barWidthDp: Int = 11,
    valueFontSp: Int = 13
) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        snapshot.displayedHomeNutrients.forEach { nutrient ->
            Box(modifier = GlanceModifier.defaultWeight()) {
                VerticalNutrientBarCell(
                    nutrient = nutrient,
                    startHex = snapshot.themeStartHex,
                    endHex = snapshot.themeEndHex,
                    barHeightDp = barHeightDp,
                    barWidthDp = barWidthDp,
                    valueFontSp = valueFontSp
                )
            }
        }
    }
}

@Composable
internal fun VerticalNutrientBarCell(
    nutrient: WidgetNutrient,
    startHex: Int?,
    endHex: Int?,
    barHeightDp: Int,
    barWidthDp: Int,
    valueFontSp: Int
) {
    val density = Resources.getSystem().displayMetrics.density
    val bitmap = verticalBarBitmap(
        widthPx = (barWidthDp * density).toInt().coerceAtLeast(2),
        heightPx = (barHeightDp * density).toInt().coerceAtLeast(2),
        progress = nutrient.progress.toFloat(),
        startRgb = WidgetTheme.themeStart(startHex),
        endRgb = WidgetTheme.themeEnd(endHex)
    )
    Column(
        modifier = GlanceModifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = MacroValueFormatter.string(nutrient.value),
            style = TextStyle(
                color = WidgetTheme.themeTextProvider(startHex),
                fontWeight = FontWeight.Bold,
                fontSize = valueFontSp.sp
            ),
            maxLines = 1
        )
        Spacer(modifier = GlanceModifier.height(3.dp))
        Image(
            provider = ImageProvider(bitmap),
            contentDescription = null,
            modifier = GlanceModifier.size(barWidthDp.dp, barHeightDp.dp)
        )
        Spacer(modifier = GlanceModifier.height(3.dp))
        Text(
            text = nutrient.label,
            style = TextStyle(
                color = WidgetTheme.primaryTextProvider,
                fontWeight = FontWeight.Medium,
                fontSize = 10.sp
            ),
            maxLines = 1
        )
        Text(
            text = "/${MacroValueFormatter.string(nutrient.goal)}${nutrient.unit}",
            style = TextStyle(
                color = WidgetTheme.secondaryTextProvider,
                fontSize = 9.sp
            ),
            maxLines = 1
        )
    }
}
