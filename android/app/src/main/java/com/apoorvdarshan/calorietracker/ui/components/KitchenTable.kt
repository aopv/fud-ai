package com.apoorvdarshan.calorietracker.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.ui.theme.AppColors

/** One decoded texture layer for the active destination, never per list row. */
@Composable
fun KitchenTableBackground(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit
) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    Box(
        modifier = modifier.background(MaterialTheme.colorScheme.background)
    ) {
        Image(
            painter = painterResource(R.drawable.kitchen_paper),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .matchParentSize()
                .alpha(if (isDark) 0.05f else 0.10f)
        )
        content()
    }
}

/**
 * Shared utility-page masthead. It stays intentionally shallow so Settings and
 * library screens begin with their useful controls instead of a marketing hero.
 * The compact perforated rule carries the receipt motif without taking over the
 * first viewport.
 */
@Composable
fun KitchenPageHeader(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    trailing: @Composable RowScope.() -> Unit = {}
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(1.dp)
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onBackground
                )
                if (!subtitle.isNullOrBlank()) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.62f)
                    )
                }
            }
            trailing()
        }
        KitchenReceiptRule(height = 5.dp, markerRadius = 2.dp)
    }
}

@Composable
fun KitchenReceiptRule(
    modifier: Modifier = Modifier,
    color: Color = AppColors.KitchenBrass,
    height: Dp = 8.dp,
    markerRadius: Dp = 3.dp
) {
    Canvas(modifier.fillMaxWidth().height(height)) {
        val centerY = size.height / 2f
        val markerRadiusPx = markerRadius.toPx()
        val lineStart = markerRadiusPx * 3.2f
        drawCircle(
            color = AppColors.KitchenTomato,
            radius = markerRadiusPx,
            center = Offset(markerRadiusPx, centerY)
        )
        drawLine(
            color = color.copy(alpha = 0.72f),
            start = Offset(lineStart, centerY),
            end = Offset(size.width, centerY),
            strokeWidth = 1.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(
                floatArrayOf(7.dp.toPx(), 5.dp.toPx())
            )
        )
    }
}

@Composable
fun KitchenSectionLabel(title: String, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth()) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.tertiary,
            modifier = Modifier.padding(start = 2.dp, bottom = 5.dp)
        )
        KitchenReceiptRule(color = AppColors.KitchenBrass.copy(alpha = 0.7f))
    }
}
